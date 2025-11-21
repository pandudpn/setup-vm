#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 9: Configuration backup before overwrite
# Validates: Requirements 10.2
#
# Property: For any existing configuration file (.zshrc, .tmux.conf), the script 
# should create a timestamped backup before overwriting

load test_helper

setup() {
    setup_script_functions
    
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
    TEST_FILES=()
}

teardown() {
    # Clean up test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Helper to generate random file content
generate_random_content() {
    head -c 100 /dev/urandom | base64 | head -c 80
}

# Property Test: backup_existing_config creates timestamped backup
@test "Property 9.1: backup_existing_config creates timestamped backup for any existing file" {
    # Run 100 iterations
    for i in {1..100}; do
        # Generate random filename
        local filename="config_${i}_$(head -c 8 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 6)"
        local filepath="${TEST_DIR}/${filename}"
        TEST_FILES+=("$filepath")
        
        # Create file with random content
        local original_content=$(generate_random_content)
        echo "$original_content" > "$filepath"
        
        # Verify file exists
        if [ ! -f "$filepath" ]; then
            echo "Failed: Test file '$filepath' was not created"
            return 1
        fi
        
        # Call backup_existing_config
        backup_existing_config "$filepath" >/dev/null 2>&1
        local backup_result=$?
        
        # Verify backup succeeded
        if [ $backup_result -ne 0 ]; then
            echo "Failed: backup_existing_config returned non-zero exit code for '$filepath'"
            return 1
        fi
        
        # Find backup file (should match pattern: filepath.backup.YYYYMMDDHHMMSS)
        local backup_files=("${filepath}.backup."*)
        
        # Verify at least one backup was created
        if [ ! -f "${backup_files[0]}" ]; then
            echo "Failed: No backup file created for '$filepath'"
            echo "Expected pattern: ${filepath}.backup.*"
            ls -la "$TEST_DIR" >&2
            return 1
        fi
        
        # Verify backup content matches original
        local backup_content=$(cat "${backup_files[0]}")
        if [ "$backup_content" != "$original_content" ]; then
            echo "Failed: Backup content doesn't match original for '$filepath'"
            return 1
        fi
        
        # Verify original file still exists
        if [ ! -f "$filepath" ]; then
            echo "Failed: Original file '$filepath' was removed after backup"
            return 1
        fi
    done
}

# Property Test: backup_existing_config succeeds when file doesn't exist
@test "Property 9.2: backup_existing_config succeeds for non-existent files" {
    # Run 100 iterations
    for i in {1..100}; do
        # Generate random non-existent filepath
        local filename="nonexistent_${i}_$(head -c 8 /dev/urandom | base64 | tr -dc 'a-z0-9' | head -c 6)"
        local filepath="${TEST_DIR}/${filename}"
        
        # Ensure file doesn't exist
        if [ -f "$filepath" ]; then
            rm "$filepath"
        fi
        
        # Call backup_existing_config on non-existent file
        backup_existing_config "$filepath" >/dev/null 2>&1
        local backup_result=$?
        
        # Should succeed (return 0) even though file doesn't exist
        if [ $backup_result -ne 0 ]; then
            echo "Failed: backup_existing_config returned non-zero for non-existent file '$filepath'"
            return 1
        fi
        
        # Verify no backup file was created
        local backup_files=("${filepath}.backup."*)
        if [ -f "${backup_files[0]}" ]; then
            echo "Failed: Backup file created for non-existent file '$filepath'"
            return 1
        fi
    done
}

# Property Test: backup_existing_config creates timestamped backups with delays
@test "Property 9.3: backup_existing_config creates timestamped backups" {
    # Create a single test file
    local filepath="${TEST_DIR}/test_config"
    echo "original content" > "$filepath"
    
    # Create multiple backups with sufficient delay to ensure unique timestamps
    local backup_count=5
    for i in $(seq 1 $backup_count); do
        backup_existing_config "$filepath" >/dev/null 2>&1
        
        # Sleep for 1 second to ensure different timestamps (YYYYMMDDHHMMSS format)
        sleep 1
    done
    
    # Count backup files
    local backup_files=("${filepath}.backup."*)
    local actual_count=0
    
    for backup_file in "${backup_files[@]}"; do
        if [ -f "$backup_file" ]; then
            actual_count=$((actual_count + 1))
        fi
    done
    
    # Verify we have at least backup_count backups (may have more if timestamps collide)
    if [ $actual_count -lt $backup_count ]; then
        echo "Failed: Expected at least $backup_count backups, found $actual_count"
        ls -la "$TEST_DIR" >&2
        return 1
    fi
    
    # Verify all backups have the correct naming pattern
    for backup_file in "${backup_files[@]}"; do
        if [ -f "$backup_file" ]; then
            # Check if filename matches pattern: filepath.backup.YYYYMMDDHHMMSS
            if [[ ! "$backup_file" =~ \.backup\.[0-9]{14}$ ]]; then
                echo "Failed: Backup file '$backup_file' doesn't match expected pattern"
                return 1
            fi
        fi
    done
}

# Property Test: backup preserves file permissions
@test "Property 9.4: backup_existing_config preserves file permissions" {
    # Skip if not on Linux (chmod behavior may differ)
    if ! command -v stat &>/dev/null; then
        skip "This test requires stat command"
    fi
    
    # Run 20 iterations with different permissions
    local permissions=("644" "600" "755" "700" "640")
    
    for i in {1..20}; do
        local filename="perm_test_${i}"
        local filepath="${TEST_DIR}/${filename}"
        TEST_FILES+=("$filepath")
        
        # Create file with random content
        echo "test content $i" > "$filepath"
        
        # Set random permissions
        local perm_index=$((i % ${#permissions[@]}))
        local perm="${permissions[$perm_index]}"
        chmod "$perm" "$filepath"
        
        # Get original permissions
        local original_perms=$(stat -c '%a' "$filepath" 2>/dev/null || stat -f '%A' "$filepath" 2>/dev/null)
        
        # Create backup
        backup_existing_config "$filepath" >/dev/null 2>&1
        
        # Find backup file
        local backup_files=("${filepath}.backup."*)
        
        if [ ! -f "${backup_files[0]}" ]; then
            echo "Failed: No backup created for '$filepath'"
            return 1
        fi
        
        # Get backup permissions
        local backup_perms=$(stat -c '%a' "${backup_files[0]}" 2>/dev/null || stat -f '%A' "${backup_files[0]}" 2>/dev/null)
        
        # Verify permissions match
        if [ "$backup_perms" != "$original_perms" ]; then
            echo "Failed: Backup permissions ($backup_perms) don't match original ($original_perms)"
            return 1
        fi
    done
}
