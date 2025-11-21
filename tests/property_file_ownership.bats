#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 12: Correct file ownership
# Validates: Requirements 12.1, 12.2, 12.3
#
# Property: For any file or directory created by the script when run with sudo,
# the ownership should be set to the actual user (not root)

load test_helper

setup() {
    setup_script_functions
    
    # Store test users and files to clean up
    TEST_USERS=()
    TEST_FILES=()
}

teardown() {
    # Clean up test files
    for file in "${TEST_FILES[@]}"; do
        rm -rf "$file" 2>/dev/null || true
    done
    
    # Clean up test users
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

# Source the fix_ownership function from the main script
source_fix_ownership() {
    # Source the function from setup-shell.sh
    source setup-shell.sh
}

# Property Test: fix_ownership sets correct ownership for .oh-my-zsh directory
@test "Property 12.1: fix_ownership sets correct ownership for .oh-my-zsh directory" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local user_home="/home/$username"
        
        # Create .oh-my-zsh directory as root
        local oh_my_zsh_dir="${user_home}/.oh-my-zsh"
        mkdir -p "$oh_my_zsh_dir" 2>/dev/null
        TEST_FILES+=("$oh_my_zsh_dir")
        
        # Verify it's owned by root initially
        local initial_owner=$(stat -c '%U' "$oh_my_zsh_dir" 2>/dev/null)
        if [ "$initial_owner" != "root" ]; then
            echo "Setup failed: Directory not owned by root initially"
            return 1
        fi
        
        # Run fix_ownership
        fix_ownership "$username" >/dev/null 2>&1
        
        # Verify ownership changed to user
        local final_owner=$(stat -c '%U' "$oh_my_zsh_dir" 2>/dev/null)
        if [ "$final_owner" != "$username" ]; then
            echo "Failed: .oh-my-zsh directory owned by '$final_owner', expected '$username'"
            return 1
        fi
    done
}

# Property Test: fix_ownership sets correct ownership for .zsh directory
@test "Property 12.2: fix_ownership sets correct ownership for .zsh directory" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local user_home="/home/$username"
        
        # Create .zsh directory as root
        local zsh_dir="${user_home}/.zsh"
        mkdir -p "$zsh_dir" 2>/dev/null
        TEST_FILES+=("$zsh_dir")
        
        # Verify it's owned by root initially
        local initial_owner=$(stat -c '%U' "$zsh_dir" 2>/dev/null)
        if [ "$initial_owner" != "root" ]; then
            echo "Setup failed: Directory not owned by root initially"
            return 1
        fi
        
        # Run fix_ownership
        fix_ownership "$username" >/dev/null 2>&1
        
        # Verify ownership changed to user
        local final_owner=$(stat -c '%U' "$zsh_dir" 2>/dev/null)
        if [ "$final_owner" != "$username" ]; then
            echo "Failed: .zsh directory owned by '$final_owner', expected '$username'"
            return 1
        fi
    done
}

# Property Test: fix_ownership sets correct ownership for .config/ranger directory
@test "Property 12.3: fix_ownership sets correct ownership for .config/ranger directory" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local user_home="/home/$username"
        
        # Create .config/ranger directory as root
        local ranger_dir="${user_home}/.config/ranger"
        mkdir -p "$ranger_dir" 2>/dev/null
        TEST_FILES+=("${user_home}/.config")
        
        # Verify it's owned by root initially
        local initial_owner=$(stat -c '%U' "$ranger_dir" 2>/dev/null)
        if [ "$initial_owner" != "root" ]; then
            echo "Setup failed: Directory not owned by root initially"
            return 1
        fi
        
        # Run fix_ownership
        fix_ownership "$username" >/dev/null 2>&1
        
        # Verify ownership changed to user
        local final_owner=$(stat -c '%U' "$ranger_dir" 2>/dev/null)
        if [ "$final_owner" != "$username" ]; then
            echo "Failed: .config/ranger directory owned by '$final_owner', expected '$username'"
            return 1
        fi
    done
}

# Property Test: fix_ownership sets correct ownership for .zshrc file
@test "Property 12.4: fix_ownership sets correct ownership for .zshrc file" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local user_home="/home/$username"
        
        # Create .zshrc file as root
        local zshrc_file="${user_home}/.zshrc"
        touch "$zshrc_file" 2>/dev/null
        TEST_FILES+=("$zshrc_file")
        
        # Verify it's owned by root initially
        local initial_owner=$(stat -c '%U' "$zshrc_file" 2>/dev/null)
        if [ "$initial_owner" != "root" ]; then
            echo "Setup failed: File not owned by root initially"
            return 1
        fi
        
        # Run fix_ownership
        fix_ownership "$username" >/dev/null 2>&1
        
        # Verify ownership changed to user
        local final_owner=$(stat -c '%U' "$zshrc_file" 2>/dev/null)
        if [ "$final_owner" != "$username" ]; then
            echo "Failed: .zshrc file owned by '$final_owner', expected '$username'"
            return 1
        fi
    done
}

# Property Test: fix_ownership sets correct ownership for .tmux.conf file
@test "Property 12.5: fix_ownership sets correct ownership for .tmux.conf file" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local user_home="/home/$username"
        
        # Create .tmux.conf file as root
        local tmux_conf_file="${user_home}/.tmux.conf"
        touch "$tmux_conf_file" 2>/dev/null
        TEST_FILES+=("$tmux_conf_file")
        
        # Verify it's owned by root initially
        local initial_owner=$(stat -c '%U' "$tmux_conf_file" 2>/dev/null)
        if [ "$initial_owner" != "root" ]; then
            echo "Setup failed: File not owned by root initially"
            return 1
        fi
        
        # Run fix_ownership
        fix_ownership "$username" >/dev/null 2>&1
        
        # Verify ownership changed to user
        local final_owner=$(stat -c '%U' "$tmux_conf_file" 2>/dev/null)
        if [ "$final_owner" != "$username" ]; then
            echo "Failed: .tmux.conf file owned by '$final_owner', expected '$username'"
            return 1
        fi
    done
}

# Property Test: fix_ownership sets correct permissions for files (644)
@test "Property 12.6: fix_ownership sets correct permissions (644) for config files" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local user_home="/home/$username"
        
        # Create config files as root with wrong permissions
        local zshrc_file="${user_home}/.zshrc"
        local tmux_conf_file="${user_home}/.tmux.conf"
        touch "$zshrc_file" "$tmux_conf_file" 2>/dev/null
        chmod 600 "$zshrc_file" "$tmux_conf_file" 2>/dev/null
        TEST_FILES+=("$zshrc_file" "$tmux_conf_file")
        
        # Run fix_ownership
        fix_ownership "$username" >/dev/null 2>&1
        
        # Verify permissions are 644
        local zshrc_perms=$(stat -c '%a' "$zshrc_file" 2>/dev/null)
        local tmux_perms=$(stat -c '%a' "$tmux_conf_file" 2>/dev/null)
        
        if [ "$zshrc_perms" != "644" ]; then
            echo "Failed: .zshrc has permissions '$zshrc_perms', expected '644'"
            return 1
        fi
        
        if [ "$tmux_perms" != "644" ]; then
            echo "Failed: .tmux.conf has permissions '$tmux_perms', expected '644'"
            return 1
        fi
    done
}

# Property Test: fix_ownership sets correct permissions for directories (755)
@test "Property 12.7: fix_ownership sets correct permissions (755) for directories" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        local user_home="/home/$username"
        
        # Create directories as root with wrong permissions
        local oh_my_zsh_dir="${user_home}/.oh-my-zsh"
        local zsh_dir="${user_home}/.zsh"
        local ranger_dir="${user_home}/.config/ranger"
        mkdir -p "$oh_my_zsh_dir" "$zsh_dir" "$ranger_dir" 2>/dev/null
        chmod 700 "$oh_my_zsh_dir" "$zsh_dir" "$ranger_dir" 2>/dev/null
        TEST_FILES+=("$oh_my_zsh_dir" "$zsh_dir" "${user_home}/.config")
        
        # Run fix_ownership
        fix_ownership "$username" >/dev/null 2>&1
        
        # Verify permissions are 755
        local oh_my_zsh_perms=$(stat -c '%a' "$oh_my_zsh_dir" 2>/dev/null)
        local zsh_perms=$(stat -c '%a' "$zsh_dir" 2>/dev/null)
        local ranger_perms=$(stat -c '%a' "$ranger_dir" 2>/dev/null)
        
        if [ "$oh_my_zsh_perms" != "755" ]; then
            echo "Failed: .oh-my-zsh has permissions '$oh_my_zsh_perms', expected '755'"
            return 1
        fi
        
        if [ "$zsh_perms" != "755" ]; then
            echo "Failed: .zsh has permissions '$zsh_perms', expected '755'"
            return 1
        fi
        
        if [ "$ranger_perms" != "755" ]; then
            echo "Failed: .config/ranger has permissions '$ranger_perms', expected '755'"
            return 1
        fi
    done
}

# Property Test: fix_ownership handles non-existent directories gracefully
@test "Property 12.8: fix_ownership handles non-existent directories gracefully" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if useradd is not available
    if ! command -v useradd &>/dev/null; then
        skip "This test requires useradd (Linux system)"
    fi
    
    # Source the fix_ownership function
    source_fix_ownership
    
    # Run 10 iterations
    for i in {1..10}; do
        local username=$(generate_valid_username)
        TEST_USERS+=("$username")
        
        # Create user
        create_user "$username" >/dev/null 2>&1
        
        # Run fix_ownership without creating any directories
        # Should not fail
        fix_ownership "$username" >/dev/null 2>&1
        local result=$?
        
        if [ $result -ne 0 ]; then
            echo "Failed: fix_ownership failed when directories don't exist"
            return 1
        fi
    done
}
