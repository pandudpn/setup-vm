#!/bin/bash

################################################################################
# Terminal Setup Script (Interactive)
#
# Purpose: Automates installation and configuration of a complete development
#          environment with an interactive component selection menu.
#
# Requirements:
#   - Debian/Ubuntu-based Linux distribution
#   - Root privileges (run with sudo)
#   - Internet connection
#
# Usage: sudo ./setup-shell.sh [OPTIONS]
#   --all            Install all components (non-interactive)
#   --user=<name>    Set username (default: deploy)
#   --help           Show help message
#
# Components:
#   Basic Tools, tmux, Shell Environment (zsh/Oh My Zsh), Ranger, CLI Tools,
#   Go, Python, Sops+age, Docker, AWS CLI v2, MongoDB Shell, Redis CLI,
#   NetBird, yq, lazydocker, lazygit, SSH Keys, Set Default Shell
#
################################################################################

# Exit on error in pipes for safer error handling
set -o pipefail

################################################################################
# Configuration
################################################################################

# SSH Public Key Configuration
SSH_PUBLIC_KEY_URL="https://raw.githubusercontent.com/pandudpn/setup-vm/main/dotfiles/id_ed25519.pub"

# Set to "true" to enable SSH key setup, "false" to skip
SETUP_SSH_KEY="true"

################################################################################
# Component Registry
################################################################################

readonly COMP_COUNT=18

# Component names (short)
COMP_NAMES=(
    "Basic Tools"
    "tmux"
    "Shell Environment"
    "Ranger"
    "CLI Tools"
    "Go"
    "Python"
    "Sops + age"
    "Docker"
    "AWS CLI v2"
    "MongoDB Shell"
    "Redis CLI"
    "NetBird"
    "yq"
    "lazydocker"
    "lazygit"
    "SSH Keys"
    "Set Default Shell"
)

# Component descriptions
COMP_DESCS=(
    "git, curl, wget, jq, build-essential, vim, neovim, nano, tree, etc."
    "Terminal multiplexer with custom config"
    "zsh, Oh My Zsh, plugins, custom .zshrc"
    "File manager with preview dependencies"
    "fzf, ripgrep, ncdu, htop, neofetch, bat"
    "Go programming language + workspace (latest)"
    "Python 3 + pip + venv"
    "Secrets management + encryption tool"
    "Docker CE, Compose, service setup"
    "Amazon Web Services CLI v2"
    "mongosh from MongoDB repository"
    "redis-tools CLI client"
    "WireGuard-based VPN mesh networking"
    "YAML/TOML processor (latest)"
    "TUI Docker manager (latest)"
    "TUI Git client (latest)"
    "Download & install SSH public keys"
    "Change default shell to zsh"
)

# Component dependencies (space-separated indices)
# Empty string = no dependencies
COMP_DEPS=(
    ""      # 0:  Basic Tools      → (none)
    "0"     # 1:  tmux             → Basic Tools
    "0"     # 2:  Shell Env        → Basic Tools
    "0"     # 3:  Ranger           → Basic Tools
    "0"     # 4:  CLI Tools        → Basic Tools
    "0"     # 5:  Go               → Basic Tools
    "0"     # 6:  Python           → Basic Tools
    "0"     # 7:  Sops + age       → Basic Tools
    "0"     # 8:  Docker           → Basic Tools
    "0"     # 9:  AWS CLI v2       → Basic Tools
    "0"     # 10: MongoDB Shell    → Basic Tools
    "0"     # 11: Redis CLI        → Basic Tools
    "0"     # 12: NetBird          → Basic Tools
    "0"     # 13: yq               → Basic Tools
    "0 8"   # 14: lazydocker       → Basic Tools + Docker
    "0"     # 15: lazygit          → Basic Tools
    "0"     # 16: SSH Keys         → Basic Tools
    "2"     # 17: Set Default Shell→ Shell Env (transitive: → Basic Tools)
)

# Component selection state (1=selected, 0=not selected)
# Default: all ON except SSH Keys (16) which is OFF
COMP_SELECTED=(1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 0 1)

# Global flags set by parse_args
RUN_ALL="false"
CLI_USERNAME=""

################################################################################
# Color codes for output
################################################################################

readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_GREEN='\033[1;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[1;31m'
readonly COLOR_CYAN='\033[1;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_DIM='\033[2m'
readonly COLOR_RESET='\033[0m'

################################################################################
# Helper Functions
################################################################################

# Print informational message in blue
print_message() {
    local message="$1"
    echo -e "${COLOR_BLUE}>> ${message}${COLOR_RESET}"
}

# Print warning message in yellow
print_warning() {
    local message="$1"
    echo -e "${COLOR_YELLOW}>> WARNING: ${message}${COLOR_RESET}"
}

# Print error message in red
print_error() {
    local message="$1"
    echo -e "${COLOR_RED}>> ERROR: ${message}${COLOR_RESET}" >&2
}

# Print success message in green
print_success() {
    local message="$1"
    echo -e "${COLOR_GREEN}>> ${message}${COLOR_RESET}"
}

# Check if script is running with root privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Get normalized architecture string for binary downloads
get_arch() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        "x86_64") echo "amd64" ;;
        "aarch64"|"arm64") echo "arm64" ;;
        "armv7l") echo "armv6l" ;;
        *) echo "amd64" ;;
    esac
}

# Fetch latest release tag from a GitHub repository
# Arguments:
#   $1 - Repository owner
#   $2 - Repository name
# Returns:
#   Version string (without 'v' prefix) on success, exits 1 on failure
get_latest_github_release() {
    local owner="$1"
    local repo="$2"
    local version

    version=$(curl -fsSL --connect-timeout 5 \
        "https://api.github.com/repos/${owner}/${repo}/releases/latest" 2>/dev/null \
        | jq -r '.tag_name' 2>/dev/null)

    # Strip leading 'v' if present
    version="${version#v}"

    if [ -n "$version" ] && [ "$version" != "null" ] && [ "$version" != "" ]; then
        echo "$version"
        return 0
    else
        return 1
    fi
}

# Fetch latest Go version from go.dev
get_latest_go_version() {
    local fallback="1.24.4"
    local version

    version=$(curl -fsSL --connect-timeout 5 "https://go.dev/VERSION?m=text" 2>/dev/null \
        | head -1 | sed 's/^go//')

    if [ -n "$version" ] && [ "$version" != "" ]; then
        echo "$version"
    else
        print_warning "Could not fetch latest Go version, using fallback: $fallback"
        echo "$fallback"
    fi
}

# Parse command-line arguments
# Sets global variables: RUN_ALL, CLI_USERNAME
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --all|-a)
                RUN_ALL="true"
                ;;
            --user=*)
                CLI_USERNAME="${1#--user=}"
                ;;
            --help|-h)
                echo "Usage: sudo ./setup-shell.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --all, -a        Install all components (non-interactive)"
                echo "  --user=<name>    Set username (default: deploy)"
                echo "  --help, -h       Show this help message"
                echo ""
                echo "Components available:"
                for i in $(seq 0 $((COMP_COUNT - 1))); do
                    printf "  %2d) %-20s %s\n" "$((i + 1))" "${COMP_NAMES[$i]}" "— ${COMP_DESCS[$i]}"
                done
                echo ""
                exit 0
                ;;
            *)
                print_warning "Unknown argument: $1"
                ;;
        esac
        shift
    done
}

################################################################################
# User Management Functions
################################################################################

# Get the actual user when script is run with sudo
get_actual_user() {
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        ACTUAL_USER="$SUDO_USER"
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
check_user_exists() {
    local username="$1"
    if id "$username" &>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Create a new user with home directory
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
fix_gpg_keys() {
    print_message "Checking and fixing GPG keys..."

    print_message "Attempting to update existing GPG keys..."
    if apt-key update 2>/dev/null; then
        print_message "GPG keys updated successfully"
        return 0
    else
        print_warning "apt-key update failed or is deprecated, trying alternative methods..."
    fi

    print_message "Fixing permissions on apt directories..."
    chmod -R 755 /etc/apt/sources.list.d/ 2>/dev/null || true
    chmod 644 /etc/apt/sources.list 2>/dev/null || true

    print_message "Cleaning up potentially problematic repository configurations..."
    apt-get clean 2>/dev/null || true
    rm -rf /var/lib/apt/lists/* 2>/dev/null || true
    mkdir -p /var/lib/apt/lists/partial 2>/dev/null || true

    print_message "GPG key fix attempts completed"
    return 0
}

# Update package lists with retry logic
update_package_lists() {
    print_message "Updating package lists..."

    local max_attempts=3
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        print_message "Update attempt $attempt of $max_attempts..."

        if apt-get update 2>&1; then
            print_message "Package lists updated successfully"
            return 0
        else
            print_warning "Package update attempt $attempt failed"

            if [ $attempt -eq 1 ]; then
                print_message "Attempting to fix GPG keys before retry..."
                fix_gpg_keys
            elif [ $attempt -eq 2 ]; then
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

    print_warning "Failed to update package lists after $max_attempts attempts"
    print_warning "Continuing with installation, but some packages may fail..."
    return 1
}

################################################################################
# Package Installation Functions
################################################################################

# Install basic development tools
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

    print_message "Basic tools installation complete: $success_count/${#packages[@]} packages installed"

    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
    fi

    return 0
}

# Install tmux terminal multiplexer
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
install_oh_my_zsh() {
    local username="$1"
    local user_home="$2"
    local oh_my_zsh_dir="${user_home}/.oh-my-zsh"

    print_message "Installing Oh My Zsh for user '$username'..."

    if [ -d "$oh_my_zsh_dir" ]; then
        print_warning "Oh My Zsh already installed at $oh_my_zsh_dir"
        return 0
    fi

    if su - "$username" -c 'sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended' 2>&1; then
        print_message "Oh My Zsh installed successfully for '$username'"
        return 0
    else
        print_warning "Failed to install Oh My Zsh for '$username', continuing..."
        return 1
    fi
}

# Update Oh My Zsh if already installed
update_oh_my_zsh() {
    local username="$1"
    local user_home="$2"
    local oh_my_zsh_dir="${user_home}/.oh-my-zsh"

    print_message "Checking for Oh My Zsh updates for user '$username'..."

    if [ ! -d "$oh_my_zsh_dir" ]; then
        print_warning "Oh My Zsh not installed at $oh_my_zsh_dir, skipping update"
        return 1
    fi

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
install_zsh_plugins() {
    local username="$1"
    local user_home="$2"
    local zsh_plugins_dir="${user_home}/.zsh"

    print_message "Installing zsh plugins for user '$username'..."

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
set_default_shell() {
    local username="$1"

    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    local shell_path
    shell_path=$(which zsh 2>/dev/null)

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
install_ranger() {
    local username="$1"
    local user_home="$2"

    print_message "Installing ranger file manager and preview dependencies..."

    local packages=("ranger" "highlight" "caca-utils" "atool" "w3m" "poppler-utils" "mediainfo")
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

    print_message "Ranger installation complete: $success_count/${#packages[@]} packages installed"

    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
    fi

    local ranger_config_dir="${user_home}/.config/ranger"

    print_message "Creating ranger configuration directory at $ranger_config_dir..."

    if su - "$username" -c "mkdir -p ~/.config/ranger" 2>&1; then
        print_message "Ranger config directory created successfully"

        print_message "Generating default ranger configuration..."
        if su - "$username" -c "ranger --copy-config=all" 2>&1; then
            print_message "Default ranger configuration generated successfully"
        else
            print_warning "Failed to generate default ranger configuration, continuing..."
        fi
    else
        print_warning "Failed to create ranger config directory, continuing..."
    fi

    return 0
}

################################################################################
# Additional Tools Installation Functions
################################################################################

# Install additional useful CLI tools
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

    print_message "Additional tools installation complete: $success_count/${#packages[@]} packages installed"

    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
        print_message "Some tools may not be available in your distribution's repositories"
    fi

    return 0
}

################################################################################
# Go Installation Functions
################################################################################

# Install Go programming language (auto-fetch latest version)
install_golang() {
    print_message "Installing Go programming language..."

    if command -v go &>/dev/null; then
        print_message "Go is already installed, checking version..."
        go version
        return 0
    fi

    local go_version
    go_version=$(get_latest_go_version)

    local go_os="linux"
    local go_arch
    go_arch=$(get_arch)

    local go_url="https://go.dev/dl/go${go_version}.${go_os}-${go_arch}.tar.gz"
    local go_temp_dir="/tmp/go-install"
    local go_tarball="${go_temp_dir}/go.tar.gz"

    mkdir -p "$go_temp_dir"

    print_message "Downloading Go ${go_version} for ${go_os}-${go_arch}..."
    if curl -fsSL "$go_url" -o "$go_tarball" 2>&1; then
        print_message "Go tarball downloaded successfully"
    else
        print_error "Failed to download Go tarball from $go_url"
        rm -rf "$go_temp_dir"
        return 1
    fi

    print_message "Extracting Go to /usr/local..."
    if tar -C /usr/local -xzf "$go_tarball" 2>&1; then
        print_message "Go extracted successfully"
    else
        print_error "Failed to extract Go tarball"
        rm -rf "$go_temp_dir"
        return 1
    fi

    rm -rf "$go_temp_dir"

    print_message "Creating Go environment file..."
    cat > /etc/profile.d/go.sh << 'GO_ENV_EOF'
# Go environment variables
export GOROOT=/usr/local/go
export GOPATH=$HOME/go
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH:/usr/local/go/bin:$GOPATH/bin
GO_ENV_EOF

    chmod 644 /etc/profile.d/go.sh

    export GOROOT=/usr/local/go
    export GOPATH=$HOME/go
    export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

    if /usr/local/go/bin/go version &>/dev/null; then
        print_success "Go ${go_version} installed successfully!"
        /usr/local/go/bin/go version
        return 0
    else
        print_error "Go installation failed"
        return 1
    fi
}

# Setup Go workspace directories for a user
setup_go_workspace() {
    local username="$1"
    local user_home="$2"
    local go_path="${user_home}/go"

    print_message "Setting up Go workspace for user '$username'..."

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
# Python Installation Functions
################################################################################

# Install Python 3, pip, and venv
install_python() {
    print_message "Installing Python 3, pip, and venv..."

    if command -v python3 &>/dev/null; then
        print_message "Python 3 is already installed, checking version..."
        python3 --version
    fi

    local packages=("python3" "python3-pip" "python3-venv")
    local failed_packages=()
    local success_count=0

    for package in "${packages[@]}"; do
        print_message "Installing $package..."

        if apt-get install -y "$package" 2>&1; then
            print_message "$package installed successfully"
            success_count=$((success_count + 1))
        else
            print_warning "Failed to install $package, continuing..."
            failed_packages+=("$package")
        fi
    done

    print_message "Python installation complete: $success_count/${#packages[@]} packages installed"

    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
    fi

    if command -v python3 &>/dev/null; then
        print_success "Python installed successfully!"
        python3 --version
    fi

    return 0
}

################################################################################
# Sops Installation Functions
################################################################################

# Install Sops (Secrets OPerationS) — auto-fetch latest version
install_sops() {
    print_message "Installing Sops (Secrets OPerationS)..."

    if command -v sops &>/dev/null; then
        print_message "Sops is already installed, checking version..."
        sops --version
        return 0
    fi

    local sops_version
    sops_version=$(get_latest_github_release "mozilla" "sops") || sops_version="3.11.0"

    local sops_os="linux"
    local sops_arch
    sops_arch=$(get_arch)

    local sops_url="https://github.com/mozilla/sops/releases/download/v${sops_version}/sops-v${sops_version}.${sops_os}.${sops_arch}"
    local sops_dest="/usr/local/bin/sops"

    print_message "Downloading Sops v${sops_version} for ${sops_os}-${sops_arch}..."
    if curl -fsSL "$sops_url" -o "$sops_dest" 2>&1; then
        print_message "Sops binary downloaded successfully"
    else
        print_error "Failed to download Sops binary from $sops_url"
        return 1
    fi

    print_message "Setting executable permissions for Sops..."
    if chmod 755 "$sops_dest" 2>&1; then
        print_message "Permissions set successfully"
    else
        print_error "Failed to set executable permissions for Sops"
        return 1
    fi

    if command -v sops &>/dev/null; then
        print_success "Sops v${sops_version} installed successfully!"
        sops --version
        return 0
    else
        print_error "Sops installation failed"
        return 1
    fi
}

################################################################################
# age Installation Functions
################################################################################

# Install age encryption tool (companion to sops)
install_age() {
    print_message "Installing age encryption tool..."

    if command -v age &>/dev/null; then
        print_message "age is already installed, checking version..."
        age --version
        return 0
    fi

    # Try apt first
    print_message "Attempting to install age via apt..."
    if apt-get install -y age 2>&1; then
        if command -v age &>/dev/null; then
            print_success "age installed successfully via apt!"
            age --version
            return 0
        fi
    fi

    # Fallback: download from GitHub
    print_message "apt install failed, downloading age from GitHub..."

    local age_version
    age_version=$(get_latest_github_release "FiloSottile" "age") || age_version="1.2.1"

    local arch
    arch=$(get_arch)

    local age_url="https://github.com/FiloSottile/age/releases/download/v${age_version}/age-v${age_version}-linux-${arch}.tar.gz"
    local temp_dir="/tmp/age-install"

    mkdir -p "$temp_dir"

    print_message "Downloading age v${age_version}..."
    if curl -fsSL "$age_url" -o "${temp_dir}/age.tar.gz" 2>&1; then
        print_message "age tarball downloaded successfully"
    else
        print_error "Failed to download age from $age_url"
        rm -rf "$temp_dir"
        return 1
    fi

    print_message "Extracting age..."
    if tar -xzf "${temp_dir}/age.tar.gz" -C "$temp_dir" 2>&1; then
        # Install binaries
        if cp "${temp_dir}/age/age" /usr/local/bin/age 2>&1 && \
           cp "${temp_dir}/age/age-keygen" /usr/local/bin/age-keygen 2>&1; then
            chmod 755 /usr/local/bin/age /usr/local/bin/age-keygen
            print_success "age v${age_version} installed successfully!"
            age --version
        else
            print_error "Failed to install age binaries"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        print_error "Failed to extract age tarball"
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$temp_dir"
    return 0
}

################################################################################
# Docker Installation Functions
################################################################################

# Install Docker from official repository
install_docker() {
    print_message "Installing Docker from official repository..."

    if command -v docker &>/dev/null; then
        print_message "Docker is already installed, checking version..."
        docker --version
        return 0
    fi

    print_message "Installing Docker prerequisites..."
    if ! apt-get install -y ca-certificates curl gnupg lsb-release 2>&1; then
        print_warning "Failed to install Docker prerequisites, continuing..."
    fi

    print_message "Setting up Docker GPG key..."
    mkdir -p /etc/apt/keyrings

    if curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>&1; then
        print_message "Docker GPG key added successfully"
        chmod a+r /etc/apt/keyrings/docker.gpg
    else
        print_warning "Failed to add Docker GPG key, trying alternative method..."
        if curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>&1; then
            print_message "Docker GPG key added successfully (Debian repository)"
            chmod a+r /etc/apt/keyrings/docker.gpg
        else
            print_error "Failed to add Docker GPG key"
            return 1
        fi
    fi

    print_message "Adding Docker repository to apt sources..."

    local distro
    distro=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')
    local codename
    codename=$(lsb_release -cs 2>/dev/null)

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

    print_message "Updating package lists with Docker repository..."
    if ! apt-get update 2>&1; then
        print_warning "Failed to update package lists, continuing..."
    fi

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

    print_message "Docker installation complete: $success_count/${#docker_packages[@]} packages installed"

    if [ ${#failed_packages[@]} -gt 0 ]; then
        print_warning "Failed packages: ${failed_packages[*]}"
        return 1
    fi

    if command -v docker &>/dev/null; then
        print_success "Docker installed successfully!"
        docker --version
        return 0
    else
        print_error "Docker installation failed"
        return 1
    fi
}

# Install Docker Compose (lazy version fetch in fallback only)
install_docker_compose() {
    print_message "Installing Docker Compose..."

    if command -v docker-compose &>/dev/null; then
        print_message "Docker Compose is already installed, checking version..."
        docker-compose --version
        return 0
    fi

    # Try docker-compose-plugin first (recommended method)
    print_message "Installing docker-compose-plugin..."
    if apt-get install -y docker-compose-plugin 2>&1; then
        print_message "docker-compose-plugin installed successfully"

        if docker compose version &>/dev/null; then
            print_success "Docker Compose (plugin) installed successfully!"
            docker compose version
            return 0
        fi
    else
        print_warning "Failed to install docker-compose-plugin, trying standalone docker-compose..."
    fi

    # Fallback: Try standalone docker-compose package
    print_message "Installing standalone docker-compose package..."
    if apt-get install -y docker-compose 2>&1; then
        print_message "docker-compose installed successfully"

        if command -v docker-compose &>/dev/null; then
            print_success "Docker Compose installed successfully!"
            docker-compose --version
            return 0
        fi
    else
        print_warning "Failed to install docker-compose package"
    fi

    # Last resort: download binary directly (lazy version fetch here)
    print_message "Attempting to download Docker Compose binary directly..."

    local compose_version
    compose_version="v$(get_latest_github_release "docker" "compose")" || compose_version="v2.32.4"

    local compose_url="https://github.com/docker/compose/releases/download/${compose_version}/docker-compose-$(uname -s)-$(uname -m)"
    local compose_dest="/usr/local/bin/docker-compose"

    if curl -L "$compose_url" -o "$compose_dest" 2>&1; then
        chmod +x "$compose_dest"

        if command -v docker-compose &>/dev/null; then
            print_success "Docker Compose binary installed successfully!"
            docker-compose --version
            return 0
        fi
    fi

    print_warning "Failed to install Docker Compose"
    return 1
}

# Configure Docker access for a user (add to docker group)
configure_docker_access() {
    local username="$1"

    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

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
enable_docker_service() {
    print_message "Enabling and starting Docker service..."

    if ! command -v systemctl &>/dev/null; then
        print_warning "systemctl not available, skipping Docker service configuration"
        return 1
    fi

    print_message "Enabling Docker service..."
    if systemctl enable docker 2>&1; then
        print_message "Docker service enabled successfully"
    else
        print_warning "Failed to enable Docker service, continuing..."
    fi

    print_message "Starting Docker service..."
    if systemctl start docker 2>&1; then
        print_message "Docker service started successfully"
    else
        print_warning "Failed to start Docker service, it may already be running"
    fi

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
# AWS CLI v2 Installation Functions
################################################################################

# Install AWS CLI v2 from official installer
install_aws_cli() {
    print_message "Installing AWS CLI v2..."

    if command -v aws &>/dev/null; then
        local aws_ver
        aws_ver=$(aws --version 2>&1)
        if echo "$aws_ver" | grep -q "aws-cli/2"; then
            print_message "AWS CLI v2 is already installed"
            echo "$aws_ver"
            return 0
        fi
        print_message "AWS CLI v1 detected, upgrading to v2..."
    fi

    local arch
    arch=$(get_arch)
    local aws_url

    case "$arch" in
        "amd64") aws_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
        "arm64") aws_url="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
        *) aws_url="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
    esac

    local temp_dir="/tmp/aws-cli-install"
    mkdir -p "$temp_dir"

    print_message "Downloading AWS CLI v2..."
    if curl -fsSL "$aws_url" -o "${temp_dir}/awscliv2.zip" 2>&1; then
        print_message "AWS CLI v2 downloaded successfully"
    else
        print_error "Failed to download AWS CLI v2"
        rm -rf "$temp_dir"
        return 1
    fi

    print_message "Extracting AWS CLI v2..."
    if unzip -o "${temp_dir}/awscliv2.zip" -d "$temp_dir" 2>&1; then
        print_message "AWS CLI v2 extracted successfully"
    else
        print_error "Failed to extract AWS CLI v2"
        rm -rf "$temp_dir"
        return 1
    fi

    print_message "Installing AWS CLI v2..."
    if [ -f /usr/local/bin/aws ]; then
        # Update existing installation
        if "${temp_dir}/aws/install" --update 2>&1; then
            print_success "AWS CLI v2 updated successfully!"
        else
            print_error "Failed to update AWS CLI v2"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        if "${temp_dir}/aws/install" 2>&1; then
            print_success "AWS CLI v2 installed successfully!"
        else
            print_error "Failed to install AWS CLI v2"
            rm -rf "$temp_dir"
            return 1
        fi
    fi

    rm -rf "$temp_dir"

    if command -v aws &>/dev/null; then
        aws --version
        return 0
    else
        print_error "AWS CLI v2 installation verification failed"
        return 1
    fi
}

################################################################################
# MongoDB Shell Installation Functions
################################################################################

# Install MongoDB Shell (mongosh) from MongoDB repository
install_mongosh() {
    print_message "Installing MongoDB Shell (mongosh)..."

    if command -v mongosh &>/dev/null; then
        print_message "mongosh is already installed, checking version..."
        mongosh --version
        return 0
    fi

    # Import MongoDB GPG key
    print_message "Importing MongoDB GPG key..."
    if curl -fsSL https://www.mongodb.org/static/pgp/server-8.0.asc \
        | gpg --dearmor -o /usr/share/keyrings/mongodb-server-8.0.gpg 2>&1; then
        print_message "MongoDB GPG key imported successfully"
    else
        print_error "Failed to import MongoDB GPG key"
        return 1
    fi

    # Detect distribution
    local distro
    distro=$(lsb_release -is 2>/dev/null | tr '[:upper:]' '[:lower:]')
    local codename
    codename=$(lsb_release -cs 2>/dev/null)

    # Add MongoDB repository
    print_message "Adding MongoDB repository..."
    local repo_component="multiverse"
    if [ "$distro" = "debian" ]; then
        repo_component="main"
    fi

    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] \
https://repo.mongodb.org/apt/${distro} ${codename}/mongodb-org/8.0 ${repo_component}" \
        | tee /etc/apt/sources.list.d/mongodb-org-8.0.list > /dev/null

    # Update and install
    print_message "Updating package lists..."
    if ! apt-get update 2>&1; then
        print_warning "Failed to update with current codename, trying fallback..."

        # Fallback codename
        local fallback_codename
        if [ "$distro" = "ubuntu" ]; then
            fallback_codename="jammy"
        else
            fallback_codename="bookworm"
        fi

        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg] \
https://repo.mongodb.org/apt/${distro} ${fallback_codename}/mongodb-org/8.0 ${repo_component}" \
            | tee /etc/apt/sources.list.d/mongodb-org-8.0.list > /dev/null

        apt-get update 2>&1 || print_warning "Package update failed, continuing..."
    fi

    print_message "Installing mongodb-mongosh..."
    if apt-get install -y mongodb-mongosh 2>&1; then
        if command -v mongosh &>/dev/null; then
            print_success "mongosh installed successfully!"
            mongosh --version
            return 0
        fi
    fi

    print_warning "Failed to install mongosh"
    return 1
}

################################################################################
# Redis CLI Installation Functions
################################################################################

# Install Redis CLI tools
install_redis_cli() {
    print_message "Installing Redis CLI tools..."

    if command -v redis-cli &>/dev/null; then
        print_message "redis-cli is already installed"
        redis-cli --version
        return 0
    fi

    if apt-get install -y redis-tools 2>&1; then
        if command -v redis-cli &>/dev/null; then
            print_success "redis-cli installed successfully!"
            redis-cli --version
            return 0
        fi
    fi

    print_warning "Failed to install redis-tools"
    return 1
}

################################################################################
# NetBird Installation Functions
################################################################################

# Install NetBird VPN mesh client
install_netbird() {
    print_message "Installing NetBird VPN mesh client..."

    if command -v netbird &>/dev/null; then
        print_message "NetBird is already installed, checking version..."
        netbird version
        return 0
    fi

    # Import NetBird GPG key
    print_message "Importing NetBird GPG key..."
    if curl -fsSL https://pkgs.netbird.io/debian/public.key \
        | gpg --dearmor -o /usr/share/keyrings/netbird-archive-keyring.gpg 2>&1; then
        print_message "NetBird GPG key imported successfully"
    else
        print_error "Failed to import NetBird GPG key"
        return 1
    fi

    # Add NetBird repository
    print_message "Adding NetBird repository..."
    echo "deb [signed-by=/usr/share/keyrings/netbird-archive-keyring.gpg] \
https://pkgs.netbird.io/debian stable main" \
        | tee /etc/apt/sources.list.d/netbird.list > /dev/null

    # Update and install
    print_message "Updating package lists..."
    if ! apt-get update 2>&1; then
        print_warning "Failed to update package lists, continuing..."
    fi

    print_message "Installing netbird..."
    if apt-get install -y netbird 2>&1; then
        if command -v netbird &>/dev/null; then
            print_success "NetBird installed successfully!"
            netbird version
            return 0
        fi
    fi

    print_warning "Failed to install NetBird"
    return 1
}

################################################################################
# yq Installation Functions
################################################################################

# Install yq YAML/TOML processor (auto-fetch latest)
install_yq() {
    print_message "Installing yq YAML/TOML processor..."

    if command -v yq &>/dev/null; then
        print_message "yq is already installed, checking version..."
        yq --version
        return 0
    fi

    local yq_version
    yq_version=$(get_latest_github_release "mikefarah" "yq") || yq_version="4.44.6"

    local arch
    arch=$(get_arch)

    local yq_url="https://github.com/mikefarah/yq/releases/download/v${yq_version}/yq_linux_${arch}"
    local yq_dest="/usr/local/bin/yq"

    print_message "Downloading yq v${yq_version}..."
    if curl -fsSL "$yq_url" -o "$yq_dest" 2>&1; then
        chmod 755 "$yq_dest"

        if command -v yq &>/dev/null; then
            print_success "yq v${yq_version} installed successfully!"
            yq --version
            return 0
        fi
    fi

    print_error "Failed to install yq"
    return 1
}

################################################################################
# lazydocker Installation Functions
################################################################################

# Install lazydocker TUI Docker manager (auto-fetch latest)
install_lazydocker() {
    print_message "Installing lazydocker TUI Docker manager..."

    if command -v lazydocker &>/dev/null; then
        print_message "lazydocker is already installed, checking version..."
        lazydocker --version
        return 0
    fi

    local ld_version
    ld_version=$(get_latest_github_release "jesseduffield" "lazydocker") || ld_version="0.24.1"

    local arch
    arch=$(get_arch)
    local arch_fmt
    case "$arch" in
        "amd64") arch_fmt="x86_64" ;;
        "arm64") arch_fmt="arm64" ;;
        *) arch_fmt="x86_64" ;;
    esac

    local ld_url="https://github.com/jesseduffield/lazydocker/releases/download/v${ld_version}/lazydocker_${ld_version}_Linux_${arch_fmt}.tar.gz"
    local temp_dir="/tmp/lazydocker-install"

    mkdir -p "$temp_dir"

    print_message "Downloading lazydocker v${ld_version}..."
    if curl -fsSL "$ld_url" -o "${temp_dir}/lazydocker.tar.gz" 2>&1; then
        print_message "lazydocker tarball downloaded successfully"
    else
        print_error "Failed to download lazydocker"
        rm -rf "$temp_dir"
        return 1
    fi

    print_message "Extracting lazydocker..."
    if tar -xzf "${temp_dir}/lazydocker.tar.gz" -C "$temp_dir" 2>&1; then
        if cp "${temp_dir}/lazydocker" /usr/local/bin/lazydocker 2>&1; then
            chmod 755 /usr/local/bin/lazydocker
            print_success "lazydocker v${ld_version} installed successfully!"
            lazydocker --version 2>&1 || true
        else
            print_error "Failed to install lazydocker binary"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        print_error "Failed to extract lazydocker tarball"
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$temp_dir"
    return 0
}

################################################################################
# lazygit Installation Functions
################################################################################

# Install lazygit TUI Git client (auto-fetch latest)
install_lazygit() {
    print_message "Installing lazygit TUI Git client..."

    if command -v lazygit &>/dev/null; then
        print_message "lazygit is already installed, checking version..."
        lazygit --version
        return 0
    fi

    local lg_version
    lg_version=$(get_latest_github_release "jesseduffield" "lazygit") || lg_version="0.44.1"

    local arch
    arch=$(get_arch)
    local arch_fmt
    case "$arch" in
        "amd64") arch_fmt="x86_64" ;;
        "arm64") arch_fmt="arm64" ;;
        *) arch_fmt="x86_64" ;;
    esac

    local lg_url="https://github.com/jesseduffield/lazygit/releases/download/v${lg_version}/lazygit_${lg_version}_Linux_${arch_fmt}.tar.gz"
    local temp_dir="/tmp/lazygit-install"

    mkdir -p "$temp_dir"

    print_message "Downloading lazygit v${lg_version}..."
    if curl -fsSL "$lg_url" -o "${temp_dir}/lazygit.tar.gz" 2>&1; then
        print_message "lazygit tarball downloaded successfully"
    else
        print_error "Failed to download lazygit"
        rm -rf "$temp_dir"
        return 1
    fi

    print_message "Extracting lazygit..."
    if tar -xzf "${temp_dir}/lazygit.tar.gz" -C "$temp_dir" 2>&1; then
        if cp "${temp_dir}/lazygit" /usr/local/bin/lazygit 2>&1; then
            chmod 755 /usr/local/bin/lazygit
            print_success "lazygit v${lg_version} installed successfully!"
            lazygit --version 2>&1 || true
        else
            print_error "Failed to install lazygit binary"
            rm -rf "$temp_dir"
            return 1
        fi
    else
        print_error "Failed to extract lazygit tarball"
        rm -rf "$temp_dir"
        return 1
    fi

    rm -rf "$temp_dir"
    return 0
}

################################################################################
# Configuration File Management Functions
################################################################################

# Backup existing configuration file with timestamp
backup_existing_config() {
    local filepath="$1"

    if [ ! -f "$filepath" ]; then
        print_message "No existing file at $filepath, no backup needed"
        return 0
    fi

    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
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
create_zshrc() {
    local destination="$1"
    local user_home="${2:-$HOME}"
    local oh_my_zsh_dir="${user_home}/.oh-my-zsh"
    local has_oh_my_zsh="false"

    print_message "Creating .zshrc configuration at $destination..."

    if [ -d "$oh_my_zsh_dir" ]; then
        has_oh_my_zsh="true"
        print_message "Oh My Zsh detected, creating enhanced .zshrc with Oh My Zsh support"
    else
        print_warning "Oh My Zsh not found, creating basic .zshrc configuration"
    fi

    backup_existing_config "$destination"

    cat > "$destination" << ZSHRC_EOF
# Ensure default PATH is set before Oh My Zsh
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH

# Basic zsh settings
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt AUTO_CD
setopt CORRECT

# Enable colors
autoload -U colors && colors

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
zstyle ':completion:*' list-colors "\${(s.:.)LS_COLORS}"
zstyle ':completion:*' rehash true
zstyle ':completion:*' accept-exact '*(N)'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.zsh/cache

ZSHRC_EOF

    # Add Oh My Zsh configuration if installed
    if [ "$has_oh_my_zsh" = "true" ]; then
        cat >> "$destination" << 'ZSHRC_OMZ_EOF'
# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="agnoster"

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

ZSHRC_OMZ_EOF
    else
        cat >> "$destination" << 'ZSHRC_PROMPT_EOF'
# Basic prompt with colors
if [ -n "$SSH_CLIENT" ]; then
    PROMPT="%{$fg[green]%}%n@%m%{$reset_color%}:%{$fg[blue]%}%~%{$reset_color%}%# "
else
    PROMPT="%{$fg[green]%}%~%{$reset_color%}%# "
fi

ZSHRC_PROMPT_EOF
    fi

    # Add common configuration (aliases, environment, etc.)
    cat >> "$destination" << 'ZSHRC_COMMON_EOF'

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

# Python aliases
if command -v python3 &> /dev/null; then
    alias python='python3'
    alias pip='pip3'
fi

# lazydocker alias
if command -v lazydocker &> /dev/null; then
    alias lzd='lazydocker'
fi

# lazygit alias
if command -v lazygit &> /dev/null; then
    alias lg='lazygit'
fi

# AWS CLI completion (for zsh)
if command -v aws &> /dev/null; then
    autoload bashcompinit && bashcompinit
    complete -C '/usr/local/bin/aws_completer' aws
fi

# MongoDB aliases
if command -v mongosh &> /dev/null; then
    alias mongo='mongosh'
fi

# NetBird aliases
if command -v netbird &> /dev/null; then
    alias nb='netbird'
    alias nbs='netbird status'
fi

# Source zsh plugins
if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
fi

if [ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Custom prompt context (only for Oh My Zsh)
prompt_context_custom() {
  if [[ "$USER" != "deploy" || -n "$SSH_CLIENT" ]]; then
    prompt_segment black default "%(!.%{%F{yellow}%}.)$USER"
  fi
}

# Environment variables
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
echo "Welcome to your development environment!"
echo "Type 'help-aliases' to see available custom aliases"
echo ""

# Function to show custom aliases
help-aliases() {
    echo "Custom Aliases:"
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
    echo "  lzd           - lazydocker TUI"
    echo ""
    echo "Git:"
    echo "  gs, ga, gc    - Git status/add/commit"
    echo "  gp, gl        - Git push/pull"
    echo "  glog          - Git log (pretty)"
    echo "  lg            - lazygit TUI"
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
    echo "  python / pip  - Python 3 / pip3"
    echo "  mongo         - mongosh"
    echo "  nb / nbs      - NetBird / NetBird status"
    echo ""
    echo "Secrets:"
    echo "  sops-edit     - Edit encrypted file"
    echo "  sops-view     - Decrypt and view"
    echo "  sops-encrypt  - Encrypt file"
    echo ""
}
ZSHRC_COMMON_EOF

    if [ $? -eq 0 ]; then
        print_message ".zshrc created successfully at $destination"
        return 0
    else
        print_error "Failed to create .zshrc at $destination"
        return 1
    fi
}

# Create .tmux.conf configuration file with complete settings
create_tmux_conf() {
    local destination="$1"

    print_message "Creating .tmux.conf configuration at $destination..."

    backup_existing_config "$destination"

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
create_neofetch_config() {
    local username="$1"
    local user_home="$2"
    local config_dir="${user_home}/.config/neofetch"
    local config_file="${config_dir}/config.conf"

    print_message "Creating custom neofetch configuration for '$username'..."

    if [ ! -d "$config_dir" ]; then
        if su - "$username" -c "mkdir -p ~/.config/neofetch" 2>&1; then
            print_message "Neofetch config directory created"
        else
            print_warning "Failed to create neofetch config directory"
            return 1
        fi
    fi

    cat > "$config_file" << 'NEOFETCH_EOF'
# Neofetch Custom Configuration
print_info() {
    info title
    info underline
    info "OS" distro
    info "Host" model
    info "Kernel" kernel
    info "Uptime" uptime
    info "Packages" packages
    info "Shell" shell
    info "Terminal" term
    info "CPU" cpu
    info "GPU" gpu
    info "Memory" memory
    info cols
}

title_fqdn="off"
kernel_shorthand="on"
distro_shorthand="off"
os_arch="on"
uptime_shorthand="on"
memory_percent="on"
memory_unit="mib"
package_managers="on"
shell_path="off"
shell_version="on"
speed_type="bios_limit"
speed_shorthand="on"
cpu_brand="on"
cpu_speed="on"
cpu_cores="logical"
cpu_temp="off"
gpu_brand="on"
gpu_type="all"
refresh_rate="off"
gtk_shorthand="off"
gtk2="on"
gtk3="on"
public_ip_host="http://ident.me"
public_ip_timeout=2
de_version="on"
disk_show=('/')
disk_subtitle="mount"
disk_percent="on"
colors=(distro)
bold="on"
underline_enabled="on"
underline_char="-"
separator=":"
block_range=(0 15)
color_blocks="on"
block_width=3
block_height=1
col_offset="auto"
bar_char_elapsed="-"
bar_char_total="="
bar_border="on"
bar_length=15
bar_color_elapsed="distro"
bar_color_total="distro"
cpu_display="off"
memory_display="off"
battery_display="off"
disk_display="off"
image_backend="ascii"
image_source="auto"
ascii_distro="auto"
ascii_colors=(distro)
ascii_bold="on"
image_loop="off"
thumbnail_dir="${XDG_CACHE_HOME:-${HOME}/.cache}/thumbnails/neofetch"
crop_mode="normal"
crop_offset="center"
image_size="auto"
gap=3
yoffset=0
xoffset=0
background_color=
stdout="off"
NEOFETCH_EOF

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
fix_ownership() {
    local username="$1"

    if ! check_user_exists "$username"; then
        print_error "User '$username' does not exist"
        return 1
    fi

    local user_home
    user_home=$(getent passwd "$username" 2>/dev/null | cut -d: -f6)
    if [ -z "$user_home" ]; then
        user_home="/home/$username"
    fi

    print_message "Fixing ownership and permissions for user '$username'..."

    local directories=(
        "${user_home}/.oh-my-zsh"
        "${user_home}/.zsh"
        "${user_home}/.config/ranger"
        "${user_home}/.config/neofetch"
        "${user_home}/go"
    )

    local files=(
        "${user_home}/.zshrc"
        "${user_home}/.tmux.conf"
    )

    for dir in "${directories[@]}"; do
        if [ -d "$dir" ]; then
            print_message "Setting ownership for directory: $dir"

            if chown -R "${username}:${username}" "$dir" 2>&1; then
                print_message "Ownership set successfully for $dir"
            else
                print_warning "Failed to set ownership for $dir, continuing..."
            fi

            if find "$dir" -type d -exec chmod 755 {} \; 2>&1; then
                print_message "Directory permissions set to 755 for $dir"
            else
                print_warning "Failed to set directory permissions for $dir, continuing..."
            fi

            if find "$dir" -type f -exec chmod 644 {} \; 2>&1; then
                print_message "File permissions set to 644 within $dir"
            else
                print_warning "Failed to set file permissions within $dir, continuing..."
            fi
        else
            print_message "Directory $dir does not exist, skipping..."
        fi
    done

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_message "Setting ownership for file: $file"

            if chown "${username}:${username}" "$file" 2>&1; then
                print_message "Ownership set successfully for $file"
            else
                print_warning "Failed to set ownership for $file, continuing..."
            fi

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
setup_ssh_keys() {
    local username="$1"
    local key_url="$2"

    if [ -z "$key_url" ]; then
        print_warning "No SSH key URL provided, skipping SSH key setup"
        return 1
    fi

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

    local user_home
    user_home=$(getent passwd "$username" 2>/dev/null | cut -d: -f6)
    if [ -z "$user_home" ]; then
        user_home="/home/$username"
    fi

    local ssh_dir="${user_home}/.ssh"
    local authorized_keys="${ssh_dir}/authorized_keys"

    print_message "Setting up SSH keys for user '$username'..."

    if [ ! -d "$ssh_dir" ]; then
        print_message "Creating .ssh directory at $ssh_dir..."

        if su - "$username" -c "mkdir -p ~/.ssh" 2>&1; then
            print_message ".ssh directory created successfully"
        else
            print_error "Failed to create .ssh directory"
            return 1
        fi
    fi

    print_message "Downloading SSH public key from: $key_url"

    local temp_key_file
    temp_key_file=$(mktemp)

    if curl -fsSL "$key_url" -o "$temp_key_file" 2>&1; then
        print_message "SSH public key downloaded successfully"
    elif wget -q "$key_url" -O "$temp_key_file" 2>&1; then
        print_message "SSH public key downloaded successfully (using wget)"
    else
        print_error "Failed to download SSH public key from $key_url"
        rm -f "$temp_key_file"
        return 1
    fi

    if [ ! -s "$temp_key_file" ]; then
        print_error "Downloaded SSH key file is empty"
        rm -f "$temp_key_file"
        return 1
    fi

    if ! grep -qE "^(ssh-rsa|ssh-ed25519|ecdsa-sha2-nistp256|ssh-dss)" "$temp_key_file"; then
        print_error "Downloaded file does not appear to contain valid SSH public keys"
        rm -f "$temp_key_file"
        return 1
    fi

    if [ -f "$authorized_keys" ]; then
        local timestamp
        timestamp=$(date +%Y%m%d%H%M%S)
        local backup_file="${authorized_keys}.backup.${timestamp}"

        print_message "Backing up existing authorized_keys to $backup_file"

        if cp "$authorized_keys" "$backup_file" 2>&1; then
            chown "${username}:${username}" "$backup_file" 2>/dev/null || true
            print_message "Backup created successfully"
        else
            print_warning "Failed to create backup of authorized_keys"
        fi
    fi

    print_message "Installing SSH public key to $authorized_keys..."

    if cp "$temp_key_file" "$authorized_keys" 2>&1; then
        print_message "SSH public key installed successfully"
    else
        print_error "Failed to install SSH public key"
        rm -f "$temp_key_file"
        return 1
    fi

    rm -f "$temp_key_file"

    print_message "Setting correct ownership and permissions for SSH files..."

    if chown -R "${username}:${username}" "$ssh_dir" 2>&1; then
        print_message "Ownership set successfully"
    else
        print_warning "Failed to set ownership for .ssh directory"
    fi

    if chmod 700 "$ssh_dir" 2>&1; then
        print_message "Permissions set to 700 for .ssh directory"
    else
        print_warning "Failed to set permissions for .ssh directory"
    fi

    if chmod 600 "$authorized_keys" 2>&1; then
        print_message "Permissions set to 600 for authorized_keys"
    else
        print_warning "Failed to set permissions for authorized_keys"
    fi

    local key_count
    key_count=$(grep -c "^ssh-" "$authorized_keys" 2>/dev/null || echo "0")
    print_message "Installed SSH public keys: $key_count key(s)"

    print_message "SSH key setup completed successfully for '$username'"
    return 0
}

################################################################################
# Interactive Menu Functions
################################################################################

# Display the interactive toggle menu
show_menu() {
    local choice

    while true; do
        # Clear screen
        printf '\033c'

        # Header
        echo -e "${COLOR_CYAN}"
        echo "  =================================================================="
        echo "       Terminal Setup - Interactive Component Selection"
        echo "  =================================================================="
        echo -e "${COLOR_RESET}"
        echo ""

        # Component list
        local i
        for i in $(seq 0 $((COMP_COUNT - 1))); do
            local idx=$((i + 1))
            local state
            if [ "${COMP_SELECTED[$i]}" -eq 1 ]; then
                state="${COLOR_GREEN}[x]${COLOR_RESET}"
            else
                state="${COLOR_DIM}[ ]${COLOR_RESET}"
            fi

            printf "  %s %2d) %-20s ${COLOR_DIM}— %s${COLOR_RESET}\n" \
                "$state" "$idx" "${COMP_NAMES[$i]}" "${COMP_DESCS[$i]}"
        done

        echo ""
        echo -e "  ${COLOR_DIM}──────────────────────────────────────────────────────────────${COLOR_RESET}"
        echo -e "  ${COLOR_WHITE}Toggle: 1-${COMP_COUNT}   ${COLOR_GREEN}[a]${COLOR_RESET} All ON   ${COLOR_YELLOW}[n]${COLOR_RESET} All OFF   ${COLOR_CYAN}[r]${COLOR_RESET} Run   ${COLOR_RED}[q]${COLOR_RESET} Quit"
        echo -e "  ${COLOR_DIM}──────────────────────────────────────────────────────────────${COLOR_RESET}"
        echo ""
        echo -ne "  Enter choice: "
        read -r choice

        # Process input
        case "$choice" in
            a|A)
                # Select all
                for i in $(seq 0 $((COMP_COUNT - 1))); do
                    COMP_SELECTED[$i]=1
                done
                ;;
            n|N)
                # Deselect all
                for i in $(seq 0 $((COMP_COUNT - 1))); do
                    COMP_SELECTED[$i]=0
                done
                ;;
            r|R)
                # Run — break out of menu loop
                break
                ;;
            q|Q)
                print_message "Installation cancelled by user."
                exit 0
                ;;
            *)
                # Try to parse as space-separated numbers
                local nums
                # Replace commas with spaces for flexible input
                nums=$(echo "$choice" | tr ',' ' ')
                for num in $nums; do
                    # Validate it's a number
                    if [[ "$num" =~ ^[0-9]+$ ]]; then
                        local idx=$((num - 1))
                        if [ "$idx" -ge 0 ] && [ "$idx" -lt "$COMP_COUNT" ]; then
                            # Toggle
                            if [ "${COMP_SELECTED[$idx]}" -eq 1 ]; then
                                COMP_SELECTED[$idx]=0
                            else
                                COMP_SELECTED[$idx]=1
                            fi
                        fi
                    fi
                done
                ;;
        esac
    done
}

# Resolve dependencies — auto-enable required components
# Handles transitive dependencies (e.g., 17→2→0)
resolve_dependencies() {
    local changed="true"

    while [ "$changed" = "true" ]; do
        changed="false"

        local i
        for i in $(seq 0 $((COMP_COUNT - 1))); do
            # Skip if not selected
            if [ "${COMP_SELECTED[$i]}" -ne 1 ]; then
                continue
            fi

            # Check dependencies
            local deps="${COMP_DEPS[$i]}"
            if [ -z "$deps" ]; then
                continue
            fi

            for dep in $deps; do
                if [ "${COMP_SELECTED[$dep]}" -ne 1 ]; then
                    COMP_SELECTED[$dep]=1
                    changed="true"
                    print_warning "Auto-enabling '${COMP_NAMES[$dep]}' (required by '${COMP_NAMES[$i]}')"
                fi
            done
        done
    done
}

# Confirm selections before proceeding
confirm_selections() {
    echo ""
    print_message "Selected components for installation:"
    echo ""

    local count=0
    local i
    for i in $(seq 0 $((COMP_COUNT - 1))); do
        if [ "${COMP_SELECTED[$i]}" -eq 1 ]; then
            echo -e "  ${COLOR_GREEN}[x]${COLOR_RESET} ${COMP_NAMES[$i]}"
            count=$((count + 1))
        fi
    done

    echo ""
    print_message "Total: $count component(s) selected"
    echo ""

    if [ "$count" -eq 0 ]; then
        print_warning "No components selected. Nothing to install."
        exit 0
    fi

    echo -ne "  Proceed with installation? [Y/n]: "
    read -r confirm

    case "$confirm" in
        n|N|no|No|NO)
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}

################################################################################
# Component Dispatcher
################################################################################

# Run a single component's installation
# Arguments:
#   $1 - Component index (0-17)
#   $2 - Username
#   $3 - User home directory
run_component() {
    local idx="$1"
    local username="$2"
    local user_home="$3"

    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    print_message "Installing component $((idx + 1))/${COMP_COUNT}: ${COMP_NAMES[$idx]}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""

    case "$idx" in
        0)
            install_basic_tools
            ;;
        1)
            install_tmux
            create_tmux_conf "${user_home}/.tmux.conf"
            ;;
        2)
            install_zsh
            if [ -d "${user_home}/.oh-my-zsh" ]; then
                update_oh_my_zsh "$username" "$user_home"
            else
                install_oh_my_zsh "$username" "$user_home"
            fi
            install_zsh_plugins "$username" "$user_home"
            create_zshrc "${user_home}/.zshrc" "$user_home"
            ;;
        3)
            install_ranger "$username" "$user_home"
            ;;
        4)
            install_additional_tools
            create_neofetch_config "$username" "$user_home"
            ;;
        5)
            install_golang
            setup_go_workspace "$username" "$user_home"
            ;;
        6)
            install_python
            ;;
        7)
            install_sops
            install_age
            ;;
        8)
            install_docker
            install_docker_compose
            configure_docker_access "$username"
            enable_docker_service
            ;;
        9)
            install_aws_cli
            ;;
        10)
            install_mongosh
            ;;
        11)
            install_redis_cli
            ;;
        12)
            install_netbird
            ;;
        13)
            install_yq
            ;;
        14)
            install_lazydocker
            ;;
        15)
            install_lazygit
            ;;
        16)
            if [ "$SETUP_SSH_KEY" = "true" ]; then
                setup_ssh_keys "$username" "$SSH_PUBLIC_KEY_URL"
            else
                print_message "SSH key setup disabled (SETUP_SSH_KEY=false)"
            fi
            ;;
        17)
            set_default_shell "$username"
            ;;
        *)
            print_error "Unknown component index: $idx"
            return 1
            ;;
    esac
}

################################################################################
# Summary Display Function
################################################################################

# Display installation completion summary
display_summary() {
    local username="$1"
    local user_home="$2"

    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    print_success "Terminal setup completed successfully!"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
    print_message "Setup Summary:"
    print_message "  User: $username"
    print_message "  Home: $user_home"
    echo ""

    print_message "Installed Components:"
    local i
    for i in $(seq 0 $((COMP_COUNT - 1))); do
        if [ "${COMP_SELECTED[$i]}" -eq 1 ]; then
            echo -e "  ${COLOR_GREEN}[x]${COLOR_RESET} ${COMP_NAMES[$i]}"
        fi
    done

    # SSH key info
    if [ "${COMP_SELECTED[16]}" -eq 1 ] && [ "$SETUP_SSH_KEY" = "true" ] && [ -f "${user_home}/.ssh/authorized_keys" ]; then
        local ssh_key_count
        ssh_key_count=$(grep -c "^ssh-" "${user_home}/.ssh/authorized_keys" 2>/dev/null || echo "0")
        print_message "  SSH Keys: $ssh_key_count key(s) installed"
    fi

    echo ""
    print_message "Next Steps:"
    print_message "  1. (Optional) Set password: sudo passwd $username"
    print_message "  2. Log out and log back in for group changes to take effect"
    print_message "  3. Switch to user '$username': su - $username"
    print_message "  4. Start using your configured environment!"
    echo ""

    if [ "${COMP_SELECTED[2]}" -eq 1 ]; then
        print_message "Configuration files created:"
        print_message "  - ${user_home}/.zshrc"
        [ "${COMP_SELECTED[1]}" -eq 1 ] && print_message "  - ${user_home}/.tmux.conf"
        [ "${COMP_SELECTED[3]}" -eq 1 ] && print_message "  - ${user_home}/.config/ranger/"
        [ "${COMP_SELECTED[4]}" -eq 1 ] && print_message "  - ${user_home}/.config/neofetch/config.conf"
        echo ""
    fi

    print_message "Enjoy your new development environment!"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
}

################################################################################
# Main Script
################################################################################

# Phase 0: Initialization
parse_args "$@"
check_root

print_message "Terminal setup script started"

get_actual_user

# Phase 1: Username handling
if [ -n "$CLI_USERNAME" ]; then
    USERNAME="$CLI_USERNAME"
elif [ "$RUN_ALL" = "true" ] || ! [ -t 0 ]; then
    USERNAME="deploy"
    print_message "Using default username: deploy"
else
    print_message "Enter username for development environment (default: deploy):"
    read -r USERNAME
    USERNAME=${USERNAME:-deploy}
fi

print_message "Setting up environment for user: $USERNAME"

# Create or verify user
if ! check_user_exists "$USERNAME"; then
    print_message "User '$USERNAME' does not exist, creating..."

    if ! create_user "$USERNAME"; then
        print_error "Failed to create user '$USERNAME'"
        exit 1
    fi

    print_message "Setting up passwordless user (you can set password later with: sudo passwd $USERNAME)..."
    if passwd -d "$USERNAME" 2>&1; then
        print_message "User '$USERNAME' created without password"
    else
        print_warning "Failed to disable password for '$USERNAME', continuing..."
    fi

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

# Phase 2: Component selection
if [ "$RUN_ALL" = "true" ]; then
    # --all flag: select everything (including SSH Keys)
    for i in $(seq 0 $((COMP_COUNT - 1))); do
        COMP_SELECTED[$i]=1
    done
    print_message "Running with --all flag, installing all components..."
elif [ -t 0 ]; then
    # Interactive terminal: show menu
    while true; do
        show_menu
        resolve_dependencies
        if confirm_selections; then
            break
        fi
        # User said no — loop back to menu
    done
else
    # Non-interactive, no --all flag: default to all with warning
    for i in $(seq 0 $((COMP_COUNT - 1))); do
        COMP_SELECTED[$i]=1
    done
    print_warning "Non-interactive mode detected, installing all components..."
fi

# Phase 3: Pre-install (always needed)
print_message "Starting pre-installation phase..."
fix_gpg_keys
update_package_lists

# Phase 4: Component execution (in order 0..17)
print_message "Starting component installation phase..."

for i in $(seq 0 $((COMP_COUNT - 1))); do
    if [ "${COMP_SELECTED[$i]}" -eq 1 ]; then
        run_component "$i" "$USERNAME" "$USER_HOME"
    fi
done

# Phase 5: Post-install
print_message "Running post-installation tasks..."
fix_ownership "$USERNAME"

# Display summary
display_summary "$USERNAME" "$USER_HOME"
