#!/bin/bash

# Multi-server auto-mount installer for SFTP services
# Manages multiple SFTP server configurations
#
# Auto-Mount SFTP Service v1.1.0
# Repository: https://github.com/caelen-cater/auto-mount
# Website: https://caelen.dev
# Copyright (c) 2025 Caelen Cater

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="/etc/auto-mount"
SERVICE_DIR="/etc/systemd/system"
CRON_DIR="/etc/cron.d"
LOG_DIR="/var/log/auto-mount"
BIN_DIR="/usr/local/bin"

# Repository information
REPO_URL="https://github.com/caelen-cater/auto-mount"
WEBSITE_URL="https://caelen.dev"
CURRENT_VERSION="1.1.0"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}[HEADER]${NC} $1"
}

# Function to check if running with sudo
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run with sudo"
        print_status "Usage: sudo $0 [COMMAND]"
        exit 1
    fi
}

# Function to create directories
create_directories() {
    print_status "Creating directories..."
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$BIN_DIR"
}

# Function to install dependencies
install_dependencies() {
    print_status "Installing dependencies..."
    
    # Check if sshfs is installed
    if ! command -v sshfs &> /dev/null; then
        print_status "Installing sshfs..."
        if command -v apt-get &> /dev/null; then
            apt-get update && apt-get install -y sshfs
        elif command -v yum &> /dev/null; then
            yum install -y fuse-sshfs
        elif command -v dnf &> /dev/null; then
            dnf install -y fuse-sshfs
        elif command -v pacman &> /dev/null; then
            pacman -S --noconfirm sshfs
        else
            print_error "Package manager not supported. Please install sshfs manually."
            exit 1
        fi
    else
        print_status "sshfs is already installed"
    fi
}

# Function to get server name
get_server_name() {
    local server_name
    while true; do
        read -p "Enter a unique name for this server (e.g., plex-media, backup-server): " server_name
        
        # Validate server name (alphanumeric, hyphens, underscores only)
        if [[ ! "$server_name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
            print_error "Server name can only contain letters, numbers, hyphens, and underscores"
            continue
        fi
        
        # Check if server already exists
        if [[ -f "$CONFIG_DIR/$server_name.conf" ]]; then
            print_error "Server '$server_name' already exists. Please choose a different name."
            continue
        fi
        
        break
    done
    echo "$server_name"
}

# Function to get user input for server configuration
get_server_config() {
    local server_name="$1"
    
    print_status "Configuring server: $server_name"
    echo
    
    # SSH Key path
    read -p "SSH Key path: " ssh_key
    while [[ -z "$ssh_key" ]]; do
        read -p "SSH Key path (required): " ssh_key
    done
    
    # User and host
    read -p "User@Host (e.g., user@server.com): " user_host
    while [[ -z "$user_host" ]]; do
        read -p "User@Host (required): " user_host
    done
    
    # Remote path
    read -p "Remote path (e.g., /home/user/data): " remote_path
    while [[ -z "$remote_path" ]]; do
        read -p "Remote path (required): " remote_path
    done
    
    # Mount point
    read -p "Mount point (e.g., /mnt/$server_name): " mount_point
    mount_point=${mount_point:-/mnt/$server_name}
    
    # Check interval
    read -p "Check interval in minutes [5]: " check_interval
    check_interval=${check_interval:-5}
    
    echo
    print_status "Configuration summary for '$server_name':"
    echo "  SSH Key: $ssh_key"
    echo "  User@Host: $user_host"
    echo "  Remote Path: $remote_path"
    echo "  Mount Point: $mount_point"
    echo "  Check Interval: $check_interval minutes"
    echo
    
    read -p "Is this correct? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Configuration cancelled"
        return 1
    fi
    
    # Store configuration
    cat > "$CONFIG_DIR/$server_name.conf" << EOF
# Auto-mount configuration for $server_name
# Generated on $(date)

# Server name
SERVER_NAME="$server_name"

# SSH Key path
SSH_KEY="$ssh_key"

# User@Host
USER_HOST="$user_host"

# Remote path on the server
REMOTE_PATH="$remote_path"

# Local mount point
MOUNT_POINT="$mount_point"

# Check interval in minutes
CHECK_INTERVAL="$check_interval"
EOF

    chmod 644 "$CONFIG_DIR/$server_name.conf"
    print_status "Configuration saved to $CONFIG_DIR/$server_name.conf"
}

# Function to generate auto-mount script for a server
generate_server_script() {
    local server_name="$1"
    local script_path="$BIN_DIR/auto-mount-$server_name.sh"
    
    print_status "Generating auto-mount script for $server_name..."
    
    cat > "$script_path" << 'EOF'
#!/bin/bash

# Auto-mount script for SFTP server
# Generated by auto-mount installer
# Monitors mount status and automatically remounts when needed
#
# Auto-Mount SFTP Service v1.1.0
# Repository: https://github.com/caelen-cater/auto-mount
# Website: https://caelen.dev
# Copyright (c) 2025 Caelen Cater

# Configuration file location
CONFIG_FILE="/etc/auto-mount/SERVER_NAME.conf"

# Log file location
LOG_FILE="/var/log/auto-mount/SERVER_NAME.log"

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to check if mount point is mounted
is_mounted() {
    local mount_point="$1"
    mountpoint -q "$mount_point" 2>/dev/null
    return $?
}

# Function to check if mount is accessible (not just mounted but working)
is_accessible() {
    local mount_point="$1"
    
    # First check if it's actually mounted
    if ! mountpoint -q "$mount_point" 2>/dev/null; then
        return 1
    fi
    
    # Check if we can access the mount point
    if [[ ! -d "$mount_point" ]]; then
        return 1
    fi
    
    # Try to list contents to verify the mount is working
    if ls "$mount_point" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to unmount if stuck
force_unmount() {
    local mount_point="$1"
    log_message "Attempting to force unmount $mount_point"
    umount -f "$mount_point" 2>/dev/null
    sleep 2
    umount -l "$mount_point" 2>/dev/null
    sleep 2
}

# Function to mount the SFTP server
mount_sftp() {
    local ssh_key="$1"
    local user_host="$2"
    local remote_path="$3"
    local mount_point="$4"
    
    log_message "Attempting to mount $user_host:$remote_path to $mount_point"
    
    # Create mount point if it doesn't exist
    mkdir -p "$mount_point"
    
    # Mount the SFTP server
    if sshfs -o IdentityFile="$ssh_key" "$user_host:$remote_path" "$mount_point"; then
        log_message "Successfully mounted $user_host:$remote_path to $mount_point"
        return 0
    else
        log_message "Failed to mount $user_host:$remote_path to $mount_point"
        return 1
    fi
}

# Main function
main() {
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_message "ERROR: Configuration file $CONFIG_FILE not found"
        exit 1
    fi
    
    # Source the configuration
    source "$CONFIG_FILE"
    
    # Validate required variables
    if [[ -z "$SSH_KEY" || -z "$USER_HOST" || -z "$REMOTE_PATH" || -z "$MOUNT_POINT" ]]; then
        log_message "ERROR: Missing required configuration variables"
        exit 1
    fi
    
    # Check if mount point is mounted
    if is_mounted "$MOUNT_POINT"; then
        # Check if it's accessible
        if is_accessible "$MOUNT_POINT"; then
            log_message "Mount $MOUNT_POINT is active and accessible"
            exit 0
        else
            log_message "Mount $MOUNT_POINT is mounted but not accessible, attempting to fix"
            force_unmount "$MOUNT_POINT"
        fi
    else
        log_message "Mount $MOUNT_POINT is not mounted"
    fi
    
    # Attempt to mount
    if mount_sftp "$SSH_KEY" "$USER_HOST" "$REMOTE_PATH" "$MOUNT_POINT"; then
        log_message "Auto-mount completed successfully"
        exit 0
    else
        log_message "Auto-mount failed"
        exit 1
    fi
}

# Run main function
main "$@"
EOF

    # Replace placeholders with actual server name
    sed -i "s/SERVER_NAME/$server_name/g" "$script_path"
    
    chmod +x "$script_path"
    print_status "Auto-mount script generated: $script_path"
}

# Function to create systemd service for a server
create_systemd_service() {
    local server_name="$1"
    local service_file="$SERVICE_DIR/auto-mount-$server_name.service"
    
    print_status "Creating systemd service for $server_name..."
    
    cat > "$service_file" << EOF
[Unit]
Description=Auto-mount SFTP Service for $server_name
After=network.target

[Service]
Type=oneshot
ExecStart=$BIN_DIR/auto-mount-$server_name.sh
User=root
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    print_status "Systemd service created: $service_file"
}

# Function to create cron job for a server
create_cron_job() {
    local server_name="$1"
    local cron_file="$CRON_DIR/auto-mount-$server_name"
    local check_interval
    
    # Get check interval from config
    source "$CONFIG_DIR/$server_name.conf"
    check_interval="$CHECK_INTERVAL"
    
    print_status "Creating cron job for $server_name (every $check_interval minutes)..."
    
    cat > "$cron_file" << EOF
# Auto-mount SFTP service for $server_name
# Runs every $check_interval minutes
#
# Auto-Mount SFTP Service v1.1.0
# Repository: https://github.com/caelen-cater/auto-mount
# Website: https://caelen.dev
# Copyright (c) 2025 Caelen Cater
*/$check_interval * * * * root $BIN_DIR/auto-mount-$server_name.sh
EOF

    chmod 644 "$cron_file"
    print_status "Cron job created: $cron_file"
}

# Function to create log file for a server
create_log_file() {
    local server_name="$1"
    local log_file="$LOG_DIR/$server_name.log"
    
    print_status "Setting up logging for $server_name..."
    
    touch "$log_file"
    chmod 644 "$log_file"
    
    # Create logrotate configuration
    cat > "/etc/logrotate.d/auto-mount-$server_name" << EOF
$log_file {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
}
EOF

    print_status "Log file created: $log_file"
}

# Function to add a new server
add_server() {
    print_header "Adding New Server Configuration"
    echo
    
    # Get server name
    local server_name
    server_name=$(get_server_name)
    
    # Get server configuration
    if ! get_server_config "$server_name"; then
        return 1
    fi
    
    # Generate script
    generate_server_script "$server_name"
    
    # Create systemd service
    create_systemd_service "$server_name"
    
    # Create cron job
    create_cron_job "$server_name"
    
    # Create log file
    create_log_file "$server_name"
    
    # Test the installation
    print_status "Testing installation for $server_name..."
    if "$BIN_DIR/auto-mount-$server_name.sh"; then
        print_status "Test run successful!"
    else
        print_warning "Test run failed. Check the log file: $LOG_DIR/$server_name.log"
    fi
    
    print_status "Server '$server_name' added successfully!"
    echo
    print_status "To view logs: tail -f $LOG_DIR/$server_name.log"
    print_status "To manually run: $BIN_DIR/auto-mount-$server_name.sh"
}

# Function to list all servers
list_servers() {
    print_header "Configured Servers"
    echo
    
    if [[ ! -d "$CONFIG_DIR" ]] || [[ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
        print_warning "No servers configured"
        return 0
    fi
    
    local count=0
    for config_file in "$CONFIG_DIR"/*.conf; do
        if [[ -f "$config_file" ]]; then
            local server_name=$(basename "$config_file" .conf)
            local mount_point
            local user_host
            local check_interval
            
            # Source the config to get details
            source "$config_file"
            mount_point="$MOUNT_POINT"
            user_host="$USER_HOST"
            check_interval="$CHECK_INTERVAL"
            
            echo "  $((++count)). $server_name"
            echo "     Host: $user_host"
            echo "     Mount: $mount_point"
            echo "     Check: Every $check_interval minutes"
            echo "     Log: $LOG_DIR/$server_name.log"
            echo
        fi
    done
    
    if [[ $count -eq 0 ]]; then
        print_warning "No servers configured"
    else
        print_status "Total: $count server(s) configured"
    fi
}

# Function to remove a server
remove_server() {
    print_header "Remove Server Configuration"
    echo
    
    # List available servers
    list_servers
    echo
    
    if [[ ! -d "$CONFIG_DIR" ]] || [[ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
        print_warning "No servers to remove"
        return 0
    fi
    
    read -p "Enter server name to remove: " server_name
    
    if [[ -z "$server_name" ]]; then
        print_error "Server name cannot be empty"
        return 1
    fi
    
    if [[ ! -f "$CONFIG_DIR/$server_name.conf" ]]; then
        print_error "Server '$server_name' not found"
        return 1
    fi
    
    echo
    print_warning "This will remove all configuration and files for server '$server_name'"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Removal cancelled"
        return 0
    fi
    
    print_status "Removing server '$server_name'..."
    
    # Remove files
    rm -f "$CONFIG_DIR/$server_name.conf"
    rm -f "$BIN_DIR/auto-mount-$server_name.sh"
    rm -f "$SERVICE_DIR/auto-mount-$server_name.service"
    rm -f "$CRON_DIR/auto-mount-$server_name"
    rm -f "/etc/logrotate.d/auto-mount-$server_name"
    rm -f "$LOG_DIR/$server_name.log"
    
    # Reload systemd
    systemctl daemon-reload
    
    print_status "Server '$server_name' removed successfully!"
}

# Function to check for updates
check_updates() {
    print_header "Checking for Updates"
    echo
    
    print_status "Current version: $CURRENT_VERSION"
    print_status "Repository: $REPO_URL"
    echo
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        print_warning "curl is not installed. Cannot check for updates."
        print_status "Install curl to enable update checking:"
        print_status "  Ubuntu/Debian: sudo apt-get install curl"
        print_status "  CentOS/RHEL: sudo yum install curl"
        print_status "  Arch: sudo pacman -S curl"
        return 1
    fi
    
    print_status "Checking for latest release..."
    
    # Get the latest release tag from GitHub API
    local latest_version
    latest_version=$(curl -s "https://api.github.com/repos/caelen-cater/auto-mount/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)
    
    if [[ -z "$latest_version" ]]; then
        print_warning "Could not fetch latest version information"
        print_status "You can check manually at: $REPO_URL/releases"
        return 1
    fi
    
    print_status "Latest version: $latest_version"
    
    # Compare versions (simple string comparison)
    if [[ "$latest_version" != "$CURRENT_VERSION" ]]; then
        print_warning "A newer version is available!"
        echo
        print_status "To update:"
        print_status "  1. Download the latest release from: $REPO_URL/releases"
        print_status "  2. Replace the files in your installation directory"
        print_status "  3. Run: sudo ./install.sh add  # to add new servers"
        echo
        print_status "Or clone the latest version:"
        print_status "  git clone $REPO_URL.git"
        print_status "  cd auto-mount"
        print_status "  sudo ./install.sh add"
    else
        print_status "You are running the latest version!"
    fi
}

# Function to edit an existing server
edit_server() {
    print_header "Edit Server Configuration"
    echo
    
    # List available servers
    list_servers
    echo
    
    if [[ ! -d "$CONFIG_DIR" ]] || [[ -z "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
        print_warning "No servers to edit"
        return 0
    fi
    
    read -p "Enter server name to edit: " server_name
    
    if [[ -z "$server_name" ]]; then
        print_error "Server name cannot be empty"
        return 1
    fi
    
    if [[ ! -f "$CONFIG_DIR/$server_name.conf" ]]; then
        print_error "Server '$server_name' not found"
        return 1
    fi
    
    print_status "Editing server '$server_name'..."
    echo
    
    # Load existing configuration
    source "$CONFIG_DIR/$server_name.conf"
    
    # Show current configuration
    print_status "Current configuration:"
    echo "  SSH Key: $SSH_KEY"
    echo "  User@Host: $USER_HOST"
    echo "  Remote Path: $REMOTE_PATH"
    echo "  Mount Point: $MOUNT_POINT"
    echo "  Check Interval: $CHECK_INTERVAL minutes"
    echo
    
    read -p "Press Enter to continue with editing or Ctrl+C to cancel..."
    
    # Get new configuration
    print_status "Enter new configuration (press Enter to keep current value):"
    echo
    
    # SSH Key path
    read -p "SSH Key path [$SSH_KEY]: " new_ssh_key
    new_ssh_key=${new_ssh_key:-$SSH_KEY}
    
    # User and host
    read -p "User@Host [$USER_HOST]: " new_user_host
    new_user_host=${new_user_host:-$USER_HOST}
    
    # Remote path
    read -p "Remote path [$REMOTE_PATH]: " new_remote_path
    new_remote_path=${new_remote_path:-$REMOTE_PATH}
    
    # Mount point
    read -p "Mount point [$MOUNT_POINT]: " new_mount_point
    new_mount_point=${new_mount_point:-$MOUNT_POINT}
    
    # Check interval
    read -p "Check interval in minutes [$CHECK_INTERVAL]: " new_check_interval
    new_check_interval=${new_check_interval:-$CHECK_INTERVAL}
    
    echo
    print_status "New configuration summary for '$server_name':"
    echo "  SSH Key: $new_ssh_key"
    echo "  User@Host: $new_user_host"
    echo "  Remote Path: $new_remote_path"
    echo "  Mount Point: $new_mount_point"
    echo "  Check Interval: $new_check_interval minutes"
    echo
    
    read -p "Is this correct? (y/N): " confirm
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_error "Edit cancelled"
        return 1
    fi
    
    # Update configuration
    print_status "Updating configuration..."
    cat > "$CONFIG_DIR/$server_name.conf" << EOF
# Auto-mount configuration for $server_name
# Generated on $(date)

# Server name
SERVER_NAME="$server_name"

# SSH Key path
SSH_KEY="$new_ssh_key"

# User@Host
USER_HOST="$new_user_host"

# Remote path on the server
REMOTE_PATH="$new_remote_path"

# Local mount point
MOUNT_POINT="$new_mount_point"

# Check interval in minutes
CHECK_INTERVAL="$new_check_interval"
EOF

    chmod 644 "$CONFIG_DIR/$server_name.conf"
    print_status "Configuration updated"
    
    # Regenerate script
    generate_server_script "$server_name"
    
    # Update cron job
    create_cron_job "$server_name"
    
    # Update log file
    create_log_file "$server_name"
    
    print_status "Server '$server_name' updated successfully!"
    echo
    print_status "To view logs: tail -f $LOG_DIR/$server_name.log"
    print_status "To manually run: $BIN_DIR/auto-mount-$server_name.sh"
}

# Function to show help
show_help() {
    echo "Auto-mount SFTP Service Manager v$CURRENT_VERSION"
    echo "================================================"
    echo
    echo "Repository: $REPO_URL"
    echo "Website: $WEBSITE_URL"
    echo
    echo "Usage: $0 [COMMAND]"
    echo
    echo "Commands:"
    echo "  add       Add a new server configuration"
    echo "  edit      Edit an existing server configuration"
    echo "  list      List all configured servers"
    echo "  remove    Remove a server configuration"
    echo "  uninstall Remove all servers and clean up"
    echo "  update    Check for updates"
    echo "  help      Show this help message"
    echo
    echo "Examples:"
    echo "  $0 add          # Add a new server"
    echo "  $0 edit         # Edit an existing server"
    echo "  $0 list         # List all servers"
    echo "  $0 remove       # Remove a server"
    echo "  $0 update       # Check for updates"
    echo "  $0 uninstall    # Remove everything"
}

# Function to uninstall everything
uninstall_all() {
    print_header "Uninstalling All Auto-mount Services"
    echo
    
    print_warning "This will remove ALL server configurations and files"
    read -p "Are you sure? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Uninstall cancelled"
        return 0
    fi
    
    print_status "Removing all auto-mount services..."
    
    # Remove all server files
    if [[ -d "$CONFIG_DIR" ]]; then
        for config_file in "$CONFIG_DIR"/*.conf; do
            if [[ -f "$config_file" ]]; then
                local server_name=$(basename "$config_file" .conf)
                print_status "Removing server: $server_name"
                
                rm -f "$BIN_DIR/auto-mount-$server_name.sh"
                rm -f "$SERVICE_DIR/auto-mount-$server_name.service"
                rm -f "$CRON_DIR/auto-mount-$server_name"
                rm -f "/etc/logrotate.d/auto-mount-$server_name"
                rm -f "$LOG_DIR/$server_name.log"
            fi
        done
        rm -rf "$CONFIG_DIR"
    fi
    
    # Remove directories
    rm -rf "$LOG_DIR"
    
    # Reload systemd
    systemctl daemon-reload
    
    print_status "All auto-mount services removed successfully!"
}

# Main function
main() {
    # Handle commands that don't require root
    case "${1:-add}" in
        "help"|"-h"|"--help")
            show_help
            exit 0
            ;;
        "update")
            check_updates
            exit 0
            ;;
    esac
    
    # Check if running with sudo for all other commands
    check_sudo
    
    # Create directories
    create_directories
    
    # Install dependencies
    install_dependencies
    
    # Handle commands
    case "${1:-add}" in
        "add")
            add_server
            ;;
        "edit")
            edit_server
            ;;
        "list")
            list_servers
            ;;
        "remove")
            remove_server
            ;;
        "uninstall")
            uninstall_all
            ;;
        "update")
            check_updates
            ;;
        *)
            print_error "Unknown command: $1"
            show_help
            exit 1
            ;;
    esac
}

# Run main function
main "$@"