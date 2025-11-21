#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 14: Warning display without stopping
# Validates: Requirements 13.2
#
# Property: For any warning that occurs during execution, the script should 
# display the warning message and continue execution

load test_helper

setup() {
    setup_script_functions
}

# Helper function to strip ANSI color codes
strip_colors() {
    sed 's/\033\[[0-9;]*m//g'
}

# Helper function to check if output contains warning
has_warning() {
    grep -q "WARNING" <<< "$1"
}

# Generate random warning messages for property testing
generate_random_warning() {
    local length=$((RANDOM % 50 + 10))
    head -c "$length" /dev/urandom | base64 | tr -d '\n' | head -c "$length"
}

# Property Test: print_warning displays message and returns 0 (doesn't stop execution)
@test "Property 14.1: print_warning displays warning and returns success" {
    # Run 100 iterations with random warning messages
    for i in {1..100}; do
        warning=$(generate_random_warning)
        
        # Capture output and return code
        output=$(print_warning "$warning" 2>&1)
        result=$?
        
        # Verify function returned 0 (success - doesn't stop execution)
        if [ $result -ne 0 ]; then
            echo "Failed: print_warning returned non-zero ($result)"
            return 1
        fi
        
        # Verify output contains WARNING label
        if ! has_warning "$output"; then
            echo "Failed: Output does not contain WARNING label"
            echo "Output: $output"
            return 1
        fi
        
        # Verify the warning message is present
        stripped=$(echo "$output" | strip_colors)
        if [[ "$stripped" != *"$warning"* ]]; then
            echo "Failed: Warning message not found in output"
            echo "Expected: $warning"
            echo "Got: $stripped"
            return 1
        fi
    done
}

# Property Test: Functions that use print_warning continue execution
@test "Property 14.2: Functions with warnings continue to completion" {
    # Test a sequence of operations where warnings occur but execution continues
    
    # Run 50 iterations
    for i in {1..50}; do
        warning1=$(generate_random_warning)
        warning2=$(generate_random_warning)
        warning3=$(generate_random_warning)
        
        # Create a test function that prints multiple warnings
        test_function() {
            print_warning "$warning1"
            local result1=$?
            
            print_warning "$warning2"
            local result2=$?
            
            print_warning "$warning3"
            local result3=$?
            
            # All should return 0
            if [ $result1 -ne 0 ] || [ $result2 -ne 0 ] || [ $result3 -ne 0 ]; then
                return 1
            fi
            
            # Function completes successfully
            return 0
        }
        
        # Run test function and capture output
        output=$(test_function 2>&1)
        result=$?
        
        # Verify function completed successfully
        if [ $result -ne 0 ]; then
            echo "Failed: Function with warnings did not complete successfully"
            return 1
        fi
        
        # Verify all three warnings were displayed
        warning_count=$(echo "$output" | grep -c "WARNING")
        if [ $warning_count -ne 3 ]; then
            echo "Failed: Expected 3 warnings, got $warning_count"
            echo "Output: $output"
            return 1
        fi
    done
}

# Property Test: Warnings don't affect subsequent operations
@test "Property 14.3: Operations after warnings execute normally" {
    # Run 50 iterations
    for i in {1..50}; do
        warning=$(generate_random_warning)
        message=$(generate_random_warning)
        
        # Create a test function that has warning then normal operation
        test_function() {
            print_warning "$warning"
            print_message "$message"
            return 0
        }
        
        # Run test function
        output=$(test_function 2>&1)
        result=$?
        
        # Verify function completed successfully
        if [ $result -ne 0 ]; then
            echo "Failed: Function did not complete after warning"
            return 1
        fi
        
        # Verify both warning and message are in output
        if ! has_warning "$output"; then
            echo "Failed: Warning not found in output"
            return 1
        fi
        
        stripped=$(echo "$output" | strip_colors)
        if [[ "$stripped" != *"$message"* ]]; then
            echo "Failed: Message after warning not found"
            return 1
        fi
    done
}

# Property Test: Multiple consecutive warnings don't stop execution
@test "Property 14.4: Multiple consecutive warnings don't stop execution" {
    # Run 20 iterations with varying numbers of warnings
    for i in {1..20}; do
        # Generate random number of warnings (5-15)
        num_warnings=$((RANDOM % 11 + 5))
        
        # Create test function with multiple warnings
        test_function() {
            for j in $(seq 1 $num_warnings); do
                local warning=$(generate_random_warning)
                print_warning "$warning"
            done
            return 0
        }
        
        # Run test function
        output=$(test_function 2>&1)
        result=$?
        
        # Verify function completed successfully
        if [ $result -ne 0 ]; then
            echo "Failed: Function with $num_warnings warnings did not complete"
            return 1
        fi
        
        # Verify all warnings were displayed
        warning_count=$(echo "$output" | grep -c "WARNING")
        if [ $warning_count -ne $num_warnings ]; then
            echo "Failed: Expected $num_warnings warnings, got $warning_count"
            return 1
        fi
    done
}

# Property Test: Warnings in error conditions don't prevent continuation
@test "Property 14.5: Warnings from failed operations allow continuation" {
    # Simulate functions that fail but use warnings instead of errors
    
    # Run 50 iterations
    for i in {1..50}; do
        warning=$(generate_random_warning)
        
        # Create a function that "fails" but warns and continues
        failing_operation() {
            # Simulate a failed operation
            if false; then
                return 0
            else
                print_warning "$warning"
                return 0  # Return success to continue
            fi
        }
        
        # Create a workflow with failing operation
        test_workflow() {
            failing_operation
            local result=$?
            
            # Should be able to continue after warning
            if [ $result -eq 0 ]; then
                print_message "Workflow continued after warning"
                return 0
            else
                return 1
            fi
        }
        
        # Run workflow
        output=$(test_workflow 2>&1)
        result=$?
        
        # Verify workflow completed
        if [ $result -ne 0 ]; then
            echo "Failed: Workflow did not continue after warning"
            return 1
        fi
        
        # Verify warning was displayed
        if ! has_warning "$output"; then
            echo "Failed: Warning not displayed"
            return 1
        fi
        
        # Verify continuation message is present
        if ! echo "$output" | grep -q "Workflow continued"; then
            echo "Failed: Workflow did not continue after warning"
            return 1
        fi
    done
}

# Property Test: Empty warnings still allow continuation
@test "Property 14.6: Empty warnings don't stop execution" {
    # Run 50 iterations
    for i in {1..50}; do
        # Test with empty warning
        output=$(print_warning "" 2>&1)
        result=$?
        
        # Verify function returned 0
        if [ $result -ne 0 ]; then
            echo "Failed: print_warning with empty string returned non-zero"
            return 1
        fi
        
        # Verify WARNING label is still present
        if ! has_warning "$output"; then
            echo "Failed: Empty warning should still show WARNING label"
            return 1
        fi
    done
}

# Property Test: Warnings with special characters don't stop execution
@test "Property 14.7: Warnings with special characters allow continuation" {
    # Test with various special characters
    special_warnings=(
        "Warning with \$dollar"
        "Warning with 'quotes'"
        'Warning with "double quotes"'
        "Warning with \`backticks\`"
        "Warning with newline\ncharacter"
        "Warning with tab\tcharacter"
        "Warning with * asterisk"
        "Warning with & ampersand"
        "Warning with | pipe"
        "Warning with ; semicolon"
    )
    
    for warning in "${special_warnings[@]}"; do
        # Test warning display
        output=$(print_warning "$warning" 2>&1)
        result=$?
        
        # Verify function returned 0
        if [ $result -ne 0 ]; then
            echo "Failed: print_warning with special chars returned non-zero"
            echo "Warning: $warning"
            return 1
        fi
        
        # Verify WARNING label is present
        if ! has_warning "$output"; then
            echo "Failed: Warning with special chars missing WARNING label"
            echo "Warning: $warning"
            return 1
        fi
    done
}

