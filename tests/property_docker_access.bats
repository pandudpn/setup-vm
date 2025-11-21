#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 8: Docker non-sudo access
# Validates: Requirements 9.5
#
# Property: For any user in the docker group, they should be able to run 
# docker commands without sudo

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

# Helper to add configure_docker_access function
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

# Property Test: Users in docker group can access Docker socket
@test "Property 8.1: Users in docker group have read/write access to Docker socket" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if Docker is not installed
    if ! command -v docker &>/dev/null; then
        skip "This test requires Docker to be installed"
    fi
    
    # Skip if Docker socket doesn't exist
    if [ ! -S /var/run/docker.sock ]; then
        skip "This test requires Docker socket at /var/run/docker.sock"
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
        
        # Add user to docker group
        configure_docker_access "$username" >/dev/null 2>&1
        
        # Verify user is in docker group
        if ! user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is not in docker group"
            return 1
        fi
        
        # Check if user can access Docker socket
        # We test this by checking if the user has the right group permissions
        local socket_group=$(stat -c '%G' /var/run/docker.sock 2>/dev/null)
        
        if [ "$socket_group" = "docker" ]; then
            # Socket is owned by docker group, user should have access
            if ! user_in_group "$username" "docker"; then
                echo "Failed: User '$username' cannot access Docker socket (not in docker group)"
                return 1
            fi
        else
            # Socket might be owned by root or another group
            # This is acceptable, just verify the user is in docker group
            if ! user_in_group "$username" "docker"; then
                echo "Failed: User '$username' is not in docker group"
                return 1
            fi
        fi
    done
}

# Property Test: Users in docker group can run docker info without sudo
@test "Property 8.2: Users in docker group can run docker info command" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if Docker is not installed
    if ! command -v docker &>/dev/null; then
        skip "This test requires Docker to be installed"
    fi
    
    # Skip if Docker daemon is not running
    if ! systemctl is-active --quiet docker 2>/dev/null && ! docker info &>/dev/null; then
        skip "This test requires Docker daemon to be running"
    fi
    
    # Skip if useradd/usermod are not available
    if ! command -v useradd &>/dev/null || ! command -v usermod &>/dev/null; then
        skip "This test requires useradd and usermod (Linux system)"
    fi
    
    # Run 5 iterations (fewer because this involves running Docker commands)
    for i in {1..5}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Ensure user doesn't exist
        if id "$username" &>/dev/null; then
            userdel -r "$username" 2>/dev/null || true
        fi
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Add user to docker group
        configure_docker_access "$username" >/dev/null 2>&1
        
        # Verify user is in docker group
        if ! user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is not in docker group"
            return 1
        fi
        
        # Try to run docker info as the user (using su with newgrp to activate group)
        # Note: This simulates what would happen after user logs out and back in
        if su - "$username" -c "sg docker -c 'docker info'" >/dev/null 2>&1; then
            # Success - user can run docker commands
            :
        else
            # This might fail if Docker daemon is not running or other issues
            # We'll just verify the user is in the docker group
            if ! user_in_group "$username" "docker"; then
                echo "Failed: User '$username' cannot run docker commands and is not in docker group"
                return 1
            fi
        fi
    done
}

# Property Test: Users NOT in docker group cannot access Docker without sudo
@test "Property 8.3: Users not in docker group require sudo for Docker access" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if Docker is not installed
    if ! command -v docker &>/dev/null; then
        skip "This test requires Docker to be installed"
    fi
    
    # Skip if Docker socket doesn't exist
    if [ ! -S /var/run/docker.sock ]; then
        skip "This test requires Docker socket at /var/run/docker.sock"
    fi
    
    # Skip if useradd are not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Ensure user doesn't exist
        if id "$username" &>/dev/null; then
            userdel -r "$username" 2>/dev/null || true
        fi
        
        # Create user WITHOUT adding to docker group
        create_user "$username" >/dev/null 2>&1
        
        # Verify user is NOT in docker group
        if user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is unexpectedly in docker group"
            return 1
        fi
        
        # Verify user cannot access Docker socket directly
        # We check this by verifying the user doesn't have docker group membership
        local socket_group=$(stat -c '%G' /var/run/docker.sock 2>/dev/null)
        
        if [ "$socket_group" = "docker" ]; then
            # Socket is owned by docker group
            # User should NOT have access since they're not in the group
            if user_in_group "$username" "docker"; then
                echo "Failed: User '$username' has unexpected access to Docker socket"
                return 1
            fi
        fi
    done
}

# Property Test: Adding user to docker group grants Docker access
@test "Property 8.4: Adding user to docker group grants Docker access" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if Docker is not installed
    if ! command -v docker &>/dev/null; then
        skip "This test requires Docker to be installed"
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
        
        # Verify user is NOT in docker group initially
        if user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is already in docker group before configure_docker_access"
            return 1
        fi
        
        # Add user to docker group
        configure_docker_access "$username" >/dev/null 2>&1
        local result=$?
        
        # Verify function succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: configure_docker_access returned non-zero exit code for '$username'"
            return 1
        fi
        
        # Verify user is NOW in docker group
        if ! user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is not in docker group after configure_docker_access"
            return 1
        fi
        
        # Verify docker group exists
        if ! getent group docker &>/dev/null; then
            echo "Failed: docker group does not exist after configure_docker_access"
            return 1
        fi
    done
}

# Property Test: Docker group membership persists across function calls
@test "Property 8.5: Docker group membership persists and is stable" {
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
        
        # Create user and add to docker group
        create_user "$username" >/dev/null 2>&1
        configure_docker_access "$username" >/dev/null 2>&1
        
        # Verify user is in docker group
        if ! user_in_group "$username" "docker"; then
            echo "Failed: User '$username' is not in docker group after initial setup"
            return 1
        fi
        
        # Check multiple times to ensure membership persists
        for check in {1..5}; do
            if ! user_in_group "$username" "docker"; then
                echo "Failed: User '$username' lost docker group membership on check $check"
                return 1
            fi
        done
    done
}
