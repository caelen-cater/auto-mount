# Multi-Server Auto-Mount SFTP Service

A powerful daemon service that automatically monitors and remounts multiple SFTP connections when they become unmounted. Perfect for Plex servers, backup systems, or any application that relies on multiple remote media storage sources.

**Repository**: [https://github.com/caelen-cater/auto-mount](https://github.com/caelen-cater/auto-mount)  
**Website**: [https://caelen.dev](https://caelen.dev)

## Features

- **Multi-Server Support**: Manage multiple SFTP servers independently
- **Automatic Monitoring**: Checks mount status every few minutes per server
- **Smart Detection**: Detects both unmounted and inaccessible mounts
- **Force Unmount**: Safely unmounts stuck connections before remounting
- **Comprehensive Logging**: Detailed logs for each server
- **Easy Management**: Add, list, and remove servers with simple commands
- **System Integration**: Works with systemd and cron
- **Unique Naming**: Each server gets its own configuration and scripts

## Quick Start

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/caelen-cater/auto-mount.git
   cd auto-mount
   ```

2. **Add your first server** (requires sudo):
   ```bash
   sudo ./install.sh add
   ```

3. **Follow the prompts** to configure your SFTP connection
4. **The service will start automatically** and run every 5 minutes (configurable)

### Alternative Installation

You can also download the latest release from the [releases page](https://github.com/caelen-cater/auto-mount/releases) or use the update checker:

```bash
sudo ./install.sh update
```

## Managing Servers

### Add a New Server
```bash
sudo ./install.sh add
```

### Edit an Existing Server
```bash
sudo ./install.sh edit
```

### Repair/Regenerate Files
```bash
sudo ./install.sh repair
```

The repair command regenerates all files for existing servers with their current settings. Useful for:
- Fixing corrupted scripts or services
- Restoring missing files after system updates
- Updating file permissions or ownership
- Regenerating files with latest improvements

### List All Servers
```bash
sudo ./install.sh list
```

### Remove a Server
```bash
sudo ./install.sh remove
```

### Remove All Servers
```bash
sudo ./install.sh uninstall
```

### Check for Updates
```bash
sudo ./install.sh update
```

## File Structure

Each server gets its own set of files:

- **Configuration**: `/etc/auto-mount/SERVER_NAME.conf`
- **Script**: `/usr/local/bin/auto-mount-SERVER_NAME.sh`
- **Service**: `/etc/systemd/system/auto-mount-SERVER_NAME.service`
- **Cron**: `/etc/cron.d/auto-mount-SERVER_NAME`
- **Log**: `/var/log/auto-mount/SERVER_NAME.log`

## Example Usage

```bash
# Add a Plex media server
sudo ./install.sh add
# Enter: plex-media
# Enter: /home/plex/.ssh/id_rsa
# Enter: media@server.com
# Enter: /home/media
# Enter: /mnt/plex-media

# Add a backup server
sudo ./install.sh add
# Enter: backup-server
# Enter: /home/backup/.ssh/id_rsa
# Enter: backup@backup.com
# Enter: /backup/data
# Enter: /mnt/backup

# List all servers
sudo ./install.sh list

# Remove a server
sudo ./install.sh remove
# Enter: plex-media

## Configuration

Each server has its own configuration file at `/etc/auto-mount/SERVER_NAME.conf`:

```bash
# Auto-mount configuration for SERVER_NAME
# Generated on 2024-01-01 12:00:00

# Server name
SERVER_NAME="plex-media"

# SSH Key path (full path to your private key)
SSH_KEY="/home/plex/.ssh/id_rsa"

# User@Host (username@hostname or username@ip)
USER_HOST="media@server.com"

# Remote path on the server (directory to mount)
REMOTE_PATH="/home/media"

# Local mount point (where to mount locally)
MOUNT_POINT="/mnt/plex-media"

# Check interval in minutes (how often to check)
CHECK_INTERVAL="5"
```

## Usage

- **View logs**: `tail -f /var/log/auto-mount/SERVER_NAME.log`
- **Manual run**: `sudo /usr/local/bin/auto-mount-SERVER_NAME.sh`
- **Check status**: `mountpoint /mnt/SERVER_NAME`
- **List servers**: `sudo ./install.sh list`

## Uninstall

To remove a specific server:

```bash
sudo ./install.sh remove
```

To remove all servers:

```bash
sudo ./install.sh uninstall
```

## Requirements

- Linux system with `sshfs` installed
- SSH key-based authentication
- Sudo access for installation and management

## Troubleshooting

1. **Check logs** for detailed error messages
2. **Verify SSH key** permissions and path
3. **Test SSH connection** manually: `ssh -i /path/to/key user@host`
4. **Check mount point** permissions and existence

## License

Apache-2.0 License - see LICENSE file for details.
