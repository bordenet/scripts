#!/usr/bin/env bash
################################################################################
# Library: wsl-backup-generators.sh
################################################################################
# PURPOSE: Document generation functions for WSL backup system
# PLATFORM: Linux (WSL)
################################################################################

# Source README generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/wsl-backup-readme.sh
source "$SCRIPT_DIR/wsl-backup-readme.sh"

# Function: generate_restore_script
# Description: Creates the interactive restore.sh script in the backup directory
# Parameters:
#   $1 - Backup directory path where restore.sh will be created
# Returns: 0 on success, 1 on failure
generate_restore_script() {
    local backup_dir="$1"

    cat > "$backup_dir/restore.sh" << 'RESTORE_SCRIPT_EOF'
#!/bin/bash
# -----------------------------------------------------------------------------
# WSL Configuration Restore Script
# Generated automatically by backup-wsl-config.sh
# -----------------------------------------------------------------------------

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header() {
    echo -e "${BLUE}=================================================="
    echo -e "$1"
    echo -e "==================================================${NC}"
    echo
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

restore_file() {
    local src="$1"
    local dest="$2"
    local description="$3"
    local needs_sudo="${4:-no}"

    if [ ! -f "$src" ]; then
        print_warning "$description (backup not found)"
        return 1
    fi

    # Backup existing file
    if [ -f "$dest" ]; then
        local backup_dest="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
        if [ "$needs_sudo" = "yes" ]; then
            sudo cp -p "$dest" "$backup_dest" 2>/dev/null || true
        else
            cp -p "$dest" "$backup_dest" 2>/dev/null || true
        fi
        print_info "Backed up existing: $dest → $backup_dest"
    fi

    # Restore file
    if [ "$needs_sudo" = "yes" ]; then
        sudo cp -p "$src" "$dest" 2>/dev/null && print_success "$description" || print_error "$description (restore failed)"
    else
        mkdir -p "$(dirname "$dest")"
        cp -p "$src" "$dest" 2>/dev/null && print_success "$description" || print_error "$description (restore failed)"
    fi
}

restore_dir() {
    local src="$1"
    local dest="$2"
    local description="$3"

    if [ ! -d "$src" ]; then
        print_warning "$description (backup not found)"
        return 1
    fi

    # Backup existing directory
    if [ -d "$dest" ]; then
        local backup_dest="${dest}.backup.$(date +%Y%m%d_%H%M%S)"
        cp -rp "$dest" "$backup_dest" 2>/dev/null || true
        print_info "Backed up existing: $dest → $backup_dest"
    fi

    # Restore directory
    mkdir -p "$(dirname "$dest")"
    cp -rp "$src" "$dest" 2>/dev/null && print_success "$description" || print_error "$description (restore failed)"
}

show_menu() {
    print_header "WSL Configuration Restore"

    echo "Select what to restore:"
    echo
    echo "  1) All configurations (full restore)"
    echo "  2) System configurations (/etc/wsl.conf, sudoers, etc.)"
    echo "  3) User shell configurations (.bashrc, .zshrc, etc.)"
    echo "  4) Git configuration"
    echo "  5) SSH configuration"
    echo "  6) Vim/Neovim configuration"
    echo "  7) Development environment configs (nvm, rbenv, cargo, etc.)"
    echo "  8) View package lists (for manual reinstallation)"
    echo "  9) View system information"
    echo "  0) Exit"
    echo
}

restore_system() {
    echo -e "${BLUE}Restoring system configurations...${NC}"
    echo

    restore_file "$SCRIPT_DIR/system/wsl.conf" "/etc/wsl.conf" "WSL configuration" "yes"
    restore_file "$SCRIPT_DIR/system/hosts" "/etc/hosts" "Hosts file" "yes"
    restore_file "$SCRIPT_DIR/system/fstab" "/etc/fstab" "Filesystem mounts" "yes"
    restore_file "$SCRIPT_DIR/system/hostname" "/etc/hostname" "Hostname" "yes"
    restore_file "$SCRIPT_DIR/system/environment" "/etc/environment" "System environment" "yes"

    if [ -f "$SCRIPT_DIR/system/sudoers" ]; then
        print_warning "Sudoers file found - manual restoration recommended"
        print_info "Run: sudo visudo -f $SCRIPT_DIR/system/sudoers"
    fi

    echo
    print_info "System configuration restore complete"
    print_warning "You may need to restart WSL for changes to take effect"
}

restore_shell() {
    echo -e "${BLUE}Restoring shell configurations...${NC}"
    echo

    restore_file "$SCRIPT_DIR/user/bashrc" "$HOME/.bashrc" "Bash configuration"
    restore_file "$SCRIPT_DIR/user/bash_profile" "$HOME/.bash_profile" "Bash profile"
    restore_file "$SCRIPT_DIR/user/profile" "$HOME/.profile" "Shell profile"
    restore_file "$SCRIPT_DIR/user/bash_aliases" "$HOME/.bash_aliases" "Bash aliases"
    restore_file "$SCRIPT_DIR/user/zshrc" "$HOME/.zshrc" "Zsh configuration"
    restore_file "$SCRIPT_DIR/user/zprofile" "$HOME/.zprofile" "Zsh profile"
    restore_file "$SCRIPT_DIR/user/inputrc" "$HOME/.inputrc" "Readline configuration"
    restore_dir "$SCRIPT_DIR/user/config/fish" "$HOME/.config/fish" "Fish shell configuration"

    echo
    print_info "Shell configuration restore complete"
    print_warning "Run 'source ~/.bashrc' or restart your shell"
}

restore_git() {
    echo -e "${BLUE}Restoring Git configuration...${NC}"
    echo

    restore_file "$SCRIPT_DIR/user/gitconfig" "$HOME/.gitconfig" "Git configuration"
    restore_file "$SCRIPT_DIR/user/gitignore_global" "$HOME/.gitignore_global" "Global gitignore"

    echo
    print_info "Git configuration restore complete"
}

restore_ssh() {
    echo -e "${BLUE}Restoring SSH configuration...${NC}"
    echo

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    restore_file "$SCRIPT_DIR/user/ssh/config" "$HOME/.ssh/config" "SSH configuration"
    restore_file "$SCRIPT_DIR/user/ssh/known_hosts" "$HOME/.ssh/known_hosts" "SSH known hosts"

    [ -f "$HOME/.ssh/config" ] && chmod 600 "$HOME/.ssh/config"

    echo
    print_info "SSH configuration restore complete"
    print_warning "SSH keys not restored - copy manually if needed"
}

restore_vim() {
    echo -e "${BLUE}Restoring Vim/Neovim configuration...${NC}"
    echo

    restore_file "$SCRIPT_DIR/user/vimrc" "$HOME/.vimrc" "Vim configuration"
    restore_dir "$SCRIPT_DIR/user/vim" "$HOME/.vim" "Vim directory"
    restore_dir "$SCRIPT_DIR/user/config/nvim" "$HOME/.config/nvim" "Neovim configuration"
    restore_file "$SCRIPT_DIR/user/tmux.conf" "$HOME/.tmux.conf" "tmux configuration"

    echo
    print_info "Vim/Neovim configuration restore complete"
}

restore_dev() {
    echo -e "${BLUE}Restoring development environment configurations...${NC}"
    echo

    restore_file "$SCRIPT_DIR/dev/nvmrc" "$HOME/.nvmrc" "NVM default version"
    restore_file "$SCRIPT_DIR/dev/nvm-default-packages" "$HOME/.nvm/default-packages" "NVM default packages"
    restore_file "$SCRIPT_DIR/dev/ruby-version" "$HOME/.ruby-version" "Ruby version"
    restore_file "$SCRIPT_DIR/dev/python-version" "$HOME/.python-version" "Python version"
    restore_file "$SCRIPT_DIR/dev/cargo-config.toml" "$HOME/.cargo/config.toml" "Cargo configuration"
    restore_file "$SCRIPT_DIR/dev/docker-config.json" "$HOME/.docker/config.json" "Docker configuration"

    echo
    print_info "Development environment configuration restore complete"
}

view_packages() {
    print_header "Package Lists"

    echo "Package list files available in: $SCRIPT_DIR/packages/"
    echo

    for file in "$SCRIPT_DIR/packages"/*.txt; do
        if [ -f "$file" ]; then
            echo "  • $(basename "$file")"
        fi
    done

    echo
    print_info "Use these lists to manually reinstall packages"
    echo
    read -p "Press Enter to continue..."
}

view_system_info() {
    print_header "System Information"

    echo "System information files available in: $SCRIPT_DIR/system-info/"
    echo

    if [ -f "$SCRIPT_DIR/system-info/uname.txt" ]; then
        echo "System:"
        cat "$SCRIPT_DIR/system-info/uname.txt"
        echo
    fi

    if [ -f "$SCRIPT_DIR/system-info/lsb-release.txt" ]; then
        echo "Distribution:"
        cat "$SCRIPT_DIR/system-info/lsb-release.txt"
        echo
    fi

    if [ -f "$SCRIPT_DIR/system-info/path.txt" ]; then
        echo "PATH at backup time:"
        cat "$SCRIPT_DIR/system-info/path.txt"
        echo
    fi

    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    read -p "Enter your choice: " choice
    echo

    case $choice in
        1)
            print_warning "This will restore ALL configurations"
            read -p "Are you sure? [y/N]: " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                restore_system
                echo
                restore_shell
                echo
                restore_git
                echo
                restore_ssh
                echo
                restore_vim
                echo
                restore_dev
                echo
                print_success "Full restore complete!"
            fi
            echo
            read -p "Press Enter to continue..."
            ;;
        2) restore_system; echo; read -p "Press Enter to continue..." ;;
        3) restore_shell; echo; read -p "Press Enter to continue..." ;;
        4) restore_git; echo; read -p "Press Enter to continue..." ;;
        5) restore_ssh; echo; read -p "Press Enter to continue..." ;;
        6) restore_vim; echo; read -p "Press Enter to continue..." ;;
        7) restore_dev; echo; read -p "Press Enter to continue..." ;;
        8) view_packages ;;
        9) view_system_info ;;
        0)
            print_info "Exiting..."
            exit 0
            ;;
        *)
            print_error "Invalid choice"
            read -p "Press Enter to continue..."
            ;;
    esac
done
RESTORE_SCRIPT_EOF

    chmod +x "$backup_dir/restore.sh"
    return 0
}

# generate_readme function now in lib/wsl-backup-readme.sh
