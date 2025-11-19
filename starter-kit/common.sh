#!/usr/bin/env bash

################################################################################
# Common Shell Script Library
################################################################################
# PURPOSE: Standardized functions, colors, and conventions for all shell scripts
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
################################################################################

# Color codes (ANSI escape sequences)
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_CYAN='\033[0;36m'
# shellcheck disable=SC2034  # Color palette for library users
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_BOLD='\033[1m'
# shellcheck disable=SC2034  # Color palette for library users
readonly COLOR_DIM='\033[2m'
readonly COLOR_RESET='\033[0m'

# Status prefixes
readonly STATUS_INFO="${COLOR_BLUE}[INFO]${COLOR_RESET}"
readonly STATUS_SUCCESS="${COLOR_GREEN}[OK]${COLOR_RESET}"
readonly STATUS_WARNING="${COLOR_YELLOW}[WARN]${COLOR_RESET}"
readonly STATUS_ERROR="${COLOR_RED}[ERROR]${COLOR_RESET}"
readonly STATUS_DEBUG="${COLOR_CYAN}[DEBUG]${COLOR_RESET}"

################################################################################
# Logging Functions
################################################################################

# Print informational message
log_info() {
    echo -e "${STATUS_INFO} $*"
}

# Print success message
log_success() {
    echo -e "${STATUS_SUCCESS} $*"
}

# Print warning message
log_warning() {
    echo -e "${STATUS_WARNING} $*"
}

# Print error message to stderr
log_error() {
    echo -e "${STATUS_ERROR} $*" >&2
}

# Print debug message (only if DEBUG=1)
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo -e "${STATUS_DEBUG} $*"
    fi
}

# Print header with separators
log_header() {
    echo ""
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo -e "${COLOR_CYAN}${COLOR_BOLD}$*${COLOR_RESET}"
    echo -e "${COLOR_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${COLOR_RESET}"
    echo ""
}

# Print section header (smaller than log_header)
log_section() {
    echo ""
    echo -e "${COLOR_BLUE}▸ $*${COLOR_RESET}"
}

################################################################################
# Error Handling
################################################################################

# Die with error message
die() {
    log_error "$*"
    exit 1
}

# Check if command exists
require_command() {
    local cmd="$1"
    local install_hint="${2:-}"

    if ! command -v "$cmd" &> /dev/null; then
        log_error "Required command not found: $cmd"
        if [[ -n "$install_hint" ]]; then
            log_info "Install with: $install_hint"
        fi
        exit 1
    fi
}

# Check if file exists
require_file() {
    local file="$1"
    local hint="${2:-}"

    if [[ ! -f "$file" ]]; then
        log_error "Required file not found: $file"
        if [[ -n "$hint" ]]; then
            log_info "$hint"
        fi
        exit 1
    fi
}

# Check if directory exists
require_directory() {
    local dir="$1"
    local hint="${2:-}"

    if [[ ! -d "$dir" ]]; then
        log_error "Required directory not found: $dir"
        if [[ -n "$hint" ]]; then
            log_info "$hint"
        fi
        exit 1
    fi
}

################################################################################
# Path Utilities
################################################################################

# Get script directory (use in calling script)
get_script_dir() {
    cd "$(dirname "${BASH_SOURCE[1]}")" && pwd
}

# Get repository root (assumes script is in scripts/ subdirectory)
get_repo_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"

    # Navigate up to find .git directory
    local current_dir="$script_dir"
    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir="$(dirname "$current_dir")"
    done

    die "Could not find repository root (no .git directory found)"
}

################################################################################
# User Interaction
################################################################################

# Ask yes/no question (returns 0 for yes, 1 for no)
# Respects AUTO_YES global variable for non-interactive mode
ask_yes_no() {
    local question="$1"
    local default="${2:-n}"

    # If AUTO_YES is set, automatically return yes
    if [[ "${AUTO_YES:-false}" == "true" ]]; then
        echo -e "${COLOR_YELLOW}[?]${COLOR_RESET} $question [AUTO-YES]"
        return 0
    fi

    local prompt
    if [[ "$default" == "y" ]]; then
        prompt="[Y/n]"
    else
        prompt="[y/N]"
    fi

    echo -ne "${COLOR_YELLOW}[?]${COLOR_RESET} $question $prompt "
    read -r response

    # Handle empty response
    if [[ -z "$response" ]]; then
        response="$default"
    fi

    case "$response" in
        [yY]|[yY][eE][sS])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

################################################################################
# Progress Indicators
################################################################################

# Simple spinner for long-running commands
# Usage: long_command & show_spinner $!
show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'

    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

################################################################################
# Validation Helpers
################################################################################

# Check if running on macOS
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Check if variable is set
is_set() {
    [[ -n "${!1:-}" ]]
}

# Check if running as root
is_root() {
    [[ $EUID -eq 0 ]]
}

################################################################################
# String Utilities
################################################################################

# Convert string to lowercase
to_lowercase() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

# Convert string to uppercase
to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

# Trim whitespace from string
trim() {
    local var="$*"
    var="${var#"${var%%[![:space:]]*}"}"
    var="${var%"${var##*[![:space:]]}"}"
    echo "$var"
}

################################################################################
# Script Metadata
################################################################################

# Print script usage from header comment
# Looks for lines between ## USAGE: and the next ##
print_usage_from_header() {
    local script_file="${1:-${BASH_SOURCE[1]}}"
    sed -n '/^# USAGE:/,/^#$/p' "$script_file" | sed 's/^# //' | sed 's/^#//'
}

################################################################################
# iOS Simulator Management
################################################################################

# Get the UDID of the standard iPhone simulator (iPhone 17 Pro Max)
# Returns the UDID or empty string if not found
get_standard_ios_simulator() {
    local udid
    udid=$(xcrun simctl list devices available 2>/dev/null | grep "iPhone 17 Pro Max" | head -1 | grep -o '([A-F0-9-]\{36\})' | tr -d '()' || true)
    echo "$udid"
}

################################################################################
# Initialization
################################################################################

# Common initialization for all scripts
# Call this at the start of every script
init_script() {
    # Enable strict error handling
    set -euo pipefail

    # Set up trap for cleanup
    trap 'log_error "Script failed at line $LINENO"' ERR

    # Log script start if DEBUG enabled
    log_debug "Script started: ${BASH_SOURCE[1]}"
    log_debug "Working directory: $(pwd)"
    log_debug "User: $(whoami)"
}
