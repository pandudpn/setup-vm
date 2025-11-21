#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 5: Error resilience
# Validates: Requirements 4.2, 8.2, 14.1, 14.2
#
# Property: For any non-critical command failure (package installation, tool installation),
# the script should continue execution with remaining steps and log the failure

load test_helper

setup() {
    setup_script_functions
}

# Helper to create a mock apt-get that fails for specific packages
create_mock_apt_get() {
    local fail_package="$1"
    local mock_dir="$2"
    
    mkdir -p "$mock_dir"
    
    cat > "$mock_dir/apt-get" << 'EOF'
#!/bin/bash
# Mock apt-get that fails for specific packages

# Check if we're being asked to install the fail package
for arg in "$@"; do
    if [ "$arg" = "$FAIL_PACKAGE" ]; then
        echo "E: Unable to locate package $FAIL_PACKAGE" >&2
        exit 100
    fi
done

# Otherwise succeed
exit 0
EOF
    
    chmod +x "$mock_dir/apt-get"
    
    # Set environment variable for the mock
    export FAIL_PACKAGE="$fail_package"
}

# Install basic tools with error handling
install_basic_tools() {
    print_message "Installing basic development tools..."
    
    local packages=("git" "curl" "wget" "build-essential" "unzip")
    local failed_packages=()
    local success_count=0
    
    for package in "${packages[@]}"; do
        print_message "Installing $package..."
        
        if apt-get install -y "$package" 2>&1; then
            print_message "$package installed successfully"
            success_count=$((success_count + 1))
        else
            print_warning "Failed to install $package, continuing with remaining packages..."
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    print_message "Basic tools installation complete: $success_count/${#packages[@]} packages installed"
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
    fi
    
    # Return success even if some packages failed (error resilience)
    return 0
}

# Property Test: install_basic_tools continues on individual package failure
@test "Property 5.1: install_basic_tools returns success even when packages fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if apt-get is not available
    if ! command -v apt-get &>/dev/null; then
        skip "This test requires apt-get (Debian/Ubuntu system)"
    fi
    
    # Run 10 iterations with different failing packages
    local packages=("git" "curl" "wget" "build-essential" "unzip")
    
    for i in {1..10}; do
        # Pick a random package to "fail"
        local fail_index=$((RANDOM % ${#packages[@]}))
        local fail_package="${packages[$fail_index]}"
        
        # Create temporary directory for mock
        local mock_dir=$(mktemp -d)
        
        # Create mock apt-get that fails for specific package
        create_mock_apt_get "$fail_package" "$mock_dir"
        
        # Temporarily modify PATH to use mock
        local original_path="$PATH"
        export PATH="$mock_dir:$PATH"
        
        # Run install_basic_tools - should succeed despite failure
        install_basic_tools >/dev/null 2>&1
        local result=$?
        
        # Restore PATH
        export PATH="$original_path"
        
        # Clean up mock
        rm -rf "$mock_dir"
        unset FAIL_PACKAGE
        
        # Verify function returned success (0) despite package failure
        if [ $result -ne 0 ]; then
            echo "Failed: install_basic_tools returned non-zero ($result) when '$fail_package' failed"
            return 1
        fi
    done
}

# Property Test: Function continues processing remaining packages after failure
@test "Property 5.2: install_basic_tools processes all packages even after failures" {
    # This test verifies that the function doesn't exit early
    # We'll count how many times apt-get is called
    
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if apt-get is not available
    if ! command -v apt-get &>/dev/null; then
        skip "This test requires apt-get (Debian/Ubuntu system)"
    fi
    
    # Run 5 iterations
    for i in {1..5}; do
        # Create temporary directory for mock and counter
        local mock_dir=$(mktemp -d)
        local counter_file="$mock_dir/counter"
        echo "0" > "$counter_file"
        
        # Create mock apt-get that counts calls and fails randomly
        cat > "$mock_dir/apt-get" << EOF
#!/bin/bash
# Mock apt-get that counts calls

# Increment counter
count=\$(cat "$counter_file")
count=\$((count + 1))
echo "\$count" > "$counter_file"

# Randomly fail 50% of the time
if [ \$((RANDOM % 2)) -eq 0 ]; then
    exit 100
fi

exit 0
EOF
        
        chmod +x "$mock_dir/apt-get"
        
        # Temporarily modify PATH to use mock
        local original_path="$PATH"
        export PATH="$mock_dir:$PATH"
        
        # Run install_basic_tools
        install_basic_tools >/dev/null 2>&1
        
        # Restore PATH
        export PATH="$original_path"
        
        # Check counter - should be 5 (one for each package)
        local call_count=$(cat "$counter_file")
        
        # Clean up mock
        rm -rf "$mock_dir"
        
        # Verify all 5 packages were attempted
        if [ "$call_count" -ne 5 ]; then
            echo "Failed: Expected 5 apt-get calls, got $call_count (function stopped early)"
            return 1
        fi
    done
}

# Property Test: Error messages are logged but don't stop execution
@test "Property 5.3: install_basic_tools logs warnings for failed packages" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if apt-get is not available
    if ! command -v apt-get &>/dev/null; then
        skip "This test requires apt-get (Debian/Ubuntu system)"
    fi
    
    # Run 10 iterations
    for i in {1..10}; do
        # Create temporary directory for mock
        local mock_dir=$(mktemp -d)
        local fail_package="curl"
        
        # Create mock apt-get that fails for curl
        create_mock_apt_get "$fail_package" "$mock_dir"
        
        # Temporarily modify PATH to use mock
        local original_path="$PATH"
        export PATH="$mock_dir:$PATH"
        
        # Run install_basic_tools and capture output
        local output=$(install_basic_tools 2>&1)
        
        # Restore PATH
        export PATH="$original_path"
        
        # Clean up mock
        rm -rf "$mock_dir"
        unset FAIL_PACKAGE
        
        # Verify output contains warning about failed package
        if ! echo "$output" | grep -q "WARNING"; then
            echo "Failed: Output should contain WARNING for failed package"
            echo "Output: $output"
            return 1
        fi
        
        # Verify output mentions the failed package
        if ! echo "$output" | grep -q "$fail_package"; then
            echo "Failed: Output should mention failed package '$fail_package'"
            echo "Output: $output"
            return 1
        fi
    done
}

# Property Test: Function returns 0 even with all packages failing
@test "Property 5.4: install_basic_tools returns 0 even when all packages fail" {
    # Skip if not running as root
    if [ "$(id -u)" -ne 0 ]; then
        skip "This test requires root privileges"
    fi
    
    # Skip if apt-get is not available
    if ! command -v apt-get &>/dev/null; then
        skip "This test requires apt-get (Debian/Ubuntu system)"
    fi
    
    # Run 10 iterations
    for i in {1..10}; do
        # Create temporary directory for mock
        local mock_dir=$(mktemp -d)
        
        # Create mock apt-get that always fails
        cat > "$mock_dir/apt-get" << 'EOF'
#!/bin/bash
# Mock apt-get that always fails
exit 100
EOF
        
        chmod +x "$mock_dir/apt-get"
        
        # Temporarily modify PATH to use mock
        local original_path="$PATH"
        export PATH="$mock_dir:$PATH"
        
        # Run install_basic_tools - should still return 0
        install_basic_tools >/dev/null 2>&1
        local result=$?
        
        # Restore PATH
        export PATH="$original_path"
        
        # Clean up mock
        rm -rf "$mock_dir"
        
        # Verify function returned success (0) despite all failures
        if [ $result -ne 0 ]; then
            echo "Failed: install_basic_tools returned non-zero ($result) when all packages failed"
            return 1
        fi
    done
}
