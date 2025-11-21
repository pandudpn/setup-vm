#!/bin/bash

################################################################################
# Reset User Password Script
# 
# Purpose: Reset password for a user or disable password requirement
#
# Usage: 
#   sudo ./reset-user-password.sh <username>
#   sudo ./reset-user-password.sh <username> --disable
#
################################################################################

# Color codes for output
readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[1;31m'
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

# Main script
check_root

# Check arguments
if [ $# -lt 1 ]; then
    print_error "Usage: sudo $0 <username> [--disable]"
    print_message "Examples:"
    print_message "  sudo $0 deploy              # Set new password for user 'deploy'"
    print_message "  sudo $0 deploy --disable    # Disable password for user 'deploy'"
    exit 1
fi

USERNAME="$1"
DISABLE_PASSWORD=false

if [ "$2" = "--disable" ]; then
    DISABLE_PASSWORD=true
fi

# Check if user exists
if ! check_user_exists "$USERNAME"; then
    print_error "User '$USERNAME' does not exist"
    exit 1
fi

print_message "User '$USERNAME' found"

if [ "$DISABLE_PASSWORD" = true ]; then
    # Disable password
    print_message "Disabling password for user '$USERNAME'..."
    
    if passwd -d "$USERNAME" 2>&1; then
        print_message "Password disabled successfully for '$USERNAME'"
        print_message "User can now login without password (from root or via su)"
        print_message ""
        print_message "To switch to this user: su - $USERNAME"
    else
        print_error "Failed to disable password for '$USERNAME'"
        exit 1
    fi
else
    # Set new password
    print_message "Setting new password for user '$USERNAME'..."
    print_warning "Please enter a password (avoid complex special characters if you have issues)"
    
    if passwd "$USERNAME"; then
        print_message "Password set successfully for '$USERNAME'"
    else
        print_error "Failed to set password for '$USERNAME'"
        print_message ""
        print_message "If you're having issues with special characters, you can:"
        print_message "  1. Use a simpler password"
        print_message "  2. Disable password: sudo $0 $USERNAME --disable"
        exit 1
    fi
fi

print_message ""
print_message "Done!"

