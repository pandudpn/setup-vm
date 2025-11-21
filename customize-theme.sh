#!/bin/bash

################################################################################
# Customize Theme Script
#
# Purpose: Change zsh theme and customize terminal appearance
#
# Usage: ./customize-theme.sh [theme-name]
#
################################################################################

# Color codes
readonly COLOR_GREEN='\033[1;32m'
readonly COLOR_RED='\033[1;31m'
readonly COLOR_BLUE='\033[1;34m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RESET='\033[0m'

print_success() {
    echo -e "${COLOR_GREEN}✓ $1${COLOR_RESET}"
}

print_error() {
    echo -e "${COLOR_RED}✗ $1${COLOR_RESET}"
}

print_info() {
    echo -e "${COLOR_BLUE}ℹ $1${COLOR_RESET}"
}

print_warning() {
    echo -e "${COLOR_YELLOW}⚠ $1${COLOR_RESET}"
}

# Popular Oh My Zsh themes
THEMES=(
    "robbyrussell:Simple and fast (default)"
    "agnoster:Powerline-style with git info"
    "af-magic:Colorful with git status"
    "bira:Two-line prompt with time"
    "cloud:Minimalist cloud theme"
    "dallas:Clean and simple"
    "dst:Compact with git info"
    "fino:Elegant two-line prompt"
    "jonathan:Simple with timestamp"
    "ys:Git-focused with exit codes"
    "avit:Clean with git branch"
    "candy:Colorful and fun"
    "clean:Minimal and clean"
    "crunch:Compact with colors"
    "eastwood:Clint Eastwood inspired"
    "frisk:Arrow-based prompt"
    "gallifrey:Doctor Who themed"
    "gentoo:Gentoo-style prompt"
    "gnzh:Simple with colors"
    "half-life:Half-Life inspired"
)

show_themes() {
    echo "=========================================="
    echo "Available Oh My Zsh Themes"
    echo "=========================================="
    echo ""
    
    local i=1
    for theme_info in "${THEMES[@]}"; do
        IFS=':' read -r theme desc <<< "$theme_info"
        printf "%2d. %-20s - %s\n" "$i" "$theme" "$desc"
        i=$((i + 1))
    done
    
    echo ""
    echo "Or enter 'random' for random theme on each startup"
    echo "Or enter 'custom' to manually edit .zshrc"
}

apply_theme() {
    local theme="$1"
    local zshrc="$HOME/.zshrc"
    
    if [ ! -f "$zshrc" ]; then
        print_error ".zshrc not found at $zshrc"
        return 1
    fi
    
    # Backup .zshrc
    local timestamp=$(date +%Y%m%d%H%M%S)
    local backup="${zshrc}.backup.${timestamp}"
    
    print_info "Creating backup: $backup"
    cp "$zshrc" "$backup"
    
    # Update theme in .zshrc
    if [ "$theme" = "random" ]; then
        print_info "Setting up random theme..."
        sed -i 's/^ZSH_THEME=.*/ZSH_THEME="random"/' "$zshrc"
        
        # Add random candidates if not present
        if ! grep -q "ZSH_THEME_RANDOM_CANDIDATES" "$zshrc"; then
            sed -i '/^ZSH_THEME=/a ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" "af-magic" "bira" "ys" )' "$zshrc"
        fi
    else
        print_info "Setting theme to: $theme"
        sed -i "s/^ZSH_THEME=.*/ZSH_THEME=\"$theme\"/" "$zshrc"
        
        # Comment out random candidates if present
        sed -i 's/^ZSH_THEME_RANDOM_CANDIDATES=/# ZSH_THEME_RANDOM_CANDIDATES=/' "$zshrc"
    fi
    
    print_success "Theme updated successfully!"
    print_info "Restart your shell or run: source ~/.zshrc"
    
    return 0
}

preview_theme() {
    local theme="$1"
    
    print_info "Preview of theme: $theme"
    echo ""
    
    # Show a preview by temporarily loading the theme
    ZSH_THEME="$theme"
    
    case "$theme" in
        "robbyrussell")
            echo "➜  ~ git:(master) ✗"
            ;;
        "agnoster")
            echo "┌─[user@hostname] - [~/project] - [git:master ✗]"
            echo "└─▶"
            ;;
        "af-magic")
            echo "user@hostname ~/project (git:master)"
            echo "» "
            ;;
        "bira")
            echo "╭─user@hostname ~/project ‹master›"
            echo "╰─➤ "
            ;;
        "ys")
            echo "# user@hostname in ~/project on git:master ✗ [12:34:56]"
            echo "$ "
            ;;
        *)
            echo "Preview not available for this theme"
            echo "Apply it to see how it looks!"
            ;;
    esac
    
    echo ""
}

# Main script
if [ $# -eq 1 ]; then
    # Theme provided as argument
    THEME="$1"
    
    if [ "$THEME" = "list" ] || [ "$THEME" = "--list" ] || [ "$THEME" = "-l" ]; then
        show_themes
        exit 0
    fi
    
    if [ "$THEME" = "random" ]; then
        apply_theme "random"
        exit 0
    fi
    
    # Check if theme exists in our list
    theme_found=false
    for theme_info in "${THEMES[@]}"; do
        IFS=':' read -r theme_name desc <<< "$theme_info"
        if [ "$theme_name" = "$THEME" ]; then
            theme_found=true
            break
        fi
    done
    
    if [ "$theme_found" = false ]; then
        print_warning "Theme '$THEME' not in popular list, but will try to apply it anyway"
    fi
    
    apply_theme "$THEME"
    exit 0
fi

# Interactive mode
echo "=========================================="
echo "🎨 Zsh Theme Customizer"
echo "=========================================="
echo ""

show_themes

echo ""
read -p "Enter theme number, name, or 'random': " choice

if [ -z "$choice" ]; then
    print_error "No theme selected"
    exit 1
fi

# Check if choice is a number
if [[ "$choice" =~ ^[0-9]+$ ]]; then
    if [ "$choice" -ge 1 ] && [ "$choice" -le "${#THEMES[@]}" ]; then
        theme_info="${THEMES[$((choice - 1))]}"
        IFS=':' read -r theme_name desc <<< "$theme_info"
        
        echo ""
        preview_theme "$theme_name"
        
        read -p "Apply this theme? (y/n): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            apply_theme "$theme_name"
        else
            print_info "Theme not applied"
        fi
    else
        print_error "Invalid theme number"
        exit 1
    fi
elif [ "$choice" = "random" ]; then
    apply_theme "random"
elif [ "$choice" = "custom" ]; then
    print_info "Opening .zshrc in editor..."
    ${EDITOR:-vim} ~/.zshrc
else
    # Assume it's a theme name
    apply_theme "$choice"
fi

