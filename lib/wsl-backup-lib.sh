#!/bin/bash
################################################################################
# Library: wsl-backup-lib.sh
################################################################################
# PURPOSE: Common helper functions for WSL backup operations
# PLATFORM: Linux (WSL)
################################################################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Output Helper Functions
# -----------------------------------------------------------------------------

print_header() {
    echo -e "${BLUE}=================================================="
    echo -e "$1"
    echo -e "==================================================${NC}"
    echo
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# -----------------------------------------------------------------------------
# Backup Helper Functions
# -----------------------------------------------------------------------------

# Function: backup_file
# Description: Backup a file if it exists
# Parameters:
#   $1 - Source file path
#   $2 - Destination file path
#   $3 - Description for output message
# Returns: 0 if file exists and copied, 1 otherwise
backup_file() {
    local src=$1
    local dest=$2
    local description=$3

    if [ -f "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp -p "$src" "$dest" 2>/dev/null && print_success "$description" || print_warning "$description (copy failed)"
        return 0
    else
        print_warning "$description (not found)"
        return 1
    fi
}

# Function: backup_dir
# Description: Backup a directory if it exists
# Parameters:
#   $1 - Source directory path
#   $2 - Destination directory path
#   $3 - Description for output message
# Returns: 0 if directory exists and copied, 1 otherwise
backup_dir() {
    local src=$1
    local dest=$2
    local description=$3

    if [ -d "$src" ]; then
        mkdir -p "$(dirname "$dest")"
        cp -rp "$src" "$dest" 2>/dev/null && print_success "$description" || print_warning "$description (copy failed)"
        return 0
    else
        print_warning "$description (not found)"
        return 1
    fi
}
