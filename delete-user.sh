#!/bin/bash

################################################################################
# Delete User Script
# 
# Purpose: Safely delete a user and all associated files/configurations
#
# Usage: 
#   sudo ./delete-user.sh <username>
#   sudo ./delete-user.sh <username> --force  # Skip confirmation
#
# Warning: This will permanently delete the user and all their files!
#
################################################################################

# Color codes for output
readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[1;31m'
readonly COLOR_GREEN='\033[1;32m'
readonly COLOR_RESET='\033[0m'

# Print informational message in blue
print_message() {
    local message="$1"
    echo -e "${COLOR_BLUE}>> ${message}${COLOR_RESET}"
}

# Print warning message in yellow
print_warning() {
    local message="$1"
    echo -e "${COLOR_YELLOW}>> WARNING: ${message}${COLOR_RESET}"
}

# Print error message in red
print_error() {
    local message="$1"
    echo -e "${COLOR_RED}>> ERROR: ${message}${COLOR_RESET}" >&2
}

# Print success message in green
print_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}>> ${message}${COLOR_RESET}"
}

# Check if script is running with root privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if user exists
check_user_exists() {
    local username="$1"
    
    if id "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Get user information
get_user_info() {
    local username="$1"
    
    if ! check_user_exists "$username"; then
        return 1
    fi
    
    local user_home=$(getent passwd "$username" 2>/dev/null | cut -d: -f6)
    local user_uid=$(id -u "$username" 2>/dev/null)
    local user_groups=$(groups "$username" 2>/dev/null | cut -d: -f2)
    
    echo "User Information:"
    echo "  Username: $username"
    echo "  UID: $user_uid"
    echo "  Home: $user_home"
    echo "  Groups:$user_groups"
    
    return 0
}

# Check if user is currently logged in
check_user_logged_in() {
    local username="$1"
    
    if who | grep -q "^${username} "; then
        return 0
    fi
    
    if ps -u "$username" &>/dev/null; then
        return 0
    fi
    
    return 1
}

# Kill all user processes
kill_user_processes() {
    local username="$1"
    
    print_message "Checking for running processes owned by '$username'..."
    
    if ps -u "$username" &>/dev/null; then
        print_warning "Found running processes for user '$username'"
        print_message "Terminating processes..."
        
        # First try graceful termination
        if pkill -TERM -u "$username" 2>&1; then
            print_message "Sent TERM signal to processes"
            sleep 2
        fi
        
        # Force kill if still running
        if ps -u "$username" &>/dev/null; then
            print_warning "Some processes still running, forcing termination..."
            if pkill -KILL -u "$username" 2>&1; then
                print_message "Sent KILL signal to processes"
                sleep 1
            fi
        fi
        
        # Verify all processes are terminated
        if ps -u "$username" &>/dev/null; then
            print_error "Failed to terminate all processes for user '$username'"
            return 1
        else
            print_success "All processes terminated successfully"
        fi
    else
        print_message "No running processes found for user '$username'"
    fi
    
    return 0
}

# Delete user and home directory
delete_user() {
    local username="$1"
    
    print_message "Deleting user '$username' and home directory..."
    
    # Use userdel with -r flag to remove home directory and mail spool
    if userdel -r "$username" 2>&1; then
        print_success "User '$username' deleted successfully"
        return 0
    else
        print_error "Failed to delete user '$username'"
        return 1
    fi
}

# Clean up additional files that might not be removed by userdel
cleanup_additional_files() {
    local username="$1"
    local user_home="/home/$username"
    
    print_message "Checking for additional files to clean up..."
    
    # Check if home directory still exists
    if [ -d "$user_home" ]; then
        print_warning "Home directory still exists at $user_home"
        print_message "Removing home directory..."
        
        if rm -rf "$user_home" 2>&1; then
            print_success "Home directory removed"
        else
            print_warning "Failed to remove home directory"
        fi
    fi
    
    # Clean up any remaining files in /tmp
    if [ -d "/tmp" ]; then
        print_message "Cleaning up temporary files..."
        find /tmp -user "$username" -delete 2>/dev/null || true
    fi
    
    # Clean up any cron jobs
    if [ -f "/var/spool/cron/crontabs/$username" ]; then
        print_message "Removing cron jobs..."
        rm -f "/var/spool/cron/crontabs/$username" 2>/dev/null || true
    fi
    
    print_success "Cleanup completed"
}

# Main script
check_root

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Usage: sudo $0 <username> [--force]"
    print_message "Examples:"
    print_message "  sudo $0 deploy              # Delete user 'deploy' with confirmation"
    print_message "  sudo $0 deploy --force      # Delete user 'deploy' without confirmation"
    exit 1
fi

USERNAME="$1"
FORCE=false

if [ "$2" = "--force" ] || [ "$2" = "-f" ]; then
    FORCE=true
fi

# Check if user exists
if ! check_user_exists "$USERNAME"; then
    print_error "User '$USERNAME' does not exist"
    exit 1
fi

# Prevent deletion of system users
USER_UID=$(id -u "$USERNAME" 2>/dev/null)
if [ "$USER_UID" -lt 1000 ]; then
    print_error "Cannot delete system user '$USERNAME' (UID: $USER_UID)"
    print_error "This script only deletes regular users (UID >= 1000)"
    exit 1
fi

# Prevent deletion of current user
CURRENT_USER=$(whoami)
if [ "$USERNAME" = "$CURRENT_USER" ]; then
    print_error "Cannot delete the currently logged in user '$USERNAME'"
    exit 1
fi

# Display user information
print_message "=========================================="
print_message "User Deletion Request"
print_message "=========================================="
echo ""
get_user_info "$USERNAME"
echo ""

# Check if user is logged in
if check_user_logged_in "$USERNAME"; then
    print_warning "User '$USERNAME' is currently logged in or has running processes!"
    print_warning "All processes will be terminated before deletion."
    echo ""
fi

# Confirmation prompt (unless --force is used)
if [ "$FORCE" = false ]; then
    print_warning "=========================================="
    print_warning "WARNING: This action is IRREVERSIBLE!"
    print_warning "=========================================="
    print_warning "This will permanently delete:"
    print_warning "  - User account: $USERNAME"
    print_warning "  - Home directory: /home/$USERNAME"
    print_warning "  - All files and configurations"
    print_warning "  - All running processes"
    echo ""
    
    read -p "Are you sure you want to delete user '$USERNAME'? (yes/no): " confirmation
    
    if [ "$confirmation" != "yes" ]; then
        print_message "Deletion cancelled"
        exit 0
    fi
    
    echo ""
    read -p "Type the username '$USERNAME' to confirm: " username_confirm
    
    if [ "$username_confirm" != "$USERNAME" ]; then
        print_error "Username confirmation does not match"
        print_message "Deletion cancelled"
        exit 1
    fi
fi

echo ""
print_message "=========================================="
print_message "Starting user deletion process..."
print_message "=========================================="
echo ""

# Kill all user processes
if ! kill_user_processes "$USERNAME"; then
    print_error "Failed to terminate user processes"
    print_message "You may need to manually kill processes and try again"
    exit 1
fi

echo ""

# Delete the user
if ! delete_user "$USERNAME"; then
    print_error "User deletion failed"
    exit 1
fi

echo ""

# Clean up additional files
cleanup_additional_files "$USERNAME"

echo ""
print_success "=========================================="
print_success "User '$USERNAME' deleted successfully!"
print_success "=========================================="
echo ""
print_message "Summary:"
print_message "  ✓ User account deleted"
print_message "  ✓ Home directory removed"
print_message "  ✓ All processes terminated"
print_message "  ✓ Additional files cleaned up"
echo ""

