#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 1: User identification with sudo
# Validates: Requirements 1.2
#
# Property: For any user who executes the script with sudo, the script should 
# correctly identify the actual user (SUDO_USER) and their home directory

load test_helper

setup() {
    setup_script_functions
}

# Property Test: get_actual_user correctly identifies SUDO_USER
@test "Property 1.1: get_actual_user identifies SUDO_USER when set" {
    # Run 100 iterations with different simulated users
    for i in {1..100}; do
        # Generate random username (alphanumeric, 3-10 chars)
        local random_user="user$(head -c 8 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 6)"
        
        # Simulate SUDO_USER environment
        export SUDO_USER="$random_user"
        
        # Call get_actual_user
        get_actual_user >/dev/null 2>&1
        
        # Verify ACTUAL_USER is set to SUDO_USER
        if [ "$ACTUAL_USER" != "$random_user" ]; then
            echo "Failed: ACTUAL_USER should be '$random_user' but got '$ACTUAL_USER'"
            return 1
        fi
        
        # Verify USER_HOME is set correctly
        expected_home="/home/$random_user"
        if [ "$USER_HOME" != "$expected_home" ]; then
            echo "Failed: USER_HOME should be '$expected_home' but got '$USER_HOME'"
            return 1
        fi
    done
    
    # Clean up
    unset SUDO_USER
}

# Property Test: get_actual_user handles root when SUDO_USER is not set
@test "Property 1.2: get_actual_user defaults to root when SUDO_USER is not set" {
    # Run 100 iterations
    for i in {1..100}; do
        # Ensure SUDO_USER is not set
        unset SUDO_USER
        
        # Call get_actual_user
        get_actual_user >/dev/null 2>&1
        
        # Verify ACTUAL_USER is set to root
        if [ "$ACTUAL_USER" != "root" ]; then
            echo "Failed: ACTUAL_USER should be 'root' but got '$ACTUAL_USER'"
            return 1
        fi
        
        # Verify USER_HOME is set to /root
        if [ "$USER_HOME" != "/root" ]; then
            echo "Failed: USER_HOME should be '/root' but got '$USER_HOME'"
            return 1
        fi
    done
}

# Property Test: get_actual_user handles root as SUDO_USER
@test "Property 1.3: get_actual_user defaults to root when SUDO_USER is root" {
    # Run 100 iterations
    for i in {1..100}; do
        # Set SUDO_USER to root
        export SUDO_USER="root"
        
        # Call get_actual_user
        get_actual_user >/dev/null 2>&1
        
        # Verify ACTUAL_USER is set to root (not SUDO_USER)
        if [ "$ACTUAL_USER" != "root" ]; then
            echo "Failed: ACTUAL_USER should be 'root' but got '$ACTUAL_USER'"
            return 1
        fi
        
        # Verify USER_HOME is set to /root
        if [ "$USER_HOME" != "/root" ]; then
            echo "Failed: USER_HOME should be '/root' but got '$USER_HOME'"
            return 1
        fi
    done
    
    # Clean up
    unset SUDO_USER
}

# Property Test: get_actual_user is idempotent
@test "Property 1.4: get_actual_user produces same result when called multiple times" {
    # Run 100 iterations
    for i in {1..100}; do
        # Generate random username
        local random_user="user$(head -c 8 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 6)"
        export SUDO_USER="$random_user"
        
        # Call get_actual_user first time
        get_actual_user >/dev/null 2>&1
        local first_user="$ACTUAL_USER"
        local first_home="$USER_HOME"
        
        # Call get_actual_user second time
        get_actual_user >/dev/null 2>&1
        local second_user="$ACTUAL_USER"
        local second_home="$USER_HOME"
        
        # Verify results are identical
        if [ "$first_user" != "$second_user" ]; then
            echo "Failed: ACTUAL_USER changed from '$first_user' to '$second_user'"
            return 1
        fi
        
        if [ "$first_home" != "$second_home" ]; then
            echo "Failed: USER_HOME changed from '$first_home' to '$second_home'"
            return 1
        fi
    done
    
    # Clean up
    unset SUDO_USER
}

# Property Test: get_actual_user handles empty SUDO_USER
@test "Property 1.5: get_actual_user handles empty SUDO_USER string" {
    # Run 100 iterations
    for i in {1..100}; do
        # Set SUDO_USER to empty string
        export SUDO_USER=""
        
        # Call get_actual_user
        get_actual_user >/dev/null 2>&1
        
        # Verify ACTUAL_USER defaults to root
        if [ "$ACTUAL_USER" != "root" ]; then
            echo "Failed: ACTUAL_USER should be 'root' but got '$ACTUAL_USER'"
            return 1
        fi
        
        # Verify USER_HOME is set to /root
        if [ "$USER_HOME" != "/root" ]; then
            echo "Failed: USER_HOME should be '/root' but got '$USER_HOME'"
            return 1
        fi
    done
    
    # Clean up
    unset SUDO_USER
}

