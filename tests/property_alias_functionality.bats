#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 11: Alias functionality
# Validates: Requirements 11.3
#
# Property: For any configured alias (ll, la, fm, bat), the alias should 
# execute the intended command correctly

load test_helper

setup() {
    setup_script_functions
    
    # Create temporary test directory
    TEST_DIR=$(mktemp -d)
}

teardown() {
    # Clean up test directory
    if [ -n "$TEST_DIR" ] && [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Property Test: All required aliases are defined in .zshrc
@test "Property 11.1: create_zshrc defines all required aliases (ll, la, l, .., ..., vi, fm)" {
    # Run 100 iterations to test property across multiple file creations
    for i in {1..100}; do
        local filepath="${TEST_DIR}/zshrc_aliases_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        local result=$?
        
        # Verify creation succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: create_zshrc returned non-zero exit code on iteration $i"
            return 1
        fi
        
        # Verify file exists
        if [ ! -f "$filepath" ]; then
            echo "Failed: .zshrc file not created at '$filepath' on iteration $i"
            return 1
        fi
        
        # Required aliases with their expected commands
        # Format: "alias_name:expected_command_pattern"
        local required_aliases=(
            "ll:ls -lah"
            "la:ls -A"
            "l:ls -CF"
            "..:cd .."
            "...:cd ../.."
            "vi:vim"
            "fm:ranger"
        )
        
        # Verify each alias is present with correct command
        for alias_spec in "${required_aliases[@]}"; do
            local alias_name="${alias_spec%%:*}"
            local expected_cmd="${alias_spec#*:}"
            
            # Check if alias definition exists
            if ! grep -q "alias ${alias_name}=" "$filepath"; then
                echo "Failed: .zshrc missing alias definition for '$alias_name' on iteration $i"
                return 1
            fi
            
            # Check if alias points to expected command
            if ! grep -q "alias ${alias_name}='${expected_cmd}'" "$filepath"; then
                echo "Failed: alias '$alias_name' doesn't map to expected command '$expected_cmd' on iteration $i"
                return 1
            fi
        done
    done
}

# Property Test: bat/batcat alias handling is present
@test "Property 11.2: create_zshrc includes bat/batcat alias handling logic" {
    # Run 100 iterations
    for i in {1..100}; do
        local filepath="${TEST_DIR}/zshrc_bat_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Verify bat/batcat conditional alias handling exists
        if ! grep -q "batcat" "$filepath"; then
            echo "Failed: .zshrc missing batcat alias handling on iteration $i"
            return 1
        fi
        
        # Verify the conditional checks for both batcat and bat commands
        if ! grep -q "command -v batcat" "$filepath"; then
            echo "Failed: .zshrc missing 'command -v batcat' check on iteration $i"
            return 1
        fi
        
        if ! grep -q "command -v bat" "$filepath"; then
            echo "Failed: .zshrc missing 'command -v bat' check on iteration $i"
            return 1
        fi
        
        # Verify alias bat='batcat' is defined when batcat exists
        if ! grep -q "alias bat='batcat'" "$filepath"; then
            echo "Failed: .zshrc missing 'alias bat=batcat' definition on iteration $i"
            return 1
        fi
    done
}

# Property Test: Aliases are syntactically correct
@test "Property 11.3: All alias definitions in .zshrc are syntactically valid" {
    # Run 100 iterations
    for i in {1..100}; do
        local filepath="${TEST_DIR}/zshrc_syntax_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Extract all alias lines
        local alias_lines=$(grep "^alias " "$filepath" || true)
        
        if [ -z "$alias_lines" ]; then
            echo "Failed: No alias definitions found in .zshrc on iteration $i"
            return 1
        fi
        
        # Check each alias line follows the pattern: alias name='command'
        while IFS= read -r line; do
            # Skip empty lines
            [ -z "$line" ] && continue
            
            # Verify line starts with 'alias '
            if ! echo "$line" | grep -q "^alias "; then
                echo "Failed: Invalid alias line format: '$line' on iteration $i"
                return 1
            fi
            
            # Verify line contains '=' sign
            if ! echo "$line" | grep -q "="; then
                echo "Failed: Alias line missing '=' sign: '$line' on iteration $i"
                return 1
            fi
            
            # Verify line has quotes around the command (either single or double)
            if ! echo "$line" | grep -q "=['\"]"; then
                echo "Failed: Alias command not properly quoted: '$line' on iteration $i"
                return 1
            fi
        done <<< "$alias_lines"
    done
}

# Property Test: Alias definitions don't conflict with each other
@test "Property 11.4: Alias names are unique (no duplicate definitions)" {
    # Run 100 iterations
    for i in {1..100}; do
        local filepath="${TEST_DIR}/zshrc_unique_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Extract all alias names
        local alias_names=$(grep "^alias " "$filepath" | sed 's/alias \([^=]*\)=.*/\1/' | sort)
        
        # Check for duplicates
        local unique_count=$(echo "$alias_names" | sort -u | wc -l)
        local total_count=$(echo "$alias_names" | wc -l)
        
        if [ "$unique_count" -ne "$total_count" ]; then
            echo "Failed: Duplicate alias definitions found on iteration $i"
            echo "Unique: $unique_count, Total: $total_count"
            return 1
        fi
    done
}

# Property Test: Aliases are defined in the correct section (after Oh My Zsh is loaded)
@test "Property 11.5: Aliases are defined after Oh My Zsh source command" {
    # Run 100 iterations
    for i in {1..100}; do
        local filepath="${TEST_DIR}/zshrc_order_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Get line number of Oh My Zsh source command
        local omz_line=$(grep -n "source.*oh-my-zsh.sh" "$filepath" | cut -d: -f1)
        
        if [ -z "$omz_line" ]; then
            echo "Failed: Oh My Zsh source command not found on iteration $i"
            return 1
        fi
        
        # Get line number of first custom alias (ll)
        local alias_line=$(grep -n "^alias ll=" "$filepath" | cut -d: -f1)
        
        if [ -z "$alias_line" ]; then
            echo "Failed: Custom alias 'll' not found on iteration $i"
            return 1
        fi
        
        # Verify aliases come after Oh My Zsh is sourced
        if [ "$alias_line" -le "$omz_line" ]; then
            echo "Failed: Aliases defined before Oh My Zsh is sourced (alias at line $alias_line, source at line $omz_line) on iteration $i"
            return 1
        fi
    done
}

# Property Test: Neofetch is configured to run on startup
@test "Property 11.6: Neofetch command is present and properly conditioned" {
    # Run 100 iterations
    for i in {1..100}; do
        local filepath="${TEST_DIR}/zshrc_neofetch_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Verify neofetch is called
        if ! grep -q "neofetch" "$filepath"; then
            echo "Failed: .zshrc doesn't include neofetch command on iteration $i"
            return 1
        fi
        
        # Verify neofetch is conditionally executed (checks if command exists)
        if ! grep -q "command -v neofetch" "$filepath"; then
            echo "Failed: .zshrc doesn't check if neofetch exists before running on iteration $i"
            return 1
        fi
        
        # Verify the conditional structure is correct
        if ! grep -A 1 "command -v neofetch" "$filepath" | grep -q "neofetch"; then
            echo "Failed: neofetch not called within conditional block on iteration $i"
            return 1
        fi
    done
}
