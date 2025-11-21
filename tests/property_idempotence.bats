#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 3: Script idempotence
# Validates: Requirements 2.3, 6.3, 7.3, 11.1
#
# Property: For any script execution, running the script multiple times should not 
# fail or create duplicate configurations (user creation, Oh My Zsh installation, 
# alias additions, etc.)

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
            # Clean up Oh My Zsh and zsh plugins
            local user_home=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
            if [ -n "$user_home" ] && [ -d "$user_home" ]; then
                rm -rf "${user_home}/.oh-my-zsh" 2>/dev/null || true
                rm -rf "${user_home}/.zsh" 2>/dev/null || true
            fi
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

# Property Test: User creation is idempotent
@test "Property 3.1: create_user is idempotent - multiple calls don't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
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
        
        # Create user multiple times
        create_user "$username" >/dev/null 2>&1
        local first_result=$?
        
        create_user "$username" >/dev/null 2>&1
        local second_result=$?
        
        create_user "$username" >/dev/null 2>&1
        local third_result=$?
        
        # All calls should succeed (return 0)
        if [ $first_result -ne 0 ] || [ $second_result -ne 0 ] || [ $third_result -ne 0 ]; then
            echo "Failed: create_user not idempotent for '$username' (results: $first_result, $second_result, $third_result)"
            return 1
        fi
        
        # User should exist
        if ! id "$username" &>/dev/null; then
            echo "Failed: User '$username' does not exist after idempotent calls"
            return 1
        fi
    done
}

# Property Test: Oh My Zsh installation is idempotent
@test "Property 3.2: install_oh_my_zsh is idempotent - multiple calls don't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if required commands are not available
    if ! command -v useradd &>/dev/null || ! command -v curl &>/dev/null || ! command -v git &>/dev/null; then
        skip "This test requires useradd, curl, and git"
    fi
    
    # Run 5 iterations (reduced due to network operations)
    for i in {1..5}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        local user_home="/home/$username"
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Install Oh My Zsh multiple times
        install_oh_my_zsh "$username" "$user_home" >/dev/null 2>&1
        local first_result=$?
        
        install_oh_my_zsh "$username" "$user_home" >/dev/null 2>&1
        local second_result=$?
        
        install_oh_my_zsh "$username" "$user_home" >/dev/null 2>&1
        local third_result=$?
        
        # All calls should succeed (return 0)
        if [ $first_result -ne 0 ] || [ $second_result -ne 0 ] || [ $third_result -ne 0 ]; then
            echo "Failed: install_oh_my_zsh not idempotent for '$username' (results: $first_result, $second_result, $third_result)"
            return 1
        fi
        
        # Oh My Zsh directory should exist
        if [ ! -d "${user_home}/.oh-my-zsh" ]; then
            echo "Failed: Oh My Zsh directory does not exist for '$username'"
            return 1
        fi
    done
}

# Property Test: Zsh plugins installation is idempotent
@test "Property 3.3: install_zsh_plugins is idempotent - multiple calls don't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if required commands are not available
    if ! command -v useradd &>/dev/null || ! command -v git &>/dev/null; then
        skip "This test requires useradd and git"
    fi
    
    # Run 5 iterations (reduced due to network operations)
    for i in {1..5}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        local user_home="/home/$username"
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Install plugins multiple times
        install_zsh_plugins "$username" "$user_home" >/dev/null 2>&1
        local first_result=$?
        
        install_zsh_plugins "$username" "$user_home" >/dev/null 2>&1
        local second_result=$?
        
        install_zsh_plugins "$username" "$user_home" >/dev/null 2>&1
        local third_result=$?
        
        # All calls should succeed (return 0)
        if [ $first_result -ne 0 ] || [ $second_result -ne 0 ] || [ $third_result -ne 0 ]; then
            echo "Failed: install_zsh_plugins not idempotent for '$username' (results: $first_result, $second_result, $third_result)"
            return 1
        fi
        
        # Plugin directories should exist
        if [ ! -d "${user_home}/.zsh" ]; then
            echo "Failed: .zsh directory does not exist for '$username'"
            return 1
        fi
    done
}

# Property Test: update_oh_my_zsh is idempotent
@test "Property 3.4: update_oh_my_zsh is idempotent - multiple calls don't fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if required commands are not available
    if ! command -v useradd &>/dev/null || ! command -v curl &>/dev/null || ! command -v git &>/dev/null; then
        skip "This test requires useradd, curl, and git"
    fi
    
    # Run 3 iterations (reduced due to network operations)
    for i in {1..3}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        local user_home="/home/$username"
        
        # Create user and install Oh My Zsh
        create_user "$username" >/dev/null 2>&1
        install_oh_my_zsh "$username" "$user_home" >/dev/null 2>&1
        
        # Update Oh My Zsh multiple times
        update_oh_my_zsh "$username" "$user_home" >/dev/null 2>&1
        local first_result=$?
        
        update_oh_my_zsh "$username" "$user_home" >/dev/null 2>&1
        local second_result=$?
        
        update_oh_my_zsh "$username" "$user_home" >/dev/null 2>&1
        local third_result=$?
        
        # All calls should succeed (return 0)
        if [ $first_result -ne 0 ] || [ $second_result -ne 0 ] || [ $third_result -ne 0 ]; then
            echo "Failed: update_oh_my_zsh not idempotent for '$username' (results: $first_result, $second_result, $third_result)"
            return 1
        fi
    done
}
