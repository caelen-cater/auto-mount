#!/bin/bash

# Test script for multi-server auto-mount functionality
# This script tests the auto-mount system without actually mounting
#
# Auto-Mount SFTP Service v1.1.0
# Repository: https://github.com/caelen-cater/auto-mount
# Website: https://caelen.dev
# Copyright (c) 2025 Caelen Cater

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[TEST]${NC} $1"
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

# Test configuration
TEST_SERVER="test-server"
TEST_CONFIG_DIR="/tmp/auto-mount-test"
TEST_CONFIG="$TEST_CONFIG_DIR/$TEST_SERVER.conf"
TEST_LOG="/tmp/auto-mount-test.log"
TEST_MOUNT="/tmp/test-mount"
TEST_SCRIPT="/tmp/auto-mount-$TEST_SERVER.sh"

print_header "Testing Multi-Server Auto-Mount System"
echo

print_status "Creating test configuration..."

# Create test config directory
mkdir -p "$TEST_CONFIG_DIR"

# Create test config
cat > "$TEST_CONFIG" << EOF
# Test configuration for $TEST_SERVER
SERVER_NAME="$TEST_SERVER"
SSH_KEY="/home/test/.ssh/id_rsa"
USER_HOST="test@test-server.com"
REMOTE_PATH="/home/test/data"
MOUNT_POINT="$TEST_MOUNT"
CHECK_INTERVAL="5"
EOF

# Create test mount point
mkdir -p "$TEST_MOUNT"

print_status "Testing auto-mount script generation..."

# Test the script generation by running the install script
if CONFIG_FILE="$TEST_CONFIG" LOG_FILE="$TEST_LOG" /usr/local/bin/auto-mount-$TEST_SERVER.sh 2>/dev/null; then
    print_status "Auto-mount script executed successfully"
else
    print_warning "Auto-mount script failed (this is expected if SSH key doesn't exist)"
fi

# Check if log was created
if [[ -f "$TEST_LOG" ]]; then
    print_status "Log file created successfully"
    echo "Log contents:"
    cat "$TEST_LOG"
else
    print_error "Log file was not created"
fi

print_status "Testing server listing functionality..."

# Test the list functionality
if sudo ./install.sh list > /dev/null 2>&1; then
    print_status "List functionality works"
else
    print_warning "List functionality failed (this is expected if no servers are configured)"
fi

print_status "Testing help functionality..."

# Test the help functionality
if ./install.sh help > /dev/null 2>&1; then
    print_status "Help functionality works"
else
    print_error "Help functionality failed"
fi

# Cleanup
print_status "Cleaning up test files..."
rm -f "$TEST_CONFIG" "$TEST_LOG" "$TEST_SCRIPT"
rmdir "$TEST_MOUNT" 2>/dev/null || true
rmdir "$TEST_CONFIG_DIR" 2>/dev/null || true

print_status "Test completed!"
echo
print_status "To test with real servers, run:"
print_status "  sudo ./install.sh add"
