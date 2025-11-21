# Quick Reference Card

## 🚀 Setup Scripts

```bash
# Initial setup
sudo ./setup-shell.sh

# Reset password
sudo ./reset-user-password.sh deploy --disable

# Delete user
sudo ./delete-user.sh deploy

# Test SSH key URL
./test-ssh-key-url.sh "https://github.com/username.keys"

# Customize theme
./customize-theme.sh
```

## 🎨 Themes

```bash
# Change theme interactively
./customize-theme.sh

# Apply specific theme
./customize-theme.sh agnoster
./customize-theme.sh robbyrussell
./customize-theme.sh af-magic

# Random theme
./customize-theme.sh random

# List all themes
./customize-theme.sh --list
```

## 📁 Navigation Aliases

```bash
ll          # List all files (detailed)
la          # List all files including hidden
l           # List files (compact)
..          # Go up one directory
...         # Go up two directories
....        # Go up three directories
c           # Clear screen
h           # Show history
```

## 🐳 Docker Aliases

```bash
dps         # docker ps
dpsa        # docker ps -a
di          # docker images
dex         # docker exec -it <container>
dlog        # docker logs -f <container>
dstop       # docker stop <container>
drm         # docker rm <container>
drmi        # docker rmi <image>
```

## 📝 Git Aliases

```bash
gs          # git status
ga          # git add
gc          # git commit
gp          # git push
gl          # git pull
gd          # git diff
gco         # git checkout
gb          # git branch
glog        # git log --oneline --graph --decorate
```

## 💻 System Aliases

```bash
update      # sudo apt update && sudo apt upgrade -y
install     # sudo apt install
remove      # sudo apt remove
search      # apt search
ports       # netstat -tulanp
meminfo     # free -m -l -t
cpuinfo     # lscpu
diskinfo    # df -h
```

## 🛠️ Tools

```bash
fm          # Ranger file manager
cat         # Bat (with syntax highlighting)
vim         # Vim editor
```

## 📚 Help Commands

```bash
help-aliases    # Show all custom aliases
man <command>   # Manual for command
<command> --help # Help for command
```

## 🔧 Configuration Files

```bash
~/.zshrc                        # Zsh configuration
~/.tmux.conf                    # Tmux configuration
~/.config/neofetch/config.conf  # Neofetch configuration
~/.config/ranger/               # Ranger configuration
~/.ssh/authorized_keys          # SSH keys
```

## 🎯 Tmux Quick Keys

```bash
# Start tmux
tmux

# Inside tmux (prefix is Ctrl+b):
Ctrl+b c        # Create new window
Ctrl+b n        # Next window
Ctrl+b p        # Previous window
Ctrl+b |        # Split vertically
Ctrl+b -        # Split horizontally
Ctrl+b h/j/k/l  # Navigate panes (vim-style)
Ctrl+b d        # Detach from session
Ctrl+b r        # Reload config

# Outside tmux:
tmux ls         # List sessions
tmux attach     # Attach to session
```

## 🔐 SSH

```bash
# SSH key location
~/.ssh/authorized_keys

# Add new key
echo "ssh-ed25519 AAAA..." >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Test SSH connection
ssh user@hostname
```

## 📦 Package Management

```bash
# Update system
update

# Install package
install <package-name>

# Remove package
remove <package-name>

# Search package
search <package-name>

# Clean up
sudo apt autoremove
sudo apt autoclean
```

## 🎨 Customization

### Change Zsh Theme
```bash
# Edit .zshrc
vim ~/.zshrc

# Find line:
ZSH_THEME="agnoster"

# Change to:
ZSH_THEME="robbyrussell"  # or any other theme

# Apply changes
source ~/.zshrc
```

### Customize Neofetch
```bash
# Edit config
vim ~/.config/neofetch/config.conf

# Test changes
neofetch
```

### Add Custom Aliases
```bash
# Edit .zshrc
vim ~/.zshrc

# Add at the end:
alias myalias='command'

# Apply changes
source ~/.zshrc
```

## 🆘 Troubleshooting

### Can't login with password
```bash
sudo ./reset-user-password.sh deploy --disable
su - deploy
```

### Docker permission denied
```bash
# Logout and login again, or:
newgrp docker
```

### Zsh not default shell
```bash
chsh -s $(which zsh)
# Logout and login again
```

### Neofetch not showing
```bash
# Check if installed
which neofetch

# Install if missing
sudo apt install neofetch

# Run manually
neofetch
```

### Theme not working
```bash
# Check Oh My Zsh installation
ls -la ~/.oh-my-zsh

# Reinstall if needed
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

## 📞 Quick Commands Reference

```bash
# System info
neofetch                    # System information
uname -a                    # Kernel info
lsb_release -a             # Distribution info

# Process management
ps aux                      # List all processes
top                         # Process monitor
htop                        # Better process monitor
kill <pid>                  # Kill process

# Network
ip a                        # Show IP addresses
ping <host>                 # Test connectivity
curl <url>                  # Download/test URL
wget <url>                  # Download file

# File operations
find . -name "*.txt"        # Find files
grep -r "text" .            # Search in files
tar -czf file.tar.gz dir/   # Compress
tar -xzf file.tar.gz        # Extract

# Permissions
chmod 755 file              # Change permissions
chown user:group file       # Change ownership
```

---

💡 **Tip:** Bookmark this file for quick reference!

