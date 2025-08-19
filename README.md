# Docker SFTP Radius

A lightweight Docker container that provides SFTP access with RADIUS authentication. This container creates a secure SFTP server that authenticates users against a RADIUS server.

## Features

- **RADIUS Authentication**: Authenticate users against your existing RADIUS infrastructure
- **SFTP-Only Access**: Users can only access SFTP, no shell access
- **Secure Configuration**: No chroot, minimal attack surface
- **Docker Ready**: Easy deployment/re-deployment with Docker Compose
- **User Management**: Automatic user creation and cleanup based on environment variables
- **Lightweight**: Based on Ubuntu 24.04 with minimal dependencies

## Prerequisites

- You have a RADIUS server already configured
- You have a basic understanding of Docker

## Quick Start

1. **Clone the repository**:

   ```bash
   git clone https://github.com/connorvernet/Docker-SFTP-Radius.git
   cd Docker-SFTP-Radius
   ```
2. **Edit the docker-compose.yml Environment Variables**
   
| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `RADIUS_HOST` | RADIUS server hostname/IP | - | ✅ |
| `RADIUS_PORT` | RADIUS server port | `1812` | ❌ |
| `RADIUS_SECRET` | RADIUS shared secret | - | ✅ |
| `RADIUS_TIMEOUT` | RADIUS timeout in seconds | `5` | ❌ |
| `SFTP_PORT` | SFTP server port | `2222` | ❌ |
| `USERS` | Comma-separated list of usernames | - | ✅ |


4. Compile the Docker File
```bash
docker build -t sftp-radius .
```

5. **Start the container**:
   ```bash
   docker-compose up -d
   ```

6. **Connect via SFTP**:
   ```bash
   sftp -P 2222 username@localhost
   ```

## How It Works

1. **Container Initialization**:
   - Generates SSH host keys
   - Configures PAM for RADIUS authentication
   - Sets up SFTP-only SSH configuration
   - Creates user accounts based on the `USERS` environment variable

2. **Authentication Flow**:
   - User connects via SFTP
   - SSH server uses PAM for authentication
   - PAM forwards credentials to RADIUS server
   - Access granted/denied based on RADIUS response

3. **User Management**:
   - Users are created with `/usr/sbin/nologin` shell (no shell access)
   - All users belong to the `sftponly` group
   - Local passwords are locked (RADIUS only)
   - Users not in the `USERS` list are automatically removed

