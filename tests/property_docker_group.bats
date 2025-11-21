#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 7: Docker group membership
# Validates: Requirements 9.2
#
# Property: For any user specified during installation, after Docker installation 
# they should be added to the docker group

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

# Helper to add configure_docker_access function to test_helper
configure_docker_access() {
    local username="$1"
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    # Check if docker group exists
    if ! getent group docker &>/dev/null; then
        print_message "Docker group does not exist, creating it..."
        if ! groupadd docker 2>&1; then
            print_error "Failed to create docker group"
            return 1
        fi
    fi
    
    print_message "Adding user '$username' to docker group..."
    
    if usermod -aG docker "$username" 2>&1; then
        print_message "User '$username' added to docker group successfully"
        return 0
    else
        print_error "Failed to add user '$username' to docker group"
        return 1
    fi
}

# Property Test: configure_docker_access adds user to docker group
@test "Property 7.1: configure_docker_access adds any user to docker group" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd/usermod are not available (not on Linux)
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null; then
        skip "This test requires useradd and usermod (Linux system)"
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
        
        # Verify user is not in docker group initially
        if user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is already in docker group before configure_docker_access"
            return 1
        fi
        
        # Configure Docker access (add to docker group)
        configure_docker_access "$username" >/dev/null 2>&1
        local result=$?
        
        # Verify function succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: configure_docker_access returned non-zero exit code for '$username'"
            return 1
        fi
        
        # Verify user is now in docker group
        if ! user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is not in docker group after configure_docker_access"
            return 1
        fi
    done
}

# Property Test: configure_docker_access is idempotent
@test "Property 7.2: configure_docker_access is idempotent - calling twice doesn't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd/usermod are not available
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null; then
        skip "This test requires useradd and usermod (Linux system)"
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
        
        # Configure Docker access first time
        configure_docker_access "$username" >/dev/null 2>&1
        local first_result=$?
        
        # Configure Docker access second time
        configure_docker_access "$username" >/dev/null 2>&1
        local second_result=$?
        
        # Both calls should succeed
        if [ $first_result -ne 0 ]; then
            echo "Failed: First configure_docker_access call failed for '$username'"
            return 1
        fi
        
        if [ $second_result -ne 0 ]; then
            echo "Failed: Second configure_docker_access call failed for '$username'"
            return 1
        fi
        
        # User should still be in docker group
        if ! user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is not in docker group after idempotent calls"
            return 1
        fi
    done
}

# Property Test: configure_docker_access fails for non-existent users
@test "Property 7.3: configure_docker_access fails gracefully for non-existent users" {
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
        
        # Try to configure Docker access for non-existent user
        configure_docker_access "$username" >/dev/null 2>&1
        local result=$?
        
        # Function should return non-zero (failure)
        if [ $result -eq 0 ]; then
            echo "Failed: configure_docker_access succeeded for non-existent user '$username'"
            return 1
        fi
    done
}

# Property Test: configure_docker_access creates docker group if it doesn't exist
@test "Property 7.4: configure_docker_access creates docker group if missing" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd/usermod/groupadd are not available
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null || ! command -v groupadd &>/dev/null; then
        skip "This test requires useradd, usermod, and groupadd (Linux system)"
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
        
        # Remove docker group if it exists (to test creation)
        if getent group docker &>/dev/null; then
            # Only remove if no users are in it (to avoid breaking system)
            local docker_users=$(getent group docker | cut -d: -f4)
            if [ -z "$docker_users" ]; then
                groupdel docker 2>/dev/null || true
            fi
        fi
        
        # Configure Docker access (should create group if needed)
        configure_docker_access "$username" >/dev/null 2>&1
        local result=$?
        
        # Verify function succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: configure_docker_access returned non-zero exit code for '$username'"
            return 1
        fi
        
        # Verify docker group exists
        if ! getent group docker &>/dev/null; then
            echo "Failed: docker group does not exist after configure_docker_access"
            return 1
        fi
        
        # Verify user is in docker group
        if ! user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is not in docker group after configure_docker_access"
            return 1
        fi
    done
}

# Property Test: configure_docker_access preserves existing group memberships
@test "Property 7.5: configure_docker_access preserves existing group memberships" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd/usermod are not available
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null; then
        skip "This test requires useradd and usermod (Linux system)"
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
        
        # Configure Docker access
        configure_docker_access "$username" >/dev/null 2>&1
        
        # Get final groups
        local final_groups=$(id -nG "$username" 2>/dev/null | tr ' ' '\n' | sort)
        
        # Verify all initial groups are still present
        while IFS= read -r group; do
            if [ -n "$group" ] && ! echo "$final_groups" | grep -qw "$group"; then
                echo "Failed: Group '$group' was removed for user '$username'"
                return 1
            fi
        done <<< "$initial_groups"
        
        # Verify docker group was added
        if ! echo "$final_groups" | grep -qw "docker"; then
            echo "Failed: docker group was not added for user '$username'"
            return 1
        fi
    done
}
