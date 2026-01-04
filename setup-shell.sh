#!/bin/bash

################################################################################
# Terminal Setup Script
# 
# Purpose: Automates installation and configuration of a complete development
#          environment including tmux, zsh, ranger, Docker, and various CLI tools
#
# Requirements: 
#   - Debian/Ubuntu-based Linux distribution
#   - Root privileges (run with sudo)
#   - Internet connection
#
# Usage: sudo ./setup-shell.sh
#
# Security Considerations:
#   - Script must be run with root privileges
#   - Properly handles sudo user identification
#   - Sets appropriate file permissions (644 for files, 755 for directories)
#   - Docker group membership has security implications (equivalent to root access)
#
################################################################################

# Exit on error in pipes for safer error handling
set -o pipefail

################################################################################
# Configuration
################################################################################

# SSH Public Key Configuration
# Set this to your GitHub raw public key URL
# Example: https://raw.githubusercontent.com/username/dotfiles/main/id_ed25519.pub
# Or use GitHub's keys endpoint: https://github.com/username.keys
SSH_PUBLIC_KEY_URL="https://raw.githubusercontent.com/pandudpn/setup-vm/main/dotfiles/id_ed25519.pub"

# Set to "true" to enable SSH key setup, "false" to skip
SETUP_SSH_KEY="true"

################################################################################
# Color codes for output
################################################################################

readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[1;31m'
readonly COLOR_RESET='\033[0m'

################################################################################
# Helper Functions
################################################################################

# Print informational message in blue
# Arguments:
#   $1 - Message to print
print_message() {
    local message="$1"
    echo -e "${COLOR_BLUE}>> ${message}${COLOR_RESET}"
}

# Print warning message in yellow
# Arguments:
#   $1 - Warning message to print
print_warning() {
    local message="$1"
    echo -e "${COLOR_YELLOW}>> WARNING: ${message}${COLOR_RESET}"
}

# Print error message in red
# Arguments:
#   $1 - Error message to print
print_error() {
    local message="$1"
    echo -e "${COLOR_RED}>> ERROR: ${message}${COLOR_RESET}" >&2
}

# Check if script is running with root privileges
# Exits with error if not running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

################################################################################
# User Management Functions
################################################################################

# Get the actual user when script is run with sudo
# Returns the SUDO_USER if available, otherwise returns root
# Sets global variables: ACTUAL_USER and USER_HOME
get_actual_user() {
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        ACTUAL_USER="$SUDO_USER"
        # Try to get home directory from passwd database, fallback to /home/$USER
        USER_HOME=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
        if [ -z "$USER_HOME" ]; then
            USER_HOME="/home/$SUDO_USER"
        fi
    else
        ACTUAL_USER="root"
        USER_HOME="/root"
    fi
    
    print_message "Identified actual user: $ACTUAL_USER (home: $USER_HOME)"
}

# Check if a user exists on the system
# Arguments:
#   $1 - Username to check
# Returns:
#   0 if user exists, 1 if user does not exist
check_user_exists() {
    local username="$1"
    
    if id "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Create a new user with home directory
# Arguments:
#   $1 - Username to create
# Returns:
#   0 on success, 1 on failure
create_user() {
    local username="$1"
    
    if check_user_exists "$username"; then
        print_warning "User '$username' already exists, skipping creation"
        return 0
    fi
    
    print_message "Creating user '$username' with home directory..."
    
    if useradd -m -s /bin/bash "$username"; then
        print_message "User '$username' created successfully"
        return 0
    else
        print_error "Failed to create user '$username'"
        return 1
    fi
}

# Set password for a user
# Arguments:
#   $1 - Username
# Returns:
#   0 on success, 1 on failure
set_user_password() {
    local username="$1"
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    print_message "Setting password for user '$username'..."
    
    if passwd "$username"; then
        print_message "Password set successfully for '$username'"
        return 0
    else
        print_error "Failed to set password for '$username'"
        return 1
    fi
}

# Add user to sudo group
# Arguments:
#   $1 - Username to add to sudo group
# Returns:
#   0 on success, 1 on failure
add_to_sudo_group() {
    local username="$1"
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    print_message "Adding user '$username' to sudo group..."
    
    if usermod -aG sudo "$username"; then
        print_message "User '$username' added to sudo group successfully"
        return 0
    else
        print_error "Failed to add user '$username' to sudo group"
        return 1
    fi
}

################################################################################
# Repository and GPG Key Management Functions
################################################################################

# Fix GPG key issues that may prevent package updates
# Attempts multiple methods to resolve GPG key problems
# Returns:
#   0 on success or if no action needed, 1 on failure (non-critical)
fix_gpg_keys() {
    print_message "Checking and fixing GPG keys..."
    
    # Method 1: Update existing keys
    print_message "Attempting to update existing GPG keys..."
    if apt-key update 2>/dev/null; then
        print_message "GPG keys updated successfully"
        return 0
    else
        print_warning "apt-key update failed or is deprecated, trying alternative methods..."
    fi
    
    # Method 2: Fix permissions on apt directories
    print_message "Fixing permissions on apt directories..."
    chmod -R 755 /etc/apt/sources.list.d/ 2>/dev/null || true
    chmod 644 /etc/apt/sources.list 2>/dev/null || true
    
    # Method 3: Remove problematic repository lists and re-add them
    print_message "Cleaning up potentially problematic repository configurations..."
    
    # Clean apt cache
    apt-get clean 2>/dev/null || true
    rm -rf /var/lib/apt/lists/* 2>/dev/null || true
    mkdir -p /var/lib/apt/lists/partial 2>/dev/null || true
    
    print_message "GPG key fix attempts completed"
    return 0
}

# Update package lists with retry logic
# Attempts multiple strategies to successfully update package lists
# Returns:
#   0 on success, 1 on failure (non-critical)
update_package_lists() {
    print_message "Updating package lists..."
    
    local max_attempts=3
    local attempt=1
    
    # Attempt 1: Standard update
    while [ $attempt -le $max_attempts ]; do
        print_message "Update attempt $attempt of $max_attempts..."
        
        if apt-get update 2>&1; then
            print_message "Package lists updated successfully"
            return 0
        else
            print_warning "Package update attempt $attempt failed"
            
            if [ $attempt -eq 1 ]; then
                # After first failure, try fixing GPG keys
                print_message "Attempting to fix GPG keys before retry..."
                fix_gpg_keys
            elif [ $attempt -eq 2 ]; then
                # After second failure, try with --allow-insecure-repositories
                print_warning "Retrying with relaxed security settings..."
                if apt-get update --allow-insecure-repositories 2>&1; then
                    print_warning "Package lists updated with relaxed security (some signatures may be missing)"
                    return 0
                fi
            fi
            
            attempt=$((attempt + 1))
            
            if [ $attempt -le $max_attempts ]; then
                print_message "Waiting 2 seconds before retry..."
                sleep 2
            fi
        fi
    done
    
    # If all attempts failed, log warning but don't exit
    print_warning "Failed to update package lists after $max_attempts attempts"
    print_warning "Continuing with installation, but some packages may fail..."
    return 1
}

################################################################################
# Package Installation Functions
################################################################################

# Install basic development tools
# Installs: git, curl, wget, build-essential, unzip, vim, neovim, nano, tree, jq, software-properties-common
# Returns:
#   0 on success (even if some packages fail), 1 only on critical failure
install_basic_tools() {
    print_message "Installing basic development tools..."
    
    local packages=(
        "git"
        "curl"
        "wget"
        "build-essential"
        "unzip"
        "vim"
        "neovim"
        "nano"
        "tree"
        "jq"
        "software-properties-common"
        "ca-certificates"
        "gnupg"
        "lsb-release"
    )
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

# Install tmux terminal multiplexer
# Returns:
#   0 on success, 1 on failure (non-critical)
install_tmux() {
    print_message "Installing tmux..."
    
    if apt-get install -y tmux 2>&1; then
        print_message "tmux installed successfully"
        return 0
    else
        print_warning "Failed to install tmux, continuing..."
        return 1
    fi
}

################################################################################
# Zsh and Oh My Zsh Installation Functions
################################################################################

# Install zsh shell
# Returns:
#   0 on success, 1 on failure (non-critical)
install_zsh() {
    print_message "Installing zsh..."
    
    if apt-get install -y zsh 2>&1; then
        print_message "zsh installed successfully"
        return 0
    else
        print_warning "Failed to install zsh, continuing..."
        return 1
    fi
}

# Install Oh My Zsh framework for a specific user
# Arguments:
#   $1 - Username for whom to install Oh My Zsh
#   $2 - User's home directory
# Returns:
#   0 on success, 1 on failure (non-critical)
install_oh_my_zsh() {
    local username="$1"
    local user_home="$2"
    local oh_my_zsh_dir="${user_home}/.oh-my-zsh"
    
    print_message "Installing Oh My Zsh for user '$username'..."
    
    # Check if Oh My Zsh is already installed
    if [ -d "$oh_my_zsh_dir" ]; then
        print_warning "Oh My Zsh already installed at $oh_my_zsh_dir"
        return 0
    fi
    
    # Install Oh My Zsh in unattended mode
    # Use su to run as the target user to ensure proper ownership
    if su - "$username" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' 2>&1; then
        print_message "Oh My Zsh installed successfully for '$username'"
        return 0
    else
        print_warning "Failed to install Oh My Zsh for '$username', continuing..."
        return 1
    fi
}

# Update Oh My Zsh if already installed
# Arguments:
#   $1 - Username whose Oh My Zsh to update
#   $2 - User's home directory
# Returns:
#   0 on success, 1 on failure (non-critical)
update_oh_my_zsh() {
    local username="$1"
    local user_home="$2"
    local oh_my_zsh_dir="${user_home}/.oh-my-zsh"
    
    print_message "Checking for Oh My Zsh updates for user '$username'..."
    
    # Check if Oh My Zsh is installed
    if [ ! -d "$oh_my_zsh_dir" ]; then
        print_warning "Oh My Zsh not installed at $oh_my_zsh_dir, skipping update"
        return 1
    fi
    
    # Update Oh My Zsh via git pull
    print_message "Updating Oh My Zsh..."
    if su - "$username" -c "cd ~/.oh-my-zsh && git pull" 2>&1; then
        print_message "Oh My Zsh updated successfully for '$username'"
        return 0
    else
        print_warning "Failed to update Oh My Zsh for '$username', continuing..."
        return 1
    fi
}

# Install zsh plugins (autosuggestions and syntax-highlighting)
# Arguments:
#   $1 - Username for whom to install plugins
#   $2 - User's home directory
# Returns:
#   0 on success, 1 on failure (non-critical)
install_zsh_plugins() {
    local username="$1"
    local user_home="$2"
    local zsh_custom_dir="${user_home}/.oh-my-zsh/custom"
    local zsh_plugins_dir="${user_home}/.zsh"
    
    print_message "Installing zsh plugins for user '$username'..."
    
    # Create .zsh directory for plugins if it doesn't exist
    if [ ! -d "$zsh_plugins_dir" ]; then
        print_message "Creating .zsh directory at $zsh_plugins_dir..."
        if su - "$username" -c "mkdir -p ~/.zsh" 2>&1; then
            print_message ".zsh directory created successfully"
        else
            print_warning "Failed to create .zsh directory, continuing..."
        fi
    fi
    
    # Install zsh-autosuggestions
    local autosuggestions_dir="${zsh_plugins_dir}/zsh-autosuggestions"
    if [ ! -d "$autosuggestions_dir" ]; then
        print_message "Installing zsh-autosuggestions..."
        if su - "$username" -c "git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions" 2>&1; then
            print_message "zsh-autosuggestions installed successfully"
        else
            print_warning "Failed to install zsh-autosuggestions, continuing..."
        fi
    else
        print_message "zsh-autosuggestions already installed, updating..."
        su - "$username" -c "cd ~/.zsh/zsh-autosuggestions && git pull" 2>&1 || print_warning "Failed to update zsh-autosuggestions"
    fi
    
    # Install zsh-syntax-highlighting
    local syntax_highlighting_dir="${zsh_plugins_dir}/zsh-syntax-highlighting"
    if [ ! -d "$syntax_highlighting_dir" ]; then
        print_message "Installing zsh-syntax-highlighting..."
        if su - "$username" -c "git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ~/.zsh/zsh-syntax-highlighting" 2>&1; then
            print_message "zsh-syntax-highlighting installed successfully"
        else
            print_warning "Failed to install zsh-syntax-highlighting, continuing..."
        fi
    else
        print_message "zsh-syntax-highlighting already installed, updating..."
        su - "$username" -c "cd ~/.zsh/zsh-syntax-highlighting && git pull" 2>&1 || print_warning "Failed to update zsh-syntax-highlighting"
    fi
    
    print_message "Zsh plugins installation complete"
    return 0
}

# Set default shell for a user to zsh
# Arguments:
#   $1 - Username
# Returns:
#   0 on success, 1 on failure
set_default_shell() {
    local username="$1"
    
    # Check if user exists first
    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    local shell_path=$(which zsh 2>/dev/null)
    
    if [ -z "$shell_path" ]; then
        print_error "zsh not found in PATH"
        return 1
    fi
    
    print_message "Setting zsh as default shell for '$username'..."
    
    if chsh -s "$shell_path" "$username" 2>&1; then
        print_message "Default shell set to zsh for '$username'"
        return 0
    else
        print_warning "Failed to set default shell for '$username', continuing..."
        return 1
    fi
}

################################################################################
# Ranger Installation Functions
################################################################################

# Install ranger file manager with preview dependencies
# Arguments:
#   $1 - Username for whom to configure ranger
#   $2 - User's home directory
# Returns:
#   0 on success, 1 on failure (non-critical)
install_ranger() {
    local username="$1"
    local user_home="$2"
    
    print_message "Installing ranger file manager and preview dependencies..."
    
    # List of packages to install
    local packages=("ranger" "highlight" "caca-utils" "atool" "w3m" "poppler-utils" "mediainfo")
    local failed_packages=()
    local success_count=0
    
    # Install each package
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
    
    # Report installation results
    print_message "Ranger installation complete: $success_count/${#packages[@]} packages installed"
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
    fi
    
    # Create ranger config directory and generate default configuration
    local ranger_config_dir="${user_home}/.config/ranger"
    
    print_message "Creating ranger configuration directory at $ranger_config_dir..."
    
    if su - "$username" -c "mkdir -p ~/.config/ranger" 2>&1; then
        print_message "Ranger config directory created successfully"
        
        # Generate default ranger configuration
        print_message "Generating default ranger configuration..."
        if su - "$username" -c "ranger --copy-config=all" 2>&1; then
            print_message "Default ranger configuration generated successfully"
        else
            print_warning "Failed to generate default ranger configuration, continuing..."
        fi
    else
        print_warning "Failed to create ranger config directory, continuing..."
    fi
    
    # Return success even if some packages failed (error resilience)
    return 0
}

################################################################################
# Additional Tools Installation Functions
################################################################################

# Install additional useful CLI tools
# Installs: fzf, ripgrep, ncdu, htop, neofetch, bat/batcat
# Returns:
#   0 on success (even if some packages fail), 1 only on critical failure
install_additional_tools() {
    print_message "Installing additional CLI tools..."
    
    local packages=("fzf" "ripgrep" "ncdu" "htop" "neofetch" "bat")
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
    print_message "Additional tools installation complete: $success_count/${#packages[@]} packages installed"
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
        print_message "Some tools may not be available in your distribution's repositories"
    fi
    
    # Return success even if some packages failed (error resilience)
    return 0
}

################################################################################
# Go Installation Functions
################################################################################

# Install Go programming language
# Returns:
#   0 on success, 1 on failure (non-critical)
install_golang() {
    print_message "Installing Go programming language..."

    # Check if Go is already installed
    if command -v go &>/dev/null; then
        print_message "Go is already installed, checking version..."
        go version
        return 0
    fi

    local go_version="1.25.5"
    local go_os="linux"
    local go_arch=$(uname -m)
    local go_arch_formatted

    # Convert architecture to Go format
    case "$go_arch" in
        "x86_64") go_arch_formatted="amd64" ;;
        "aarch64"|"arm64") go_arch_formatted="arm64" ;;
        "armv7l") go_arch_formatted="armv6l" ;;
        *) go_arch_formatted="amd64" ;;
    esac

    local go_url="https://go.dev/dl/go${go_version}.${go_os}-${go_arch_formatted}.tar.gz"
    local go_temp_dir="/tmp/go-install"
    local go_tarball="${go_temp_dir}/go.tar.gz"

    # Create temp directory
    mkdir -p "$go_temp_dir"

    # Download Go tarball
    print_message "Downloading Go ${go_version} for ${go_os}-${go_arch_formatted}..."
    if curl -fsSL "$go_url" -o "$go_tarball" 2>&1; then
        print_message "Go tarball downloaded successfully"
    else
        print_error "Failed to download Go tarball from $go_url"
        rm -rf "$go_temp_dir"
        return 1
    fi

    # Extract Go to /usr/local
    print_message "Extracting Go to /usr/local..."
    if tar -C /usr/local -xzf "$go_tarball" 2>&1; then
        print_message "Go extracted successfully"
    else
        print_error "Failed to extract Go tarball"
        rm -rf "$go_temp_dir"
        return 1
    fi

    # Clean up temp directory
    rm -rf "$go_temp_dir"

    # Create environment file for all users
    print_message "Creating Go environment file..."
    cat > /etc/profile.d/go.sh << 'GO_ENV_EOF'
# Go environment variables
export GOROOT=/usr/local/go
export GOPATH=\$HOME/go
export PATH=\$PATH:/usr/local/go/bin:\$GOPATH/bin
GO_ENV_EOF

    # Set permissions
    chmod 644 /etc/profile.d/go.sh

    # Load environment immediately for current session
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

    # Verify installation
    if /usr/local/go/bin/go version &>/dev/null; then
        print_message "Go installed successfully!"
        /usr/local/go/bin/go version
        return 0
    else
        print_error "Go installation failed"
        return 1
    fi
}

# Setup Go workspace directories for a user
# Arguments:
#   $1 - Username for whom to setup Go workspace
#   $2 - User's home directory
# Returns:
#   0 on success, 1 on failure (non-critical)
setup_go_workspace() {
    local username="$1"
    local user_home="$2"
    local go_path="${user_home}/go"

    print_message "Setting up Go workspace for user '$username'..."

    # Create Go workspace directories
    local go_dirs=("bin" "pkg" "src")
    local success_count=0

    for dir in "${go_dirs[@]}"; do
        local dir_path="${go_path}/${dir}"
        print_message "Creating directory: $dir_path"

        if su - "$username" -c "mkdir -p ~/go/${dir}" 2>&1; then
            print_message "Directory $dir created successfully"
            success_count=$((success_count + 1))
        else
            print_warning "Failed to create directory $dir, continuing..."
        fi
    done

    print_message "Go workspace setup complete: $success_count/${#go_dirs[@]} directories created"
    return 0
}

################################################################################
# Sops Installation Functions
################################################################################

# Install Sops (Secrets OPerationS)
# Returns:
#   0 on success, 1 on failure (non-critical)
install_sops() {
    print_message "Installing Sops (Secrets OPerationS)..."

    # Check if Sops is already installed
    if command -v sops &>/dev/null; then
        print_message "Sops is already installed, checking version..."
        sops --version
        return 0
    fi

    local sops_version="v3.9.0"
    local sops_os="linux"
    local sops_arch=$(uname -m)
    local sops_arch_formatted

    # Convert architecture to Sops format
    case "$sops_arch" in
        "x86_64") sops_arch_formatted="amd64" ;;
        "aarch64"|"arm64") sops_arch_formatted="arm64" ;;
        *) sops_arch_formatted="amd64" ;;
    esac

    local sops_url="https://github.com/mozilla/sops/releases/download/${sops_version}/sops-${sops_version}.${sops_os}.${sops_arch_formatted}"
    local sops_dest="/usr/local/bin/sops"

    # Download Sops binary
    print_message "Downloading Sops ${sops_version} for ${sops_os}-${sops_arch_formatted}..."
    if curl -fsSL "$sops_url" -o "$sops_dest" 2>&1; then
        print_message "Sops binary downloaded successfully"
    else
        print_error "Failed to download Sops binary from $sops_url"
        return 1
    fi

    # Set executable permissions
    print_message "Setting executable permissions for Sops..."
    if chmod 755 "$sops_dest" 2>&1; then
        print_message "Permissions set successfully"
    else
        print_error "Failed to set executable permissions for Sops"
        return 1
    fi

    # Verify installation
    if command -v sops &>/dev/null; then
        print_message "Sops installed successfully!"
        sops --version
        return 0
    else
        print_error "Sops installation failed"
        return 1
    fi
}

################################################################################
# Docker Installation Functions
################################################################################

# Install Docker from official repository
# Returns:
#   0 on success, 1 on failure (non-critical)
install_docker() {
    print_message "Installing Docker from official repository..."
    
    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        print_message "Docker is already installed, checking version..."
        docker --version
        return 0
    fi
    
    # Install prerequisites
    print_message "Installing Docker prerequisites..."
    if ! apt-get install -y ca-certificates curl gnupg lsb-release 2>&1; then
        print_warning "Failed to install Docker prerequisites, continuing..."
    fi
    
    # Create directory for Docker GPG key
    print_message "Setting up Docker GPG key..."
    mkdir -p /etc/apt/keyrings
    
    # Add Docker's official GPG key
    if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>&1; then
        print_message "Docker GPG key added successfully"
        chmod a+r /etc/apt/keyrings/docker.gpg
    else
        print_warning "Failed to add Docker GPG key, trying alternative method..."
        # Try Debian repository if Ubuntu fails
        if curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>&1; then
            print_message "Docker GPG key added successfully (Debian repository)"
            chmod a+r /etc/apt/keyrings/docker.gpg
        else
            print_error "Failed to add Docker GPG key"
            return 1
        fi
    fi
    
    # Add Docker repository to apt sources
    print_message "Adding Docker repository to apt sources..."
    
    # Detect distribution
    local distro=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
    local codename=$(lsb_release -cs)
    
    # Try Ubuntu repository first, fallback to Debian
    if [ "$distro" = "ubuntu" ] || [ "$distro" = "debian" ]; then
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$distro \
          $codename stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        print_message "Docker repository added successfully"
    else
        print_warning "Unsupported distribution: $distro, trying Debian repository..."
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
          $codename stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Update package lists
    print_message "Updating package lists with Docker repository..."
    if ! apt-get update 2>&1; then
        print_warning "Failed to update package lists, continuing..."
    fi
    
    # Install Docker packages
    print_message "Installing Docker packages (docker-ce, docker-ce-cli, containerd.io)..."
    
    local docker_packages=("docker-ce" "docker-ce-cli" "containerd.io")
    local failed_packages=()
    local success_count=0
    
    for package in "${docker_packages[@]}"; do
        print_message "Installing $package..."
        
        if apt-get install -y "$package" 2>&1; then
            print_message "$package installed successfully"
            success_count=$((success_count + 1))
        else
            print_warning "Failed to install $package, continuing..."
            failed_packages+=("$package")
        fi
    done
    
    # Report results
    print_message "Docker installation complete: $success_count/${#docker_packages[@]} packages installed"
    
    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
        return 1
    fi
    
    # Verify Docker installation
    if command -v docker &>/dev/null; then
        print_message "Docker installed successfully!"
        docker --version
        return 0
    else
        print_error "Docker installation failed"
        return 1
    fi
}

# Install Docker Compose
# Returns:
#   0 on success, 1 on failure (non-critical)
install_docker_compose() {
    print_message "Installing Docker Compose..."
    
    # Check if docker-compose is already installed
    if command -v docker-compose &>/dev/null; then
        print_message "Docker Compose is already installed, checking version..."
        docker-compose --version
        return 0
    fi
    
    # Try to install docker-compose-plugin first (recommended method)
    print_message "Installing docker-compose-plugin..."
    if apt-get install -y docker-compose-plugin 2>&1; then
        print_message "docker-compose-plugin installed successfully"
        
        # Verify installation
        if docker compose version &>/dev/null; then
            print_message "Docker Compose (plugin) installed successfully!"
            docker compose version
            return 0
        fi
    else
        print_warning "Failed to install docker-compose-plugin, trying standalone docker-compose..."
    fi
    
    # Fallback: Try to install standalone docker-compose package
    print_message "Installing standalone docker-compose package..."
    if apt-get install -y docker-compose 2>&1; then
        print_message "docker-compose installed successfully"
        
        # Verify installation
        if command -v docker-compose &>/dev/null; then
            print_message "Docker Compose installed successfully!"
            docker-compose --version
            return 0
        fi
    else
        print_warning "Failed to install docker-compose package"
    fi
    
    # If both methods failed, try downloading binary directly
    print_message "Attempting to download Docker Compose binary directly..."
    
    local compose_version="v2.24.0"
    local compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)"
    local compose_dest="/usr/local/bin/docker-compose"
    
    if curl -L "$compose_url" -o "$compose_dest" 2>&1; then
        chmod +x "$compose_dest"
        
        if command -v docker-compose &>/dev/null; then
            print_message "Docker Compose binary installed successfully!"
            docker-compose --version
            return 0
        fi
    fi
    
    print_warning "Failed to install Docker Compose"
    return 1
}

# Configure Docker access for a user (add to docker group)
# Arguments:
#   $1 - Username to add to docker group
# Returns:
#   0 on success, 1 on failure
configure_docker_access() {
    local username="$1"
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    # Check if docker group exists
    if ! getent group docker &>/dev/null; then
        print_message "Docker group does not exist, creating it..."
        if ! groupadd docker 2>&1; then
            print_error "Failed to create docker group"
            return 1
        fi
    fi
    
    print_message "Adding user '$username' to docker group..."
    
    if usermod -aG docker "$username" 2>&1; then
        print_message "User '$username' added to docker group successfully"
        print_message "Note: User may need to log out and back in for group changes to take effect"
        return 0
    else
        print_error "Failed to add user '$username' to docker group"
        return 1
    fi
}

# Enable and start Docker service
# Returns:
#   0 on success, 1 on failure (non-critical)
enable_docker_service() {
    print_message "Enabling and starting Docker service..."
    
    # Check if systemctl is available
    if ! command -v systemctl &>/dev/null; then
        print_warning "systemctl not available, skipping Docker service configuration"
        return 1
    fi
    
    # Enable Docker service to start on boot
    print_message "Enabling Docker service..."
    if systemctl enable docker 2>&1; then
        print_message "Docker service enabled successfully"
    else
        print_warning "Failed to enable Docker service, continuing..."
    fi
    
    # Start Docker service
    print_message "Starting Docker service..."
    if systemctl start docker 2>&1; then
        print_message "Docker service started successfully"
    else
        print_warning "Failed to start Docker service, it may already be running"
    fi
    
    # Check Docker service status
    print_message "Checking Docker service status..."
    if systemctl is-active --quiet docker; then
        print_message "Docker service is running"
        return 0
    else
        print_warning "Docker service is not running"
        return 1
    fi
}

################################################################################
# Configuration File Management Functions
################################################################################

# Backup existing configuration file with timestamp
# Arguments:
#   $1 - File path to backup
# Returns:
#   0 on success or if file doesn't exist, 1 on failure
backup_existing_config() {
    local filepath="$1"
    
    # Check if file exists
    if [ ! -f "$filepath" ]; then
        print_message "No existing file at $filepath, no backup needed"
        return 0
    fi
    
    # Create timestamped backup
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup_path="${filepath}.backup.${timestamp}"
    
    print_message "Backing up existing file $filepath to $backup_path..."
    
    if cp "$filepath" "$backup_path" 2>&1; then
        print_message "Backup created successfully at $backup_path"
        return 0
    else
        print_error "Failed to create backup of $filepath"
        return 1
    fi
}

# Create .zshrc configuration file with complete settings
# Arguments:
#   $1 - Destination path for .zshrc file
# Returns:
#   0 on success, 1 on failure
create_zshrc() {
    local destination="$1"
    
    print_message "Creating .zshrc configuration at $destination..."
    
    # Backup existing file if present
    backup_existing_config "$destination"
    
    # Create .zshrc with complete configuration
    cat > "$destination" << 'ZSHRC_EOF'
# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme - Options: robbyrussell, agnoster, powerlevel10k/powerlevel10k, 
# af-magic, bira, cloud, dallas, dst, fino, jonathan, ys
ZSH_THEME="agnoster"

# Uncomment for random theme on each startup
# ZSH_THEME="random"
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" "af-magic" "bira" )

# Plugins
plugins=(
    git
    docker
    sudo
    history
    colored-man-pages
    command-not-found
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Custom aliases
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias vi='vim'
alias vim='vim'
alias nvim='nvim'
alias v='nvim'
alias fm='ranger'
alias c='clear'
alias h='history'
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'
alias tree='tree -C'

# Docker aliases
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
alias dstop='docker stop'
alias drm='docker rm'
alias drmi='docker rmi'

# Git aliases (additional to oh-my-zsh git plugin)
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gco='git checkout'
alias gb='git branch'
alias glog='git log --oneline --graph --decorate'

# System aliases
alias update='sudo apt update && sudo apt upgrade -y'
alias install='sudo apt install'
alias remove='sudo apt remove'
alias search='apt search'
alias ports='netstat -tulanp'
alias meminfo='free -m -l -t'
alias cpuinfo='lscpu'
alias diskinfo='df -h'

# Sops aliases
if command -v sops &> /dev/null; then
    alias sops-edit='sops edit'
    alias sops-view='sops -d'
    alias sops-encrypt='sops --encrypt'
fi

# Bat/batcat alias handling
if command -v batcat &> /dev/null; then
    alias bat='batcat'
    alias cat='batcat --paging=never'
elif command -v bat &> /dev/null; then
    alias cat='bat --paging=never'
fi

# History settings
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY

# Key bindings
bindkey '^[[A' history-beginning-search-backward
bindkey '^[[B' history-beginning-search-forward
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char

# Tab completion settings
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

# Source zsh plugins
if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
    # Customize autosuggestions color
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
fi

if [ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Custom prompt context (hide user@hostname if default user)
DEFAULT_USER="deploy"
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)$USER"
  fi
}

# Environment variables
# Use neovim if available, otherwise vim
if command -v nvim &> /dev/null; then
    export EDITOR='nvim'
    export VISUAL='nvim'
else
    export EDITOR='vim'
    export VISUAL='vim'
fi
export PAGER='less'

# Go environment variables
if [ -d /usr/local/go ]; then
    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOROOT/bin:$GOPATH/bin
fi

# Colored man pages
export LESS_TERMCAP_mb=$'\e[1;32m'
export LESS_TERMCAP_md=$'\e[1;32m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_so=$'\e[01;33m'
export LESS_TERMCAP_ue=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;4;31m'

# Run neofetch on startup (only for interactive shells)
if command -v neofetch &> /dev/null && [[ $- == *i* ]]; then
    neofetch
fi

# Welcome message
echo ""
echo "🚀 Welcome to your development environment!"
echo "💡 Type 'help-aliases' to see available custom aliases"
echo ""

# Function to show custom aliases
help-aliases() {
    echo "📝 Custom Aliases:"
    echo ""
    echo "Navigation:"
    echo "  ll, la, l     - List files with different options"
    echo "  .., ..., .... - Navigate up directories"
    echo "  c             - Clear screen"
    echo ""
    echo "Docker:"
    echo "  dps, dpsa     - Docker ps / ps -a"
    echo "  di            - Docker images"
    echo "  dex           - Docker exec -it"
    echo "  dlog          - Docker logs -f"
    echo ""
    echo "Git:"
    echo "  gs, ga, gc    - Git status/add/commit"
    echo "  gp, gl        - Git push/pull"
    echo "  glog          - Git log (pretty)"
    echo ""
    echo "System:"
    echo "  update        - Update system packages"
    echo "  install       - Install package"
    echo "  meminfo       - Memory information"
    echo "  diskinfo      - Disk usage"
    echo ""
    echo "Tools:"
    echo "  fm            - Ranger file manager"
    echo "  cat           - Bat (syntax highlighting)"
    echo ""
}
ZSHRC_EOF
    
    if [ $? -eq 0 ]; then
        print_message ".zshrc created successfully at $destination"
        return 0
    else
        print_error "Failed to create .zshrc at $destination"
        return 1
    fi
}

# Create .tmux.conf configuration file with complete settings
# Arguments:
#   $1 - Destination path for .tmux.conf file
# Returns:
#   0 on success, 1 on failure
create_tmux_conf() {
    local destination="$1"
    
    print_message "Creating .tmux.conf configuration at $destination..."
    
    # Backup existing file if present
    backup_existing_config "$destination"
    
    # Create .tmux.conf with complete configuration
    cat > "$destination" << 'TMUX_EOF'
# Enable mouse support
set -g mouse on

# Set vi mode for copy mode
setw -g mode-keys vi

# Start window numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# Renumber windows when one is closed
set -g renumber-windows on

# Increase scrollback buffer size
set -g history-limit 10000

# Set terminal colors
set -g default-terminal "screen-256color"

# Status bar customization
set -g status-style bg=black,fg=white
set -g status-left-length 40
set -g status-left "#[fg=green]Session: #S #[fg=yellow]#I #[fg=cyan]#P"
set -g status-right "#[fg=cyan]%d %b %R"
set -g status-interval 60
set -g status-justify centre

# Window status customization
setw -g window-status-style fg=cyan,bg=black
setw -g window-status-current-style fg=white,bold,bg=red

# Pane border customization
set -g pane-border-style fg=green
set -g pane-active-border-style fg=white,bold

# Message customization
set -g message-style fg=white,bold,bg=black

# Pane navigation shortcuts
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R

# Pane resizing shortcuts
bind -r H resize-pane -L 5
bind -r J resize-pane -D 5
bind -r K resize-pane -U 5
bind -r L resize-pane -R 5

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config file
bind r source-file ~/.tmux.conf \; display "Config reloaded!"

# Copy mode settings
bind Escape copy-mode
bind -T copy-mode-vi v send -X begin-selection
bind -T copy-mode-vi y send -X copy-selection-and-cancel

# Enable activity alerts
setw -g monitor-activity on
set -g visual-activity on

# Reduce escape time for better vim experience
set -sg escape-time 0

# Display pane numbers for longer
set -g display-panes-time 2000
TMUX_EOF
    
    if [ $? -eq 0 ]; then
        print_message ".tmux.conf created successfully at $destination"
        return 0
    else
        print_error "Failed to create .tmux.conf at $destination"
        return 1
    fi
}

################################################################################
# Neofetch Configuration Function
################################################################################

# Create custom neofetch configuration
# Arguments:
#   $1 - Username
#   $2 - User's home directory
# Returns:
#   0 on success, 1 on failure (non-critical)
create_neofetch_config() {
    local username="$1"
    local user_home="$2"
    local config_dir="${user_home}/.config/neofetch"
    local config_file="${config_dir}/config.conf"
    
    print_message "Creating custom neofetch configuration for '$username'..."
    
    # Create config directory
    if [ ! -d "$config_dir" ]; then
        if su - "$username" -c "mkdir -p ~/.config/neofetch" 2>&1; then
            print_message "Neofetch config directory created"
        else
            print_warning "Failed to create neofetch config directory"
            return 1
        fi
    fi
    
    # Create custom neofetch config
    cat > "$config_file" << 'NEOFETCH_EOF'
# Neofetch Custom Configuration

# Print info
print_info() {
    info title
    info underline

    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Resolution" resolution
    info "DE" de
    info "WM" wm
    info "WM Theme" wm_theme
    info "Theme" theme
    info "Icons" icons
    info "Terminal" term
    info "Terminal Font" term_font
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory

    # info "GPU Driver" gpu_driver  # Linux/macOS only
    # info "CPU Usage" cpu_usage
    # info "Disk" disk
    # info "Battery" battery
    # info "Font" font
    # info "Song" song
    # [[ "$player" ]] && prin "Music Player" "$player"
    # info "Local IP" local_ip
    # info "Public IP" public_ip
    # info "Users" users
    # info "Locale" locale  # This only works on glibc systems.

    info cols
}

# Title
title_fqdn="off"

# Kernel
kernel_shorthand="on"

# Distro
distro_shorthand="off"
os_arch="on"

# Uptime
uptime_shorthand="on"

# Memory
memory_percent="on"
memory_unit="mib"

# Packages
package_managers="on"

# Shell
shell_path="off"
shell_version="on"

# CPU
speed_type="bios_limit"
speed_shorthand="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"

# GPU
gpu_brand="on"
gpu_type="all"

# Resolution
refresh_rate="off"

# Gtk Theme / Icons / Font
gtk_shorthand="off"
gtk2="on"
gtk3="on"

# IP Address
public_ip_host="http://ident.me"
public_ip_timeout=2

# Desktop Environment
de_version="on"

# Disk
disk_show=('/')
disk_subtitle="mount"
disk_percent="on"

# Song
music_player="auto"
song_format="%artist% - %album% - %title%"
song_shorthand="off"
mpc_args=()

# Text Colors
colors=(distro)

# Text Options
bold="on"
underline_enabled="on"
underline_char="-"
separator=":"

# Color Blocks
block_range=(0 15)
color_blocks="on"
block_width=3
block_height=1
col_offset="auto"

# Progress Bars
bar_char_elapsed="-"
bar_char_total="="
bar_border="on"
bar_length=15
bar_color_elapsed="distro"
bar_color_total="distro"

# Info display
cpu_display="off"
memory_display="off"
battery_display="off"
disk_display="off"

# Backend Settings
image_backend="ascii"
image_source="auto"

# Ascii Options
ascii_distro="auto"
ascii_colors=(distro)
ascii_bold="on"

# Image Options
image_loop="off"
thumbnail_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails/neofetch"
crop_mode="normal"
crop_offset="center"
image_size="auto"
gap=3
yoffset=0
xoffset=0
background_color=

# Misc Options
stdout="off"
NEOFETCH_EOF
    
    # Set ownership
    if chown "${username}:${username}" "$config_file" 2>&1; then
        chmod 644 "$config_file" 2>&1 || true
        print_message "Neofetch configuration created successfully"
        return 0
    else
        print_warning "Failed to set ownership for neofetch config"
        return 1
    fi
}

################################################################################
# Ownership and Permissions Management Functions
################################################################################

# Fix ownership and permissions for configuration files and directories
# Arguments:
#   $1 - Username for whom to fix ownership
# Returns:
#   0 on success, 1 on failure (non-critical)
fix_ownership() {
    local username="$1"
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    # Get user's home directory
    local user_home=$(getent passwd "$username" 2>/dev/null | cut -d: -f6)
    if [ -z "$user_home" ]; then
        user_home="/home/$username"
    fi
    
    print_message "Fixing ownership and permissions for user '$username'..."
    
    # List of directories to fix ownership (recursively)
    local directories=(
        "${user_home}/.oh-my-zsh"
        "${user_home}/.zsh"
        "${user_home}/.config/ranger"
    )
    
    # List of files to fix ownership
    local files=(
        "${user_home}/.zshrc"
        "${user_home}/.tmux.conf"
    )
    
    # Fix ownership for directories (recursively)
    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            print_message "Setting ownership for directory: $dir"
            
            # Set ownership recursively
            if chown -R "${username}:${username}" "$dir" 2>&1; then
                print_message "Ownership set successfully for $dir"
            else
                print_warning "Failed to set ownership for $dir, continuing..."
            fi
            
            # Set directory permissions to 755
            if find "$dir" -type d -exec chmod 755 {} \; 2>&1; then
                print_message "Directory permissions set to 755 for $dir"
            else
                print_warning "Failed to set directory permissions for $dir, continuing..."
            fi
            
            # Set file permissions to 644 within the directory
            if find "$dir" -type f -exec chmod 644 {} \; 2>&1; then
                print_message "File permissions set to 644 within $dir"
            else
                print_warning "Failed to set file permissions within $dir, continuing..."
            fi
        else
            print_message "Directory $dir does not exist, skipping..."
        fi
    done
    
    # Fix ownership for individual files
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_message "Setting ownership for file: $file"
            
            # Set ownership
            if chown "${username}:${username}" "$file" 2>&1; then
                print_message "Ownership set successfully for $file"
            else
                print_warning "Failed to set ownership for $file, continuing..."
            fi
            
            # Set file permissions to 644
            if chmod 644 "$file" 2>&1; then
                print_message "File permissions set to 644 for $file"
            else
                print_warning "Failed to set file permissions for $file, continuing..."
            fi
        else
            print_message "File $file does not exist, skipping..."
        fi
    done
    
    print_message "Ownership and permissions fixed successfully for '$username'"
    return 0
}

################################################################################
# SSH Key Setup Functions
################################################################################

# Setup SSH keys for a user by downloading from a URL
# Arguments:
#   $1 - Username
#   $2 - SSH public key URL
# Returns:
#   0 on success, 1 on failure (non-critical)
setup_ssh_keys() {
    local username="$1"
    local key_url="$2"
    
    if [ -z "$key_url" ]; then
        print_warning "No SSH key URL provided, skipping SSH key setup"
        return 1
    fi
    
    # Check if URL is still the default placeholder
    if [[ "$key_url" == *"YOUR_GITHUB_USERNAME"* ]]; then
        print_warning "SSH key URL is still set to default placeholder"
        print_warning "Please update SSH_PUBLIC_KEY_URL in the script with your GitHub username"
        print_warning "Skipping SSH key setup"
        return 1
    fi
    
    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi
    
    # Get user's home directory
    local user_home=$(getent passwd "$username" 2>/dev/null | cut -d: -f6)
    if [ -z "$user_home" ]; then
        user_home="/home/$username"
    fi
    
    local ssh_dir="${user_home}/.ssh"
    local authorized_keys="${ssh_dir}/authorized_keys"
    
    print_message "Setting up SSH keys for user '$username'..."
    
    # Create .ssh directory if it doesn't exist
    if [ ! -d "$ssh_dir" ]; then
        print_message "Creating .ssh directory at $ssh_dir..."
        
        if su - "$username" -c "mkdir -p ~/.ssh" 2>&1; then
            print_message ".ssh directory created successfully"
        else
            print_error "Failed to create .ssh directory"
            return 1
        fi
    fi
    
    # Download public key from URL
    print_message "Downloading SSH public key from: $key_url"
    
    local temp_key_file=$(mktemp)
    
    if curl -fsSL "$key_url" -o "$temp_key_file" 2>&1; then
        print_message "SSH public key downloaded successfully"
    elif wget -q "$key_url" -O "$temp_key_file" 2>&1; then
        print_message "SSH public key downloaded successfully (using wget)"
    else
        print_error "Failed to download SSH public key from $key_url"
        rm -f "$temp_key_file"
        return 1
    fi
    
    # Verify the downloaded file is not empty
    if [ ! -s "$temp_key_file" ]; then
        print_error "Downloaded SSH key file is empty"
        rm -f "$temp_key_file"
        return 1
    fi
    
    # Verify the file contains valid SSH key format
    if ! grep -qE "^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ssh-dss)" "$temp_key_file"; then
        print_error "Downloaded file does not appear to contain valid SSH public keys"
        print_warning "File content:"
        head -5 "$temp_key_file"
        rm -f "$temp_key_file"
        return 1
    fi
    
    # Backup existing authorized_keys if present
    if [ -f "$authorized_keys" ]; then
        local timestamp=$(date +%Y%m%d%H%M%S)
        local backup_file="${authorized_keys}.backup.${timestamp}"
        
        print_message "Backing up existing authorized_keys to $backup_file"
        
        if cp "$authorized_keys" "$backup_file" 2>&1; then
            chown "${username}:${username}" "$backup_file" 2>/dev/null || true
            print_message "Backup created successfully"
        else
            print_warning "Failed to create backup of authorized_keys"
        fi
    fi
    
    # Copy the downloaded key to authorized_keys
    print_message "Installing SSH public key to $authorized_keys..."
    
    if cp "$temp_key_file" "$authorized_keys" 2>&1; then
        print_message "SSH public key installed successfully"
    else
        print_error "Failed to install SSH public key"
        rm -f "$temp_key_file"
        return 1
    fi
    
    # Clean up temp file
    rm -f "$temp_key_file"
    
    # Set correct ownership and permissions
    print_message "Setting correct ownership and permissions for SSH files..."
    
    # Set ownership for .ssh directory and contents
    if chown -R "${username}:${username}" "$ssh_dir" 2>&1; then
        print_message "Ownership set successfully"
    else
        print_warning "Failed to set ownership for .ssh directory"
    fi
    
    # Set correct permissions
    # .ssh directory: 700 (rwx------)
    if chmod 700 "$ssh_dir" 2>&1; then
        print_message "Permissions set to 700 for .ssh directory"
    else
        print_warning "Failed to set permissions for .ssh directory"
    fi
    
    # authorized_keys file: 600 (rw-------)
    if chmod 600 "$authorized_keys" 2>&1; then
        print_message "Permissions set to 600 for authorized_keys"
    else
        print_warning "Failed to set permissions for authorized_keys"
    fi
    
    # Display the installed keys
    print_message "Installed SSH public keys:"
    local key_count=$(grep -c "^ssh-" "$authorized_keys" 2>/dev/null || echo "0")
    print_message "  - Number of keys: $key_count"
    
    if [ "$key_count" -gt 0 ]; then
        print_message "  - Key fingerprints:"
        while IFS= read -r key; do
            if [[ "$key" =~ ^ssh- ]]; then
                local fingerprint=$(echo "$key" | ssh-keygen -lf - 2>/dev/null | awk '{print $2}')
                if [ -n "$fingerprint" ]; then
                    print_message "    $fingerprint"
                fi
            fi
        done < "$authorized_keys"
    fi
    
    print_message "SSH key setup completed successfully for '$username'"
    return 0
}

################################################################################
# Main Script
################################################################################

# Verify root privileges
check_root

print_message "Terminal setup script started"

# Get actual user information
get_actual_user

# Prompt for username (default: deploy)
print_message "Enter username for development environment (default: deploy):"
read -r USERNAME
USERNAME=${USERNAME:-deploy}

print_message "Setting up environment for user: $USERNAME"

# Create or verify user
if ! check_user_exists "$USERNAME"; then
    print_message "User '$USERNAME' does not exist, creating..."
    
    if ! create_user "$USERNAME"; then
        print_error "Failed to create user '$USERNAME'"
        exit 1
    fi
    
    # Set user password to disabled (no password required for sudo from root)
    print_message "Setting up passwordless user (you can set password later with: sudo passwd $USERNAME)..."
    if passwd -d "$USERNAME" 2>&1; then
        print_message "User '$USERNAME' created without password"
    else
        print_warning "Failed to disable password for '$USERNAME', continuing..."
    fi
    
    # Add user to sudo group
    if ! add_to_sudo_group "$USERNAME"; then
        print_warning "Failed to add '$USERNAME' to sudo group, continuing..."
    fi
else
    print_message "User '$USERNAME' already exists, using existing user"
fi

# Get user's home directory
USER_HOME=$(getent passwd "$USERNAME" 2>/dev/null | cut -d: -f6)
if [ -z "$USER_HOME" ]; then
    USER_HOME="/home/$USERNAME"
fi

print_message "User home directory: $USER_HOME"

# Fix GPG keys and update repositories
fix_gpg_keys
update_package_lists

# Install all packages and tools
print_message "Starting package installation phase..."

install_basic_tools
install_tmux
install_zsh

# Install Oh My Zsh for the user
if [ -d "${USER_HOME}/.oh-my-zsh" ]; then
    update_oh_my_zsh "$USERNAME" "$USER_HOME"
else
    install_oh_my_zsh "$USERNAME" "$USER_HOME"
fi

# Install zsh plugins
install_zsh_plugins "$USERNAME" "$USER_HOME"

# Install ranger
install_ranger "$USERNAME" "$USER_HOME"

# Install additional tools
install_additional_tools

# Install Go and Sops
print_message "Starting Go and Sops installation phase..."
install_golang

# Setup Go workspace for user
setup_go_workspace "$USERNAME" "$USER_HOME"

# Install Sops
install_sops

# Install Docker and Docker Compose
print_message "Starting Docker installation phase..."
install_docker
install_docker_compose

# Configure Docker access for user
configure_docker_access "$USERNAME"

# Enable and start Docker service
enable_docker_service

# Create configuration files
print_message "Creating configuration files..."

# Create .zshrc
ZSHRC_PATH="${USER_HOME}/.zshrc"
create_zshrc "$ZSHRC_PATH"

# Create .tmux.conf
TMUX_CONF_PATH="${USER_HOME}/.tmux.conf"
create_tmux_conf "$TMUX_CONF_PATH"

# Create neofetch config
create_neofetch_config "$USERNAME" "$USER_HOME"

# Fix ownership and permissions
print_message "Fixing ownership and permissions..."
fix_ownership "$USERNAME"

# Setup SSH keys (if enabled)
if [ "$SETUP_SSH_KEY" = "true" ]; then
    print_message "Setting up SSH keys..."
    if setup_ssh_keys "$USERNAME" "$SSH_PUBLIC_KEY_URL"; then
        print_message "SSH keys configured successfully"
    else
        print_warning "SSH key setup failed or was skipped"
    fi
else
    print_message "SSH key setup is disabled (SETUP_SSH_KEY=false)"
fi

# Set default shell
print_message "Setting default shell to zsh..."
set_default_shell "$USERNAME"

# Display completion message
print_message "=========================================="
print_message "Terminal setup completed successfully!"
print_message "=========================================="
print_message ""
print_message "Setup Summary:"
print_message "  - User: $USERNAME (no password set)"
print_message "  - Home: $USER_HOME"
print_message "  - Shell: zsh with Oh My Zsh"
print_message "  - Terminal Multiplexer: tmux"
print_message "  - File Manager: ranger"
print_message "  - Docker: Installed with non-root access"
print_message "  - Go: Installed with workspace directories"
print_message "  - Sops: Installed for secrets management"

# Check if SSH keys were setup
if [ "$SETUP_SSH_KEY" = "true" ] && [ -f "${USER_HOME}/.ssh/authorized_keys" ]; then
    local ssh_key_count=$(grep -c "^ssh-" "${USER_HOME}/.ssh/authorized_keys" 2>/dev/null || echo "0")
    print_message "  - SSH Keys: $ssh_key_count key(s) installed"
fi
print_message ""
print_message "Next Steps:"
print_message "  1. (Optional) Set password for user: sudo passwd $USERNAME"
print_message "  2. Log out and log back in for group changes to take effect"
print_message "  3. Switch to user '$USERNAME': su - $USERNAME"
print_message "  4. Start using your configured environment!"
print_message ""
print_message "Configuration files created:"
print_message "  - $ZSHRC_PATH"
print_message "  - $TMUX_CONF_PATH"
print_message "  - ${USER_HOME}/.config/ranger/"
print_message ""
print_message "Enjoy your new development environment!"
print_message "=========================================="
