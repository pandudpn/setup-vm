# Test helper functions for Bats tests

# Color codes for output
readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RED='\033[1;31m'
readonly COLOR_RESET='\033[0m'

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

# Check if script is running with root privileges
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Get the actual user when script is run with sudo
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
    
    # Check if Oh My Zsh is already installed
    if [ -d "$oh_my_zsh_dir" ]; then
        print_warning "Oh My Zsh already installed at $oh_my_zsh_dir"
        return 0
    fi
    
    # Install Oh My Zsh in unattended mode
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

# Set default shell for a user
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

# Backup existing configuration file with timestamp
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
create_zshrc() {
    local destination="$1"
    
    print_message "Creating .zshrc configuration at $destination..."
    
    # Backup existing file if present
    backup_existing_config "$destination"
    
    # Create .zshrc with complete configuration
    cat > "$destination" << 'ZSHRC_EOF'
# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme
ZSH_THEME="xiong-chiamiov-plus"

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
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias vi='vim'
alias fm='ranger'

# Bat/batcat alias handling
if command -v batcat &> /dev/null; then
    alias bat='batcat'
    alias cat='batcat'
elif command -v bat &> /dev/null; then
    alias cat='bat'
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

# Source zsh plugins
if [ -f ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if [ -f ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# Run neofetch on startup
if command -v neofetch &> /dev/null; then
    neofetch
fi
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

setup_script_functions() {
    # Functions are already defined above
    :
}

# Fix ownership and permissions for configuration files and directories
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
