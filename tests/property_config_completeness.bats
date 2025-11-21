#!/usr/bin/env bats

# Feature: terminal-setup-script, Property 10: Configuration completeness
# Validates: Requirements 10.3
#
# Property: For any configuration file created (.zshrc, .tmux.conf), it should 
# contain all necessary settings for proper functionality

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

# Property Test: create_zshrc creates complete configuration
@test "Property 10.1: create_zshrc contains all required Oh My Zsh settings" {
    # Run 20 iterations with different destination paths
    for i in {1..20}; do
        local filename="zshrc_test_${i}"
        local filepath="${TEST_DIR}/${filename}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        local result=$?
        
        # Verify creation succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: create_zshrc returned non-zero exit code"
            return 1
        fi
        
        # Verify file exists
        if [ ! -f "$filepath" ]; then
            echo "Failed: .zshrc file not created at '$filepath'"
            return 1
        fi
        
        # Verify Oh My Zsh path is set
        if ! grep -q 'export ZSH=' "$filepath"; then
            echo "Failed: .zshrc missing Oh My Zsh path export"
            return 1
        fi
        
        # Verify theme is set
        if ! grep -q 'ZSH_THEME=' "$filepath"; then
            echo "Failed: .zshrc missing theme setting"
            return 1
        fi
        
        # Verify plugins are configured
        if ! grep -q 'plugins=(' "$filepath"; then
            echo "Failed: .zshrc missing plugins configuration"
            return 1
        fi
        
        # Verify Oh My Zsh is sourced
        if ! grep -q 'source.*oh-my-zsh.sh' "$filepath"; then
            echo "Failed: .zshrc missing Oh My Zsh source command"
            return 1
        fi
    done
}

# Property Test: create_zshrc includes all required plugins
@test "Property 10.2: create_zshrc includes required plugins (git, docker, sudo, history, colored-man-pages, command-not-found)" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/zshrc_plugins_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Required plugins
        local required_plugins=("git" "docker" "sudo" "history" "colored-man-pages" "command-not-found")
        
        # Verify each plugin is present
        for plugin in "${required_plugins[@]}"; do
            if ! grep -q "$plugin" "$filepath"; then
                echo "Failed: .zshrc missing required plugin: $plugin"
                return 1
            fi
        done
    done
}

# Property Test: create_zshrc includes all required aliases
@test "Property 10.3: create_zshrc includes required aliases (ll, la, l, .., ..., vi, fm)" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/zshrc_aliases_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Required aliases
        local required_aliases=("alias ll=" "alias la=" "alias l=" "alias ..=" "alias ...=" "alias vi=" "alias fm=")
        
        # Verify each alias is present
        for alias_def in "${required_aliases[@]}"; do
            if ! grep -q "$alias_def" "$filepath"; then
                echo "Failed: .zshrc missing required alias: $alias_def"
                return 1
            fi
        done
    done
}

# Property Test: create_zshrc includes history settings
@test "Property 10.4: create_zshrc includes history configuration (HISTSIZE, SAVEHIST, options)" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/zshrc_history_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Verify HISTSIZE is set
        if ! grep -q 'HISTSIZE=' "$filepath"; then
            echo "Failed: .zshrc missing HISTSIZE setting"
            return 1
        fi
        
        # Verify SAVEHIST is set
        if ! grep -q 'SAVEHIST=' "$filepath"; then
            echo "Failed: .zshrc missing SAVEHIST setting"
            return 1
        fi
        
        # Verify at least one history option is set
        if ! grep -q 'setopt.*HIST' "$filepath"; then
            echo "Failed: .zshrc missing history options"
            return 1
        fi
    done
}

# Property Test: create_zshrc sources zsh plugins
@test "Property 10.5: create_zshrc sources zsh-autosuggestions and zsh-syntax-highlighting" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/zshrc_plugin_source_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Verify zsh-autosuggestions is sourced
        if ! grep -q 'zsh-autosuggestions.zsh' "$filepath"; then
            echo "Failed: .zshrc doesn't source zsh-autosuggestions"
            return 1
        fi
        
        # Verify zsh-syntax-highlighting is sourced
        if ! grep -q 'zsh-syntax-highlighting.zsh' "$filepath"; then
            echo "Failed: .zshrc doesn't source zsh-syntax-highlighting"
            return 1
        fi
    done
}

# Property Test: create_zshrc includes neofetch on startup
@test "Property 10.6: create_zshrc includes neofetch command" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/zshrc_neofetch_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Verify neofetch is called
        if ! grep -q 'neofetch' "$filepath"; then
            echo "Failed: .zshrc doesn't include neofetch"
            return 1
        fi
    done
}

# Property Test: create_tmux_conf creates complete configuration
@test "Property 10.7: create_tmux_conf contains all required tmux settings" {
    # Run 20 iterations
    for i in {1..20}; do
        local filename="tmux_conf_test_${i}"
        local filepath="${TEST_DIR}/${filename}"
        
        # Create .tmux.conf
        create_tmux_conf "$filepath" >/dev/null 2>&1
        local result=$?
        
        # Verify creation succeeded
        if [ $result -ne 0 ]; then
            echo "Failed: create_tmux_conf returned non-zero exit code"
            return 1
        fi
        
        # Verify file exists
        if [ ! -f "$filepath" ]; then
            echo "Failed: .tmux.conf file not created at '$filepath'"
            return 1
        fi
        
        # Verify mouse support is enabled
        if ! grep -q 'set -g mouse on' "$filepath"; then
            echo "Failed: .tmux.conf missing mouse support"
            return 1
        fi
        
        # Verify vi mode is set
        if ! grep -q 'mode-keys vi' "$filepath"; then
            echo "Failed: .tmux.conf missing vi mode"
            return 1
        fi
        
        # Verify status bar is configured
        if ! grep -q 'status-style' "$filepath"; then
            echo "Failed: .tmux.conf missing status bar configuration"
            return 1
        fi
    done
}

# Property Test: create_tmux_conf includes pane navigation
@test "Property 10.8: create_tmux_conf includes pane navigation shortcuts (h, j, k, l)" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/tmux_nav_${i}"
        
        # Create .tmux.conf
        create_tmux_conf "$filepath" >/dev/null 2>&1
        
        # Verify pane navigation bindings
        local nav_keys=("bind h select-pane" "bind j select-pane" "bind k select-pane" "bind l select-pane")
        
        for nav_key in "${nav_keys[@]}"; do
            if ! grep -q "$nav_key" "$filepath"; then
                echo "Failed: .tmux.conf missing navigation binding: $nav_key"
                return 1
            fi
        done
    done
}

# Property Test: create_tmux_conf includes copy mode settings
@test "Property 10.9: create_tmux_conf includes copy mode configuration" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/tmux_copy_${i}"
        
        # Create .tmux.conf
        create_tmux_conf "$filepath" >/dev/null 2>&1
        
        # Verify copy mode binding exists
        if ! grep -q 'copy-mode' "$filepath"; then
            echo "Failed: .tmux.conf missing copy mode configuration"
            return 1
        fi
        
        # Verify copy mode vi bindings
        if ! grep -q 'copy-mode-vi' "$filepath"; then
            echo "Failed: .tmux.conf missing copy mode vi bindings"
            return 1
        fi
    done
}

# Property Test: create_tmux_conf includes terminal colors
@test "Property 10.10: create_tmux_conf includes terminal color configuration" {
    # Run 20 iterations
    for i in {1..20}; do
        local filepath="${TEST_DIR}/tmux_colors_${i}"
        
        # Create .tmux.conf
        create_tmux_conf "$filepath" >/dev/null 2>&1
        
        # Verify default-terminal is set
        if ! grep -q 'default-terminal' "$filepath"; then
            echo "Failed: .tmux.conf missing default-terminal setting"
            return 1
        fi
    done
}

# Property Test: Configuration files are valid and parseable
@test "Property 10.11: create_zshrc creates syntactically valid configuration" {
    # Run 10 iterations
    for i in {1..10}; do
        local filepath="${TEST_DIR}/zshrc_valid_${i}"
        
        # Create .zshrc
        create_zshrc "$filepath" >/dev/null 2>&1
        
        # Verify file is not empty
        if [ ! -s "$filepath" ]; then
            echo "Failed: .zshrc file is empty"
            return 1
        fi
        
        # Verify file has reasonable size (should be at least 500 bytes for complete config)
        local filesize=$(wc -c < "$filepath")
        if [ "$filesize" -lt 500 ]; then
            echo "Failed: .zshrc file is too small ($filesize bytes), likely incomplete"
            return 1
        fi
        
        # Verify no syntax errors in basic shell parsing (check for unmatched quotes)
        # This is a basic check - full validation would require zsh
        local quote_count=$(grep -o "'" "$filepath" | wc -l)
        if [ $((quote_count % 2)) -ne 0 ]; then
            echo "Failed: .zshrc has unmatched single quotes"
            return 1
        fi
    done
}

# Property Test: Configuration files are valid and parseable
@test "Property 10.12: create_tmux_conf creates syntactically valid configuration" {
    # Run 10 iterations
    for i in {1..10}; do
        local filepath="${TEST_DIR}/tmux_valid_${i}"
        
        # Create .tmux.conf
        create_tmux_conf "$filepath" >/dev/null 2>&1
        
        # Verify file is not empty
        if [ ! -s "$filepath" ]; then
            echo "Failed: .tmux.conf file is empty"
            return 1
        fi
        
        # Verify file has reasonable size (should be at least 500 bytes for complete config)
        local filesize=$(wc -c < "$filepath")
        if [ "$filesize" -lt 500 ]; then
            echo "Failed: .tmux.conf file is too small ($filesize bytes), likely incomplete"
            return 1
        fi
    done
}
