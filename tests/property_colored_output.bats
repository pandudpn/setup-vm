#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 13: Installation step feedback
# Validates: Requirements 13.1
#
# Property: For any installation step that begins, the script should print 
# a colored message indicating the current operation

load test_helper

setup() {
    # Source the script functions
    setup_script_functions
}

# Helper function to strip ANSI color codes
strip_colors() {
    sed $'s/\033\[[0-9;]*m//g'
}

# Helper function to check if output contains ANSI color codes
has_color_codes() {
    grep -q $'\033\[' <<< "$1"
}

# Generate random messages for property testing
generate_random_message() {
    local length=$((RANDOM % 50 + 10))
    head -c "$length" /dev/urandom | base64 | tr -d '\n' | head -c "$length"
}

# Property Test: print_message should always produce colored output
@test "Property 13.1: print_message produces colored output for any message" {
    # Run 100 iterations with random messages
    for i in {1..100}; do
        message=$(generate_random_message)
        
        # Capture output
        output=$(print_message "$message" 2>&1)
        
        # Verify output contains color codes
        if ! has_color_codes "$output"; then
            echo "Failed: Output does not contain color codes"
            echo "Output: $output"
            return 1
        fi
        
        # Verify the message content is present (after stripping colors)
        stripped=$(echo "$output" | strip_colors)
        if [[ "$stripped" != *"$message"* ]]; then
            echo "Failed: Message content not found in output"
            echo "Expected: $message"
            echo "Got: $stripped"
            return 1
        fi
    done
}

# Property Test: print_warning should always produce colored output
@test "Property 13.2: print_warning produces colored output for any warning" {
    # Run 100 iterations with random messages
    for i in {1..100}; do
        message=$(generate_random_message)
        
        # Capture output
        output=$(print_warning "$message" 2>&1)
        
        # Verify output contains color codes
        if ! has_color_codes "$output"; then
            echo "Failed: Output does not contain color codes"
            return 1
        fi
        
        # Verify the message content is present (after stripping colors)
        stripped=$(echo "$output" | strip_colors)
        if [[ "$stripped" != *"WARNING"* ]]; then
            echo "Failed: WARNING label not found"
            return 1
        fi
        if [[ "$stripped" != *"$message"* ]]; then
            echo "Failed: Message content not found"
            return 1
        fi
    done
}

# Property Test: print_error should always produce colored output
@test "Property 13.3: print_error produces colored output for any error" {
    # Run 100 iterations with random messages
    for i in {1..100}; do
        message=$(generate_random_message)
        
        # Capture output (errors go to stderr)
        output=$(print_error "$message" 2>&1)
        
        # Verify output contains color codes
        if ! has_color_codes "$output"; then
            echo "Failed: Output does not contain color codes"
            return 1
        fi
        
        # Verify the message content is present (after stripping colors)
        stripped=$(echo "$output" | strip_colors)
        if [[ "$stripped" != *"ERROR"* ]]; then
            echo "Failed: ERROR label not found"
            return 1
        fi
        if [[ "$stripped" != *"$message"* ]]; then
            echo "Failed: Message content not found"
            return 1
        fi
    done
}

# Property Test: All message functions should produce distinct colors
@test "Property 13.4: Different message types use different colors" {
    # Run 100 iterations
    for i in {1..100}; do
        message=$(generate_random_message)
        
        # Capture outputs
        info_output=$(print_message "$message" 2>&1)
        warn_output=$(print_warning "$message" 2>&1)
        error_output=$(print_error "$message" 2>&1)
        
        # Extract color codes (first ANSI sequence)
        info_color=$(echo "$info_output" | grep -o $'\033\[[0-9;]*m' | head -1)
        warn_color=$(echo "$warn_output" | grep -o $'\033\[[0-9;]*m' | head -1)
        error_color=$(echo "$error_output" | grep -o $'\033\[[0-9;]*m' | head -1)
        
        # Verify colors are different
        if [ "$info_color" = "$warn_color" ]; then
            echo "Failed: info and warning colors are the same"
            return 1
        fi
        if [ "$info_color" = "$error_color" ]; then
            echo "Failed: info and error colors are the same"
            return 1
        fi
        if [ "$warn_color" = "$error_color" ]; then
            echo "Failed: warning and error colors are the same"
            return 1
        fi
    done
}

# Property Test: Messages should always be properly terminated with color reset
@test "Property 13.5: All colored messages end with color reset" {
    # Run 100 iterations
    for i in {1..100}; do
        message=$(generate_random_message)
        
        # Test all three message types
        for func in print_message print_warning print_error; do
            output=$($func "$message" 2>&1)
            
            # Verify output ends with color reset code
            if [[ "$output" != *$'\033[0m' ]]; then
                echo "Failed: $func output does not end with color reset"
                echo "Output: $output"
                return 1
            fi
        done
    done
}

# Property Test: Empty messages should still produce colored output
@test "Property 13.6: Empty messages produce colored output" {
    # Test with empty string
    output=$(print_message "" 2>&1)
    if ! has_color_codes "$output"; then
        echo "Failed: print_message with empty string has no color codes"
        return 1
    fi
    
    output=$(print_warning "" 2>&1)
    if ! has_color_codes "$output"; then
        echo "Failed: print_warning with empty string has no color codes"
        return 1
    fi
    
    output=$(print_error "" 2>&1)
    if ! has_color_codes "$output"; then
        echo "Failed: print_error with empty string has no color codes"
        return 1
    fi
}

# Property Test: Special characters in messages should be handled correctly
@test "Property 13.7: Messages with special characters are displayed correctly" {
    # Test with various special characters
    special_messages=(
        "Message with \$dollar"
        "Message with 'quotes'"
        'Message with "double quotes"'
        "Message with \`backticks\`"
        "Message with newline\ncharacter"
        "Message with tab\tcharacter"
        "Message with * asterisk"
        "Message with & ampersand"
    )
    
    for message in "${special_messages[@]}"; do
        # Test all three message types
        output=$(print_message "$message" 2>&1)
        [ -n "$output" ]
        
        output=$(print_warning "$message" 2>&1)
        [ -n "$output" ]
        
        output=$(print_error "$message" 2>&1)
        [ -n "$output" ]
    done
}
