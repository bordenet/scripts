#!/bin/bash
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }
# -----------------------------------------------------------------------------
#
# Script Name: bu.sh
#
# Description: This script performs a comprehensive system update and cleanup
#              for a macOS environment. It updates Homebrew, npm, mas (Mac App
#              Store), and pip. It also cleans up Homebrew installations and
#              triggers a macOS software update.
#
# Platform:    macOS only
#
# Usage: ./bu.sh
#
# Dependencies:
#   - Homebrew: For managing packages.
#   - npm: For managing Node.js packages.
#   - mas: For managing Mac App Store applications.
#   - pip: For managing Python packages.
#
# Author: Gemini
#
# Last Updated: 2025-11-18
#
# -----------------------------------------------------------------------------

# Do NOT exit on error - we want to continue through failures
set -u  # Exit on undefined variables
set -o pipefail  # Catch errors in pipes

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Global Variables ---
FAILED_TASKS=()
SUCCEEDED_TASKS=()
SKIPPED_TASKS=()
MAX_RETRIES=3
RETRY_DELAY=5

# --- Helper Functions ---

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Execute command with retry logic
# Usage: retry_command "Task name" command [args...]
retry_command() {
    local task_name=$1
    shift
    local attempt=1
    local max_attempts=$MAX_RETRIES

    log_info "Starting: $task_name"

    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            log_warning "Retry attempt $attempt of $max_attempts for: $task_name"
            sleep $RETRY_DELAY
        fi

        # Execute command and capture output
        local output
        if output=$("$@" 2>&1); then
            log_success "$task_name completed"
            SUCCEEDED_TASKS+=("$task_name")
            return 0
        fi

        local exit_code=$?
        log_warning "$task_name failed (attempt $attempt/$max_attempts, exit code: $exit_code)"

        if [ $attempt -eq $max_attempts ]; then
            log_error "$task_name failed after $max_attempts attempts"
            log_error "Last error output:"
            echo "$output" | sed 's/^/  /' >&2
            FAILED_TASKS+=("$task_name")
            return 1
        fi

        ((attempt++))
    done
}

# Execute command without retries but with error handling
# Usage: safe_command "Task name" command [args...]
safe_command() {
    local task_name=$1
    shift

    log_info "Starting: $task_name"

    local output
    if output=$("$@" 2>&1); then
        log_success "$task_name completed"
        SUCCEEDED_TASKS+=("$task_name")
        return 0
    else
        local exit_code=$?
        log_error "$task_name failed (exit code: $exit_code)"
        log_error "Error output:"
        echo "$output" | sed 's/^/  /' >&2
        FAILED_TASKS+=("$task_name")
        return 1
    fi
}

# Check if command exists
command_exists() {
    command -v "$1" &> /dev/null
}

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    bu.sh - Comprehensive macOS system update and cleanup

SYNOPSIS
    bu.sh [OPTIONS]

DESCRIPTION
    Performs a comprehensive system update and cleanup for macOS. Updates Homebrew,
    npm, mas (Mac App Store), and pip packages. Cleans up Homebrew installations
    and triggers macOS software updates.

    This script includes comprehensive error handling and retry logic to ensure
    maximum reliability even when individual operations fail.

OPTIONS
    -h, --help
        Display this help message and exit.

PLATFORM
    macOS only - Script will exit with error on other platforms

DEPENDENCIES
    • Homebrew - Package manager
    • npm - Node.js package manager
    • mas - Mac App Store CLI
    • pip - Python package manager

EXAMPLES
    # Run full system update
    ./bu.sh

NOTES
    This script requires sudo privileges and will request them at startup.
    The script will continue even if individual tasks fail, showing a summary
    at the end.

AUTHOR
    Gemini / Enhanced by Claude Code

SEE ALSO
    brew(1), npm(1), mas(1), pip(1), softwareupdate(8)

EOF
    exit 0
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# Start timer
start_time=$(date +%s)

# --- Initial Setup ---
echo "========================================================================"
echo "  macOS System Update & Cleanup"
echo "========================================================================"
log_info "Starting the system update and cleanup process..."
echo

# Request sudo privileges upfront to avoid prompts later.
if ! sudo -v; then
    log_error "Failed to obtain sudo privileges"
    exit 1
fi

# Keep sudo alive in background
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

clear

# --- Homebrew Updates ---
echo
echo "========================================================================"
echo "  Homebrew Updates"
echo "========================================================================"

retry_command "Homebrew update" brew update

retry_command "Homebrew package upgrades" brew upgrade

safe_command "Homebrew cleanup" brew cleanup -s

# Cask upgrades can be flaky, so use retry
retry_command "Homebrew Cask upgrades" brew upgrade --cask

# Untap is not critical, so don't fail if it doesn't work
log_info "Removing the homebrew/cask tap (if present)..."
if brew untap homebrew/cask 2>/dev/null; then
    log_success "Removed homebrew/cask tap"
    SUCCEEDED_TASKS+=("Remove homebrew/cask tap")
else
    log_info "homebrew/cask tap not present or already removed"
    SKIPPED_TASKS+=("Remove homebrew/cask tap")
fi

# Doctor is informational, don't fail the script
log_info "Running Homebrew Doctor..."
if brew doctor 2>&1; then
    log_success "Homebrew Doctor check passed"
    SUCCEEDED_TASKS+=("Homebrew Doctor")
else
    log_warning "Homebrew Doctor found some issues (non-critical)"
    SKIPPED_TASKS+=("Homebrew Doctor")
fi

# Missing is informational
log_info "Checking for missing Homebrew dependencies..."
if output=$(brew missing 2>&1); then
    if [ -z "$output" ]; then
        log_success "No missing dependencies"
    else
        log_info "Missing dependencies found (informational):"
        echo "$output" | sed 's/^/  /'
    fi
    SUCCEEDED_TASKS+=("Check missing dependencies")
else
    log_warning "Could not check for missing dependencies"
    SKIPPED_TASKS+=("Check missing dependencies")
fi

# --- npm Updates ---
echo
echo "========================================================================"
echo "  npm Updates"
echo "========================================================================"

if ! command_exists npm; then
    log_warning "npm not found, skipping npm updates"
    SKIPPED_TASKS+=("npm updates" "npm self-update")
else
    retry_command "npm global package updates" npm update -g --force

    # npm self-update can sometimes fail, but it's not critical
    log_info "Updating npm itself..."
    if npm install -g npm --force 2>&1; then
        log_success "npm self-update completed"
        SUCCEEDED_TASKS+=("npm self-update")
    else
        log_warning "npm self-update failed (non-critical, continuing)"
        FAILED_TASKS+=("npm self-update")
    fi
fi

# --- Mac App Store Updates (mas) ---
echo
echo "========================================================================"
echo "  Mac App Store Updates"
echo "========================================================================"

if ! command_exists mas; then
    log_warning "mas command not found. Attempting to install..."
    if retry_command "Install mas" brew install mas; then
        log_success "mas installed successfully"
    else
        log_error "Failed to install mas, skipping App Store updates"
        SKIPPED_TASKS+=("Mac App Store updates")
    fi
fi

if command_exists mas; then
    log_info "Checking for Mac App Store updates..."
    if outdated=$(mas outdated 2>&1); then
        if [ -z "$outdated" ]; then
            log_info "No Mac App Store updates available"
            SUCCEEDED_TASKS+=("Check Mac App Store updates")
        else
            log_info "Outdated apps:"
            echo "$outdated" | sed 's/^/  /'

            # mas upgrade is notoriously flaky, so use special handling
            log_info "Attempting to upgrade Mac App Store apps..."
            log_warning "Note: mas upgrade can fail due to App Store service issues"

            # Try multiple times with longer delays
            mas_attempt=1
            mas_max_attempts=3
            mas_success=false

            while [ $mas_attempt -le $mas_max_attempts ]; do
                if [ $mas_attempt -gt 1 ]; then
                    log_warning "mas upgrade attempt $mas_attempt of $mas_max_attempts"
                    log_info "Waiting 10 seconds before retry..."
                    sleep 10
                fi

                if mas upgrade 2>&1; then
                    log_success "Mac App Store apps upgraded"
                    SUCCEEDED_TASKS+=("Mac App Store upgrades")
                    mas_success=true
                    break
                else
                    mas_exit=$?
                    log_warning "mas upgrade failed (attempt $mas_attempt/$mas_max_attempts, exit code: $mas_exit)"

                    # Check if it's the PKInstallErrorDomain error
                    if [ $mas_exit -eq 1 ]; then
                        log_warning "This appears to be an App Store service error"
                        log_info "You may need to:"
                        log_info "  1. Open App Store app and check for updates manually"
                        log_info "  2. Try running 'mas upgrade' again later"
                        log_info "  3. Restart your Mac if the issue persists"
                    fi
                fi

                ((mas_attempt++))
            done

            if [ "$mas_success" = false ]; then
                log_error "Mac App Store upgrades failed after $mas_max_attempts attempts"
                log_warning "Continuing with remaining updates..."
                FAILED_TASKS+=("Mac App Store upgrades")
            fi
        fi
    else
        log_error "Failed to check for Mac App Store updates"
        FAILED_TASKS+=("Check Mac App Store updates")
    fi
fi

# --- macOS Software Update ---
echo
echo "========================================================================"
echo "  macOS Software Updates"
echo "========================================================================"

log_info "Checking for macOS software updates..."
log_warning "This may take several minutes and might require a restart"

# Software updates can take a long time, don't retry
if safe_command "macOS Software Update" sudo softwareupdate --all --install --force -R; then
    log_success "macOS software updates completed"
else
    log_warning "macOS software updates failed or no updates available"
    log_info "You can manually check: System Preferences > Software Update"
fi

# --- Completion ---
echo
echo "========================================================================"
echo "  Update Summary"
echo "========================================================================"

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo
log_info "Total execution time: ${execution_time} seconds"
echo

# Display summary
if [ ${#SUCCEEDED_TASKS[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Successful tasks (${#SUCCEEDED_TASKS[@]}):${NC}"
    for task in "${SUCCEEDED_TASKS[@]}"; do
        echo "  • $task"
    done
    echo
fi

if [ ${#SKIPPED_TASKS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Skipped tasks (${#SKIPPED_TASKS[@]}):${NC}"
    for task in "${SKIPPED_TASKS[@]}"; do
        echo "  • $task"
    done
    echo
fi

if [ ${#FAILED_TASKS[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed tasks (${#FAILED_TASKS[@]}):${NC}"
    for task in "${FAILED_TASKS[@]}"; do
        echo "  • $task"
    done
    echo
    log_warning "Script completed with some failures"
    log_info "Check the output above for details on what failed"
    exit 1
else
    log_success "All tasks completed successfully!"
    exit 0
fi
