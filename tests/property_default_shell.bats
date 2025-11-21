#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 6: Default shell configuration
# Validates: Requirements 6.5
#
# Property: For any user for whom the script completes installation, their default 
# shell should be set to zsh

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

# Property Test: set_default_shell sets zsh as default shell
@test "Property 6.1: set_default_shell sets zsh as default shell for any user" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if required commands are not available
    if ! command -v useradd &>/dev/null || ! command -v chsh &>/dev/null; then
        skip "This test requires useradd and chsh"
    fi
    
    # Check if zsh is installed
    if ! command -v zsh &>/dev/null; then
        skip "This test requires zsh to be installed"
    fi
    
    local zsh_path=$(which zsh)
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user (default shell is /bin/bash)
        create_user "$username" >/dev/null 2>&1
        
        # Verify initial shell is bash
        local initial_shell=$(getent passwd "$username" | cut -d: -f7)
        if [ "$initial_shell" != "/bin/bash" ]; then
            echo "Failed: Initial shell for '$username' is '$initial_shell', expected '/bin/bash'"
            return 1
        fi
        
        # Set default shell to zsh
        set_default_shell "$username" >/dev/null 2>&1
        local result=$?
        
        # Verify function succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: set_default_shell returned non-zero exit code for '$username'"
            return 1
        fi
        
        # Verify shell was changed to zsh
        local new_shell=$(getent passwd "$username" | cut -d: -f7)
        if [ "$new_shell" != "$zsh_path" ]; then
            echo "Failed: Shell for '$username' is '$new_shell', expected '$zsh_path'"
            return 1
        fi
    done
}

# Property Test: set_default_shell is idempotent
@test "Property 6.2: set_default_shell is idempotent - multiple calls don't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if required commands are not available
    if ! command -v useradd &>/dev/null || ! command -v chsh &>/dev/null; then
        skip "This test requires useradd and chsh"
    fi
    
    # Check if zsh is installed
    if ! command -v zsh &>/dev/null; then
        skip "This test requires zsh to be installed"
    fi
    
    local zsh_path=$(which zsh)
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Set default shell multiple times
        set_default_shell "$username" >/dev/null 2>&1
        local first_result=$?
        
        set_default_shell "$username" >/dev/null 2>&1
        local second_result=$?
        
        set_default_shell "$username" >/dev/null 2>&1
        local third_result=$?
        
        # All calls should succeed
        if [ $first_result -ne 0 ] || [ $second_result -ne 0 ] || [ $third_result -ne 0 ]; then
            echo "Failed: set_default_shell not idempotent for '$username' (results: $first_result, $second_result, $third_result)"
            return 1
        fi
        
        # Shell should still be zsh
        local final_shell=$(getent passwd "$username" | cut -d: -f7)
        if [ "$final_shell" != "$zsh_path" ]; then
            echo "Failed: Final shell for '$username' is '$final_shell', expected '$zsh_path'"
            return 1
        fi
    done
}

# Property Test: Default shell persists across sessions
@test "Property 6.3: Default shell configuration persists for any user" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if required commands are not available
    if ! command -v useradd &>/dev/null || ! command -v chsh &>/dev/null; then
        skip "This test requires useradd and chsh"
    fi
    
    # Check if zsh is installed
    if ! command -v zsh &>/dev/null; then
        skip "This test requires zsh to be installed"
    fi
    
    local zsh_path=$(which zsh)
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user and set shell
        create_user "$username" >/dev/null 2>&1
        set_default_shell "$username" >/dev/null 2>&1
        
        # Verify shell immediately after setting
        local shell_after_set=$(getent passwd "$username" | cut -d: -f7)
        
        # Re-read from passwd database (simulating persistence check)
        local shell_reread=$(getent passwd "$username" | cut -d: -f7)
        
        # Both reads should return zsh
        if [ "$shell_after_set" != "$zsh_path" ] || [ "$shell_reread" != "$zsh_path" ]; then
            echo "Failed: Shell configuration not persistent for '$username' (after_set: $shell_after_set, reread: $shell_reread)"
            return 1
        fi
    done
}

# Property Test: set_default_shell handles non-existent users gracefully
@test "Property 6.4: set_default_shell returns error for non-existent users" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if not on Linux (useradd/chsh behavior differs on macOS)
    if ! command -v useradd &>/dev/null; then
        skip "This test requires Linux system"
    fi
    
    # Check if zsh is installed
    if ! command -v zsh &>/dev/null; then
        skip "This test requires zsh to be installed"
    fi
    
    # Run 10 iterations with random non-existent usernames
    for i in {1..10}; do
        local username="nonexistent$(head -c 16 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 12)"
        
        # Ensure user doesn't exist
        if id "$username" &>/dev/null; then
            continue
        fi
        
        # Try to set default shell for non-existent user
        set_default_shell "$username" >/dev/null 2>&1
        local result=$?
        
        # Should return non-zero (error)
        if [ $result -eq 0 ]; then
            echo "Failed: set_default_shell returned success for non-existent user '$username'"
            return 1
        fi
    done
}
