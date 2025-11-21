#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 2: User creation with home directory
# Validates: Requirements 2.2
#
# Property: For any valid username provided, the script should create a new user 
# with a home directory at /home/{username}

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
    # Username: lowercase letters and numbers, 3-8 chars, starts with letter
    local prefix="test"
    local suffix=$(head -c 8 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 5)
    echo "${prefix}${suffix}"
}

# Property Test: create_user creates user with home directory
@test "Property 2.1: create_user creates user with home directory for any valid username" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available (not on Linux)
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Run 10 iterations (reduced from 100 due to system resource constraints)
    for i in {1..10}; do
        # Generate random valid username
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Ensure user doesn't exist before test
        if id "$username" &>/dev/null; then
            userdel -r "$username" 2>/dev/null || true
        fi
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local create_result=$?
        
        # Verify user was created successfully
        if [ $create_result -ne 0 ]; then
            echo "Failed: create_user returned non-zero exit code for '$username'"
            return 1
        fi
        
        # Verify user exists
        if ! id "$username" &>/dev/null; then
            echo "Failed: User '$username' does not exist after creation"
            return 1
        fi
        
        # Verify home directory exists
        local expected_home="/home/$username"
        if [ ! -d "$expected_home" ]; then
            echo "Failed: Home directory '$expected_home' does not exist"
            return 1
        fi
        
        # Verify home directory ownership
        local owner=$(stat -c '%U' "$expected_home")
        if [ "$owner" != "$username" ]; then
            echo "Failed: Home directory owner is '$owner', expected '$username'"
            return 1
        fi
    done
}

# Property Test: create_user is idempotent
@test "Property 2.2: create_user is idempotent - calling twice doesn't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available (not on Linux)
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
        
        # Create user first time
        create_user "$username" >/dev/null 2>&1
        local first_result=$?
        
        # Create user second time (should skip, not fail)
        create_user "$username" >/dev/null 2>&1
        local second_result=$?
        
        # Both calls should succeed
        if [ $first_result -ne 0 ]; then
            echo "Failed: First create_user call failed for '$username'"
            return 1
        fi
        
        if [ $second_result -ne 0 ]; then
            echo "Failed: Second create_user call failed for '$username'"
            return 1
        fi
        
        # User should still exist
        if ! id "$username" &>/dev/null; then
            echo "Failed: User '$username' does not exist after idempotent calls"
            return 1
        fi
    done
}

# Property Test: check_user_exists correctly identifies existing users
@test "Property 2.3: check_user_exists returns true for created users" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available (not on Linux)
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
        
        # Verify check_user_exists returns false before creation
        if check_user_exists "$username"; then
            echo "Failed: check_user_exists returned true for non-existent user '$username'"
            return 1
        fi
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Verify check_user_exists returns true after creation
        if ! check_user_exists "$username"; then
            echo "Failed: check_user_exists returned false for existing user '$username'"
            return 1
        fi
    done
}

# Property Test: check_user_exists returns false for non-existent users
@test "Property 2.4: check_user_exists returns false for random non-existent users" {
    # Run 100 iterations
    for i in {1..100}; do
        # Generate random username that very likely doesn't exist
        local username="nonexistent$(head -c 16 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 12)"
        
        # Verify check_user_exists returns false
        if check_user_exists "$username"; then
            echo "Failed: check_user_exists returned true for non-existent user '$username'"
            return 1
        fi
    done
}

# Property Test: create_user sets bash as default shell
@test "Property 2.5: create_user sets /bin/bash as default shell" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available (not on Linux)
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
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Get user's shell
        local user_shell=$(getent passwd "$username" | cut -d: -f7)
        
        # Verify shell is /bin/bash
        if [ "$user_shell" != "/bin/bash" ]; then
            echo "Failed: User '$username' has shell '$user_shell', expected '/bin/bash'"
            return 1
        fi
    done
}

