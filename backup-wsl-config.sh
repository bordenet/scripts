#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: backup-wsl-config.sh
#
# Description: Backs up important WSL configuration files and settings into a
#              timestamped zip archive. Includes system configs, user configs,
#              shell configurations, and package lists. Creates a restore script
#              inside the archive for selective restoration.
#
# Usage: ./backup-wsl-config.sh [backup-directory]
#
# Options:
#   [backup-directory]    Optional: Custom backup location (default: ~/wsl-backups/)
#
# What it backs up:
#   • System configs: /etc/wsl.conf, sudoers, hosts, fstab, hostname, DNS
#   • Shell configs: .bashrc, .zshrc, .bash_profile, .profile, .bash_aliases
#   • Git configuration: .gitconfig, .gitignore_global
#   • SSH configuration: config, known_hosts (keys excluded for security)
#   • Editor configs: vim, neovim, tmux
#   • Dev environments: nvm, rbenv, Python, Rust, Docker configs
#   • Package lists: APT, npm, pip, cargo, Homebrew, Snap, Flatpak
#   • System info: PATH, environment variables, OS details
#
# The Archive Contains:
#   1. All backed up files in organized directories
#   2. restore.sh - Interactive menu-driven restoration script
#   3. README.md - Complete documentation
#
# Restoration:
#   1. Extract archive: unzip wsl-backup-YYYYMMDD_HHMMSS.zip
#   2. Change directory: cd wsl-backup-YYYYMMDD_HHMMSS
#   3. Run restore script: ./restore.sh
#
# Restoration Menu Options:
#   1. Full restore (all configurations)
#   2. System configurations only
#   3. Shell configurations only
#   4. Git configuration
#   5. SSH configuration
#   6. Vim/Neovim configuration
#   7. Development environment configs
#   8. View package lists
#   9. View system information
#
# Safety Features:
#   • Automatically backs up existing files before overwriting
#   • SSH private keys NOT included for security
#   • Menu-driven selective restoration
#   • Timestamped archive names
#
# Platform: WSL (Linux)
#
# Author: Matt J Bordenet
# Last Updated: 2025-01-11
#
# -----------------------------------------------------------------------------

set -euo pipefail

# Get script directory for sourcing libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source library files
# shellcheck source=lib/wsl-backup-lib.sh
source "$SCRIPT_DIR/lib/wsl-backup-lib.sh"
# shellcheck source=lib/wsl-backup-generators.sh
source "$SCRIPT_DIR/lib/wsl-backup-generators.sh"

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    backup-wsl-config.sh - Comprehensive WSL configuration backup utility

SYNOPSIS
    backup-wsl-config.sh [OPTIONS] [BACKUP_DIRECTORY]

DESCRIPTION
    Backs up important WSL configuration files and settings into a timestamped
    zip archive. Includes system configs, user configs, shell configurations,
    and package lists. Creates an interactive restore script inside the archive.

OPTIONS
    -h, --help
        Display this help message and exit.

ARGUMENTS
    BACKUP_DIRECTORY
        Custom backup location. Default: ~/wsl-backups/

PLATFORM
    WSL (Windows Subsystem for Linux) only

WHAT IT BACKS UP
    • System configs: /etc/wsl.conf, sudoers, hosts, fstab, hostname, DNS
    • Shell configs: .bashrc, .zshrc, .bash_profile, .profile, .bash_aliases
    • Git configuration: .gitconfig, .gitignore_global
    • SSH configuration: config, known_hosts (keys excluded for security)
    • Editor configs: vim, neovim, tmux
    • Dev environments: nvm, rbenv, Python, Rust, Docker configs
    • Package lists: APT, npm, pip, cargo, Homebrew, Snap, Flatpak
    • System info: PATH, environment variables, OS details

THE ARCHIVE CONTAINS
    1. All backed up files in organized directories
    2. restore.sh - Interactive menu-driven restoration script
    3. README.md - Complete documentation

RESTORATION
    1. Extract archive: unzip wsl-backup-YYYYMMDD_HHMMSS.zip
    2. Change directory: cd wsl-backup-YYYYMMDD_HHMMSS
    3. Run restore script: ./restore.sh

EXAMPLES
    # Backup to default location
    ./backup-wsl-config.sh

    # Backup to custom directory
    ./backup-wsl-config.sh /mnt/d/backups

NOTES
    SSH private keys are NOT included for security reasons.
    Existing files are automatically backed up before overwriting during restore.

AUTHOR
    Matt J Bordenet

SEE ALSO
    wsl.conf(5), rsync(1), zip(1)

EOF
    exit 0
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

BACKUP_BASE_DIR="${1:-$HOME/wsl-backups}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="wsl-backup-$TIMESTAMP"
BACKUP_DIR="$BACKUP_BASE_DIR/$BACKUP_NAME"
ARCHIVE_PATH="$BACKUP_BASE_DIR/$BACKUP_NAME.zip"

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

print_header "WSL Configuration Backup"

# Check if running in WSL
if ! grep -qi microsoft /proc/version 2>/dev/null; then
    print_error "This script must be run in WSL"
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"
print_info "Backup directory: $BACKUP_DIR"
echo

# -----------------------------------------------------------------------------
# System Configuration Files
# -----------------------------------------------------------------------------

echo -e "${BLUE}System Configuration Files:${NC}"

backup_file "/etc/wsl.conf" "$BACKUP_DIR/system/wsl.conf" "WSL configuration"
backup_file "/etc/hosts" "$BACKUP_DIR/system/hosts" "Hosts file"
backup_file "/etc/fstab" "$BACKUP_DIR/system/fstab" "Filesystem mounts"
backup_file "/etc/hostname" "$BACKUP_DIR/system/hostname" "Hostname"
backup_file "/etc/resolv.conf" "$BACKUP_DIR/system/resolv.conf" "DNS configuration"
backup_file "/etc/environment" "$BACKUP_DIR/system/environment" "System environment"

# Backup sudoers configuration (requires sudo)
if sudo test -f /etc/sudoers; then
    sudo cp -p /etc/sudoers "$BACKUP_DIR/system/sudoers" 2>/dev/null && print_success "Sudoers configuration" || print_warning "Sudoers configuration (copy failed)"
fi

if sudo test -d /etc/sudoers.d; then
    sudo cp -rp /etc/sudoers.d "$BACKUP_DIR/system/sudoers.d" 2>/dev/null && print_success "Sudoers.d directory" || print_warning "Sudoers.d directory (copy failed)"
fi

echo

# -----------------------------------------------------------------------------
# User Configuration Files
# -----------------------------------------------------------------------------

echo -e "${BLUE}User Configuration Files:${NC}"

# Shell configurations
backup_file "$HOME/.bashrc" "$BACKUP_DIR/user/bashrc" "Bash configuration"
backup_file "$HOME/.bash_profile" "$BACKUP_DIR/user/bash_profile" "Bash profile"
backup_file "$HOME/.profile" "$BACKUP_DIR/user/profile" "Shell profile"
backup_file "$HOME/.bash_aliases" "$BACKUP_DIR/user/bash_aliases" "Bash aliases"
backup_file "$HOME/.zshrc" "$BACKUP_DIR/user/zshrc" "Zsh configuration"
backup_file "$HOME/.zprofile" "$BACKUP_DIR/user/zprofile" "Zsh profile"

# Git configuration
backup_file "$HOME/.gitconfig" "$BACKUP_DIR/user/gitconfig" "Git configuration"
backup_file "$HOME/.gitignore_global" "$BACKUP_DIR/user/gitignore_global" "Global gitignore"

# SSH configuration
if [ -d "$HOME/.ssh" ]; then
    backup_file "$HOME/.ssh/config" "$BACKUP_DIR/user/ssh/config" "SSH configuration"
    backup_file "$HOME/.ssh/known_hosts" "$BACKUP_DIR/user/ssh/known_hosts" "SSH known hosts"
    print_info "SSH keys not backed up for security (backup manually if needed)"
fi

# Vim/Neovim configuration
backup_file "$HOME/.vimrc" "$BACKUP_DIR/user/vimrc" "Vim configuration"
backup_dir "$HOME/.vim" "$BACKUP_DIR/user/vim" "Vim directory"
backup_dir "$HOME/.config/nvim" "$BACKUP_DIR/user/config/nvim" "Neovim configuration"

# tmux configuration
backup_file "$HOME/.tmux.conf" "$BACKUP_DIR/user/tmux.conf" "tmux configuration"

# Other common configs
backup_dir "$HOME/.config/fish" "$BACKUP_DIR/user/config/fish" "Fish shell configuration"
backup_file "$HOME/.inputrc" "$BACKUP_DIR/user/inputrc" "Readline configuration"
backup_file "$HOME/.editorconfig" "$BACKUP_DIR/user/editorconfig" "Editor configuration"

echo

# -----------------------------------------------------------------------------
# Development Environment Configurations
# -----------------------------------------------------------------------------

echo -e "${BLUE}Development Environment Configurations:${NC}"

# NVM
backup_file "$HOME/.nvmrc" "$BACKUP_DIR/dev/nvmrc" "NVM default version"
if [ -d "$HOME/.nvm" ]; then
    backup_file "$HOME/.nvm/default-packages" "$BACKUP_DIR/dev/nvm-default-packages" "NVM default packages"
    backup_file "$HOME/.nvm/alias/default" "$BACKUP_DIR/dev/nvm-default-alias" "NVM default alias"
fi

# rbenv
backup_file "$HOME/.ruby-version" "$BACKUP_DIR/dev/ruby-version" "Ruby version"

# Python
backup_file "$HOME/.python-version" "$BACKUP_DIR/dev/python-version" "Python version"

# Rust
backup_file "$HOME/.cargo/config.toml" "$BACKUP_DIR/dev/cargo-config.toml" "Cargo configuration"

# Docker (if using Docker Desktop for Windows)
backup_file "$HOME/.docker/config.json" "$BACKUP_DIR/dev/docker-config.json" "Docker configuration"

echo

# -----------------------------------------------------------------------------
# Package Lists and System Information
# -----------------------------------------------------------------------------

echo -e "${BLUE}Package Lists and System Information:${NC}"

# APT packages
if command -v apt &> /dev/null; then
    apt list --installed 2>/dev/null > "$BACKUP_DIR/packages/apt-packages.txt" && print_success "APT package list"
    dpkg --get-selections > "$BACKUP_DIR/packages/dpkg-selections.txt" 2>/dev/null && print_success "dpkg selections"
fi

# Snap packages
if command -v snap &> /dev/null; then
    snap list > "$BACKUP_DIR/packages/snap-packages.txt" 2>/dev/null && print_success "Snap package list"
fi

# Flatpak packages
if command -v flatpak &> /dev/null; then
    flatpak list > "$BACKUP_DIR/packages/flatpak-packages.txt" 2>/dev/null && print_success "Flatpak package list"
fi

# Homebrew packages
if command -v brew &> /dev/null; then
    brew list > "$BACKUP_DIR/packages/brew-packages.txt" 2>/dev/null && print_success "Homebrew package list"
    brew list --cask > "$BACKUP_DIR/packages/brew-casks.txt" 2>/dev/null && print_success "Homebrew cask list"
fi

# npm global packages
if command -v npm &> /dev/null; then
    npm list -g --depth=0 > "$BACKUP_DIR/packages/npm-global-packages.txt" 2>/dev/null && print_success "npm global packages"
fi

# pip packages
if command -v pip3 &> /dev/null; then
    pip3 list --format=freeze > "$BACKUP_DIR/packages/pip3-packages.txt" 2>/dev/null && print_success "pip3 packages"
fi

# pipx packages
if command -v pipx &> /dev/null; then
    pipx list > "$BACKUP_DIR/packages/pipx-packages.txt" 2>/dev/null && print_success "pipx packages"
fi

# Cargo packages
if command -v cargo &> /dev/null; then
    cargo install --list > "$BACKUP_DIR/packages/cargo-packages.txt" 2>/dev/null && print_success "Cargo packages"
fi

# System information
uname -a > "$BACKUP_DIR/system-info/uname.txt" 2>/dev/null
lsb_release -a > "$BACKUP_DIR/system-info/lsb-release.txt" 2>/dev/null || true
cat /etc/os-release > "$BACKUP_DIR/system-info/os-release.txt" 2>/dev/null || true
env > "$BACKUP_DIR/system-info/environment.txt" 2>/dev/null
echo "$PATH" > "$BACKUP_DIR/system-info/path.txt" 2>/dev/null

print_success "System information"

echo

# -----------------------------------------------------------------------------
# Generate Documentation Files
# -----------------------------------------------------------------------------

echo -e "${BLUE}Creating restoration script and documentation...${NC}"

generate_restore_script "$BACKUP_DIR" && print_success "Restoration script created"
generate_readme "$BACKUP_DIR" && print_success "README created"

echo

# -----------------------------------------------------------------------------
# Create Archive
# -----------------------------------------------------------------------------

echo -e "${BLUE}Creating zip archive...${NC}"

cd "$BACKUP_BASE_DIR"
zip -r "$BACKUP_NAME.zip" "$BACKUP_NAME" > /dev/null 2>&1

if [ -f "$ARCHIVE_PATH" ]; then
    print_success "Archive created: $ARCHIVE_PATH"

    # Get archive size
    ARCHIVE_SIZE=$(du -h "$ARCHIVE_PATH" | cut -f1)
    print_info "Archive size: $ARCHIVE_SIZE"

    # Remove temporary directory
    rm -rf "$BACKUP_DIR"
    print_info "Temporary directory removed"
else
    print_error "Failed to create archive"
    exit 1
fi

echo

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

print_header "Backup Complete"

echo "Archive: $ARCHIVE_PATH"
echo "Size: $ARCHIVE_SIZE"
echo
echo "To restore:"
echo "  1. Extract the archive: unzip $BACKUP_NAME.zip"
echo "  2. Run the restore script: cd $BACKUP_NAME && ./restore.sh"
echo
print_success "WSL configuration backup completed successfully!"
