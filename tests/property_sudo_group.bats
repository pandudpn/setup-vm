#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 4: User sudo group membership
# Validates: Requirements 2.5
#
# Property: For any newly created user, the user should be added to the sudo group

load test_helper

setup() {
    setup_script_functions
    
    # Store users to clean up
    TEST_USERS=()
}

teardown() {
    # Clean up any test users created
    for user in "${TEST_USERS[@]}"; do
        if id "$user" &>/dev/null; then
            userdel -r "$user" 2>/dev/null || true
        fi
    done
}

# Helper to generate valid random username
generate_valid_username() {
    local prefix="test"
    local suffix=$(head -c 8 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 5)
    echo "${prefix}${suffix}"
}

# Helper to check if user is in a group
user_in_group() {
    local username="$1"
    local groupname="$2"
    
    # Check using groups command
    if groups "$username" 2>/dev/null | grep -qw "$groupname"; then
        return 0
    fi
    
    # Also check using id command
    if id -nG "$username" 2>/dev/null | grep -qw "$groupname"; then
        return 0
    fi
    
    return 1
}

# Property Test: add_to_sudo_group adds user to sudo group
@test "Property 4.1: add_to_sudo_group adds any user to sudo group" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd/usermod are not available (not on Linux)
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null; then
        skip "This test requires useradd and usermod (Linux system)"
    fi
    
    # Check if sudo group exists, skip if not
    if ! getent group sudo &>/dev/null; then
        skip "This test requires sudo group to exist"
    fi
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Ensure user doesn't exist
        if id "$username" &>/dev/null; then
            userdel -r "$username" 2>/dev/null || true
        fi
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Verify user is not in sudo group initially
        if user_in_group "$username" "sudo"; then
            echo "Failed: User '$username' is already in sudo group before add_to_sudo_group"
            return 1
        fi
        
        # Add user to sudo group
        add_to_sudo_group "$username" >/dev/null 2>&1
        local result=$?
        
        # Verify function succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: add_to_sudo_group returned non-zero exit code for '$username'"
            return 1
        fi
        
        # Verify user is now in sudo group
        if ! user_in_group "$username" "sudo"; then
            echo "Failed: User '$username' is not in sudo group after add_to_sudo_group"
            return 1
        fi
    done
}

# Property Test: add_to_sudo_group is idempotent
@test "Property 4.2: add_to_sudo_group is idempotent - calling twice doesn't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd/usermod are not available
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null; then
        skip "This test requires useradd and usermod (Linux system)"
    fi
    
    # Check if sudo group exists
    if ! getent group sudo &>/dev/null; then
        skip "This test requires sudo group to exist"
    fi
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Ensure user doesn't exist
        if id "$username" &>/dev/null; then
            userdel -r "$username" 2>/dev/null || true
        fi
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Add to sudo group first time
        add_to_sudo_group "$username" >/dev/null 2>&1
        local first_result=$?
        
        # Add to sudo group second time
        add_to_sudo_group "$username" >/dev/null 2>&1
        local second_result=$?
        
        # Both calls should succeed
        if [ $first_result -ne 0 ]; then
            echo "Failed: First add_to_sudo_group call failed for '$username'"
            return 1
        fi
        
        if [ $second_result -ne 0 ]; then
            echo "Failed: Second add_to_sudo_group call failed for '$username'"
            return 1
        fi
        
        # User should still be in sudo group
        if ! user_in_group "$username" "sudo"; then
            echo "Failed: User '$username' is not in sudo group after idempotent calls"
            return 1
        fi
    done
}

# Property Test: add_to_sudo_group fails for non-existent users
@test "Property 4.3: add_to_sudo_group fails gracefully for non-existent users" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if usermod is not available
    if ! command -v usermod &>/dev/null; then
        skip "This test requires usermod (Linux system)"
    fi
    
    # Run 100 iterations
    for i in {1..100}; do
        # Generate random username that doesn't exist
        local username="nonexistent$(head -c 16 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 12)"
        
        # Ensure user doesn't exist
        if id "$username" &>/dev/null; then
            continue
        fi
        
        # Try to add non-existent user to sudo group
        add_to_sudo_group "$username" >/dev/null 2>&1
        local result=$?
        
        # Function should return non-zero (failure)
        if [ $result -eq 0 ]; then
            echo "Failed: add_to_sudo_group succeeded for non-existent user '$username'"
            return 1
        fi
    done
}

# Property Test: add_to_sudo_group preserves existing group memberships
@test "Property 4.4: add_to_sudo_group preserves existing group memberships" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd/usermod are not available
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null; then
        skip "This test requires useradd and usermod (Linux system)"
    fi
    
    # Check if sudo group exists
    if ! getent group sudo &>/dev/null; then
        skip "This test requires sudo group to exist"
    fi
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Ensure user doesn't exist
        if id "$username" &>/dev/null; then
            userdel -r "$username" 2>/dev/null || true
        fi
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Get initial groups
        local initial_groups=$(id -nG "$username" 2>/dev/null | tr ' ' '\n' | sort)
        
        # Add to sudo group
        add_to_sudo_group "$username" >/dev/null 2>&1
        
        # Get final groups
        local final_groups=$(id -nG "$username" 2>/dev/null | tr ' ' '\n' | sort)
        
        # Verify all initial groups are still present
        while IFS= read -r group; do
            if [ -n "$group" ] && ! echo "$final_groups" | grep -qw "$group"; then
                echo "Failed: Group '$group' was removed for user '$username'"
                return 1
            fi
        done <<< "$initial_groups"
        
        # Verify sudo group was added
        if ! echo "$final_groups" | grep -qw "sudo"; then
            echo "Failed: sudo group was not added for user '$username'"
            return 1
        fi
    done
}

