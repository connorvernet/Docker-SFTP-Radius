#!/usr/bin/env bash
set -euo pipefail

echo "[init] sftp-radius (minimal, no chroot, with prune)"

# Required env
: "${RADIUS_HOST:?RADIUS_HOST must be set}"
: "${RADIUS_SECRET:?RADIUS_SECRET must be set}"
: "${USERS:?USERS must be set}"

# Defaults
RADIUS_PORT="${RADIUS_PORT:-1812}"
RADIUS_TIMEOUT="${RADIUS_TIMEOUT:-5}"
SFTP_PORT="${SFTP_PORT:-2222}"
SFTP_GROUP="sftponly"

# Host keys
/usr/bin/ssh-keygen -A

# RADIUS client config for PAM
echo "${RADIUS_HOST}:${RADIUS_PORT}    ${RADIUS_SECRET}    ${RADIUS_TIMEOUT}" > /etc/pam_radius_auth.conf
chmod 600 /etc/pam_radius_auth.conf

# PAM stack for sshd (RADIUS required)
cat > /etc/pam.d/sshd <<"PAM"
#%PAM-1.0
auth    required     pam_radius_auth.so
@include common-account
@include common-session
PAM

# sshd config (SFTP-only, no chroot)
cat >/etc/ssh/sshd_config <<CFG
Port ${SFTP_PORT}
UsePAM yes
KbdInteractiveAuthentication yes
PasswordAuthentication no
Subsystem sftp internal-sftp
# Force SFTP for all users; no shells
ForceCommand internal-sftp
AllowTcpForwarding no
X11Forwarding no
CFG

# Ensure management group exists
getent group "${SFTP_GROUP}" >/dev/null 2>&1 || groupadd -r "${SFTP_GROUP}"

# Normalize desired users from env -> space-separated list
readarray -td, _raw <<<"${USERS},"; unset ' _raw[-1]' || true
desired_users=()
for x in "${_raw[@]}"; do
  n="$(echo "$x" | xargs)"; [[ -n "$n" ]] && desired_users+=("$n")
done

#Ensure desired users exist (primary group = sftponly, nologin, local pw locked)
for name in "${desired_users[@]}"; do
  if ! id "$name" >/dev/null 2>&1; then
    useradd -m -g "${SFTP_GROUP}" -s /usr/sbin/nologin "$name"
    echo "[add] $name"
  else
    # ensure primary group is sftponly
    primary_gid="$(id -g "$name")"
    sftponly_gid="$(getent group "${SFTP_GROUP}" | cut -d: -f3)"
    if [[ "$primary_gid" != "$sftponly_gid" ]]; then
      usermod -g "${SFTP_GROUP}" "$name"
    fi
  fi
  passwd -l "$name" >/dev/null 2>&1 || true
done

# Build a quick membership string for contains checks
desired_str=" ${desired_users[*]} "

# Remove managed users not listed in USERS
# Only consider accounts whose PRIMARY group is sftponly (our managed set) and with UID >= 1000
sftponly_gid="$(getent group "${SFTP_GROUP}" | cut -d: -f3)"
while IFS=: read -r uname _ uid gid _ _ _; do
  [[ "$gid" != "$sftponly_gid" ]] && continue
  [[ "$uid" -lt 1000 ]] && continue   # safety: skip system users, just in case
  if [[ "$desired_str" != *" ${uname} "* ]]; then
    echo "[prune] deleting ${uname}"
    userdel -r "${uname}" 2>/dev/null || userdel "${uname}" || true
  fi
done < <(getent passwd)

echo "[init] ready"
exec "$@"
