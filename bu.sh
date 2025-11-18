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
# Usage: ./bu.sh [-v|--verbose]
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
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Global Variables ---
FAILED_TASKS=()
SUCCEEDED_TASKS=()
SKIPPED_TASKS=()
MAX_RETRIES=3
RETRY_DELAY=5
VERBOSE=false

# ANSI cursor control
ERASE_LINE='\033[2K'
SAVE_CURSOR='\033[s'
RESTORE_CURSOR='\033[u'
TIMER_PID=""

# --- Helper Functions ---

# Display timer in top right corner
show_timer() {
    local elapsed=$(($(date +%s) - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local timer_text
    timer_text=$(printf "%02d:%02d" "$minutes" "$seconds")
    local timer_pos=$((cols - 6))

    # Save cursor, move to top right, print timer with background, restore cursor
    echo -ne "${SAVE_CURSOR}\033[1;${timer_pos}H\033[43;30m ${timer_text} ${NC}${RESTORE_CURSOR}"
}

# Timer background process
timer_loop() {
    while kill -0 $$ 2>/dev/null; do
        show_timer
        sleep 1
    done
}

# Start timer in background
start_timer() {
    if [ "$VERBOSE" = false ]; then
        timer_loop &
        TIMER_PID=$!
    fi
}

# Stop timer
stop_timer() {
    if [ -n "$TIMER_PID" ] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null
    fi
}

# Update current line with spinner
update_status() {
    if [ "$VERBOSE" = false ]; then
        echo -ne "${ERASE_LINE}\r$*"
    fi
}

# Complete current line
complete_status() {
    if [ "$VERBOSE" = false ]; then
        echo -e "${ERASE_LINE}\r$*"
    fi
}

# Log functions
log_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}[SUCCESS]${NC} $*"
    fi
}

log_warning() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${YELLOW}[WARNING]${NC} $*"
    fi
}

log_error() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${RED}[ERROR]${NC} $*"
    fi
}

# Execute command with retry logic
# Usage: retry_command "Task name" "Spinner text" command [args...]
retry_command() {
    local task_name=$1
    local spinner_text=$2
    shift 2
    local attempt=1
    local max_attempts=$MAX_RETRIES

    log_info "Starting: $task_name"

    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            update_status "${YELLOW}↻${NC} $spinner_text (retry $attempt/$max_attempts)..."
            log_warning "Retry attempt $attempt of $max_attempts for: $task_name"
            sleep $RETRY_DELAY
        else
            update_status "  $spinner_text..."
        fi

        # Execute command and capture output
        local output
        if output=$("$@" 2>&1); then
            complete_status "${GREEN}✓${NC} $spinner_text"
            log_success "$task_name completed"
            SUCCEEDED_TASKS+=("$task_name")
            return 0
        fi

        local exit_code=$?
        log_warning "$task_name failed (attempt $attempt/$max_attempts, exit code: $exit_code)"

        if [ $attempt -eq $max_attempts ]; then
            complete_status "${RED}✗${NC} $spinner_text"
            log_error "$task_name failed after $max_attempts attempts"
            if [ "$VERBOSE" = true ]; then
                log_error "Last error output:"
                echo "$output" | sed 's/^/  /' >&2
            fi
            FAILED_TASKS+=("$task_name")
            return 1
        fi

        ((attempt++))
    done
}

# Execute command without retries but with error handling
# Usage: safe_command "Task name" "Spinner text" command [args...]
safe_command() {
    local task_name=$1
    local spinner_text=$2
    shift 2

    log_info "Starting: $task_name"
    update_status "  $spinner_text..."

    local output
    if output=$("$@" 2>&1); then
        complete_status "${GREEN}✓${NC} $spinner_text"
        log_success "$task_name completed"
        SUCCEEDED_TASKS+=("$task_name")
        return 0
    else
        local exit_code=$?
        complete_status "${RED}✗${NC} $spinner_text"
        log_error "$task_name failed (exit code: $exit_code)"
        if [ "$VERBOSE" = true ]; then
            log_error "Error output:"
            echo "$output" | sed 's/^/  /' >&2
        fi
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

    By default, shows minimal output with inline status updates. Use --verbose
    for detailed progress information.

    This script includes comprehensive error handling and retry logic to ensure
    maximum reliability even when individual operations fail.

OPTIONS
    -v, --verbose
        Show detailed progress information and command output

    -h, --help
        Display this help message and exit

PLATFORM
    macOS only - Script will exit with error on other platforms

DEPENDENCIES
    • Homebrew - Package manager
    • npm - Node.js package manager
    • mas - Mac App Store CLI
    • pip - Python package manager

EXAMPLES
    # Run with minimal output (default)
    ./bu.sh

    # Run with verbose output
    ./bu.sh --verbose

NOTES
    This script requires sudo privileges and will request them at startup.
    All sudo operations have a 10-minute timeout to prevent hanging if no one
    is available to dismiss the sudo dialog, allowing unattended background runs.
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
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Use -h or --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Start timer
start_time=$(date +%s)

# --- Initial Setup ---
if [ "$VERBOSE" = true ]; then
    echo "========================================================================"
    echo "  macOS System Update & Cleanup"
    echo "========================================================================"
    log_info "Starting the system update and cleanup process..."
    echo
else
    echo -e "${BOLD}System Update & Cleanup${NC}"
fi

# Request sudo privileges upfront to avoid prompts later.
# 10 minute timeout ensures script can run in background
if ! timeout 600 sudo -v; then
    log_error "Failed to obtain sudo privileges (timed out after 10 minutes)"
    exit 1
fi

# Keep sudo alive in background
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

if [ "$VERBOSE" = false ]; then
    # Clear the screen for clean output
    clear
    echo -e "${BOLD}System Update & Cleanup${NC}\n"
    start_timer
fi

# Ensure timer stops on exit
trap stop_timer EXIT

# --- Homebrew Updates ---
if [ "$VERBOSE" = true ]; then
    echo
    echo "========================================================================"
    echo "  Homebrew Updates"
    echo "========================================================================"
fi

retry_command "Homebrew update" "Updating Homebrew" brew update

retry_command "Homebrew package upgrades" "Upgrading Homebrew packages" brew upgrade

safe_command "Homebrew cleanup" "Cleaning up Homebrew" brew cleanup -s

# Cask upgrades can be flaky, so use retry
retry_command "Homebrew Cask upgrades" "Upgrading Homebrew Casks" brew upgrade --cask

# Untap is not critical, so don't fail if it doesn't work
if [ "$VERBOSE" = true ]; then
    log_info "Removing the homebrew/cask tap (if present)..."
fi
if brew untap homebrew/cask 2>/dev/null; then
    if [ "$VERBOSE" = true ]; then
        log_success "Removed homebrew/cask tap"
    fi
    SUCCEEDED_TASKS+=("Remove homebrew/cask tap")
else
    if [ "$VERBOSE" = true ]; then
        log_info "homebrew/cask tap not present or already removed"
    fi
    SKIPPED_TASKS+=("Remove homebrew/cask tap")
fi

# Doctor is informational, don't fail the script
if [ "$VERBOSE" = true ]; then
    log_info "Running Homebrew Doctor..."
    if brew doctor 2>&1; then
        log_success "Homebrew Doctor check passed"
        SUCCEEDED_TASKS+=("Homebrew Doctor")
    else
        log_warning "Homebrew Doctor found some issues (non-critical)"
        SKIPPED_TASKS+=("Homebrew Doctor")
    fi
else
    update_status "  Checking Homebrew health..."
    if brew doctor >/dev/null 2>&1; then
        complete_status "${GREEN}✓${NC} Homebrew health check"
        SUCCEEDED_TASKS+=("Homebrew Doctor")
    else
        complete_status "${YELLOW}⊘${NC} Homebrew health check (non-critical issues)"
        SKIPPED_TASKS+=("Homebrew Doctor")
    fi
fi

# Missing is informational
if [ "$VERBOSE" = true ]; then
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
else
    SUCCEEDED_TASKS+=("Check missing dependencies")
fi

# --- npm Updates ---
if [ "$VERBOSE" = true ]; then
    echo
    echo "========================================================================"
    echo "  npm Updates"
    echo "========================================================================"
fi

if ! command_exists npm; then
    log_warning "npm not found, skipping npm updates"
    SKIPPED_TASKS+=("npm updates" "npm self-update")
else
    retry_command "npm global package updates" "Updating npm packages" npm update -g --force

    # npm self-update can sometimes fail, but it's not critical
    if [ "$VERBOSE" = true ]; then
        log_info "Updating npm itself..."
    else
        update_status "  Updating npm itself..."
    fi
    if npm install -g npm --force >/dev/null 2>&1; then
        if [ "$VERBOSE" = false ]; then
            complete_status "${GREEN}✓${NC} Updating npm itself"
        fi
        log_success "npm self-update completed"
        SUCCEEDED_TASKS+=("npm self-update")
    else
        if [ "$VERBOSE" = false ]; then
            complete_status "${YELLOW}⊘${NC} Updating npm itself (non-critical)"
        fi
        log_warning "npm self-update failed (non-critical, continuing)"
        FAILED_TASKS+=("npm self-update")
    fi
fi

# --- Mac App Store Updates (mas) ---
if [ "$VERBOSE" = true ]; then
    echo
    echo "========================================================================"
    echo "  Mac App Store Updates"
    echo "========================================================================"
fi

if ! command_exists mas; then
    log_warning "mas command not found. Attempting to install..."
    if retry_command "Install mas" "Installing mas" brew install mas; then
        log_success "mas installed successfully"
    else
        log_error "Failed to install mas, skipping App Store updates"
        SKIPPED_TASKS+=("Mac App Store updates")
    fi
fi

if command_exists mas; then
    if [ "$VERBOSE" = true ]; then
        log_info "Checking for Mac App Store updates..."
    fi
    if outdated=$(mas outdated 2>&1); then
        if [ -z "$outdated" ]; then
            if [ "$VERBOSE" = true ]; then
                log_info "No Mac App Store updates available"
            else
                complete_status "${GREEN}✓${NC} Mac App Store (up to date)"
            fi
            SUCCEEDED_TASKS+=("Check Mac App Store updates")
        else
            if [ "$VERBOSE" = true ]; then
                log_info "Outdated apps:"
                echo "$outdated" | sed 's/^/  /'
            fi

            # mas upgrade is notoriously flaky, so use special handling
            if [ "$VERBOSE" = true ]; then
                log_info "Attempting to upgrade Mac App Store apps..."
                log_warning "Note: mas upgrade can fail due to App Store service issues"
            fi

            # Try multiple times with longer delays
            mas_attempt=1
            mas_max_attempts=3
            mas_success=false

            while [ $mas_attempt -le $mas_max_attempts ]; do
                if [ $mas_attempt -gt 1 ]; then
                    update_status "${YELLOW}↻${NC} Upgrading App Store apps (retry $mas_attempt/$mas_max_attempts)..."
                    log_warning "mas upgrade attempt $mas_attempt of $mas_max_attempts"
                    if [ "$VERBOSE" = true ]; then
                        log_info "Waiting 10 seconds before retry..."
                    fi
                    sleep 10
                else
                    update_status "  Upgrading App Store apps..."
                fi

                if mas upgrade >/dev/null 2>&1; then
                    complete_status "${GREEN}✓${NC} Upgrading App Store apps"
                    log_success "Mac App Store apps upgraded"
                    SUCCEEDED_TASKS+=("Mac App Store upgrades")
                    mas_success=true
                    break
                else
                    mas_exit=$?
                    log_warning "mas upgrade failed (attempt $mas_attempt/$mas_max_attempts, exit code: $mas_exit)"

                    # Check if it's the PKInstallErrorDomain error
                    if [ $mas_exit -eq 1 ] && [ "$VERBOSE" = true ]; then
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
                complete_status "${RED}✗${NC} Upgrading App Store apps"
                log_error "Mac App Store upgrades failed after $mas_max_attempts attempts"
                if [ "$VERBOSE" = false ]; then
                    # Show manual steps in concise mode too since this is actionable
                    echo
                    echo -e "${YELLOW}Manual steps for App Store updates:${NC}"
                    echo "  1. Open App Store app and check for updates"
                    echo "  2. Try running 'mas upgrade' later"
                    echo
                fi
                FAILED_TASKS+=("Mac App Store upgrades")
            fi
        fi
    else
        complete_status "${RED}✗${NC} Mac App Store updates check failed"
        log_error "Failed to check for Mac App Store updates"
        FAILED_TASKS+=("Check Mac App Store updates")
    fi
fi

# --- macOS Software Update ---
if [ "$VERBOSE" = true ]; then
    echo
    echo "========================================================================"
    echo "  macOS Software Updates"
    echo "========================================================================"
    log_info "Checking for macOS software updates..."
    log_warning "This may take several minutes and might require a restart"
fi

# Software updates can take a long time, don't retry
# 10 minute timeout ensures script doesn't hang indefinitely
update_status "  Checking for macOS updates (may take several minutes)..."
if timeout 600 sudo softwareupdate --all --install --force -R >/dev/null 2>&1; then
    complete_status "${GREEN}✓${NC} macOS software updates"
    log_success "macOS software updates completed"
else
    exit_code=$?
    if [ $exit_code -eq 124 ]; then
        complete_status "${RED}✗${NC} macOS software updates (timed out after 10 minutes)"
        if [ "$VERBOSE" = true ]; then
            log_error "macOS software update timed out after 10 minutes"
            log_info "You can manually check: System Preferences > Software Update"
        fi
        FAILED_TASKS+=("macOS software updates (timeout)")
    else
        complete_status "${YELLOW}⊘${NC} macOS software updates (none available or check System Preferences)"
        if [ "$VERBOSE" = true ]; then
            log_warning "macOS software updates failed or no updates available"
            log_info "You can manually check: System Preferences > Software Update"
        fi
    fi
fi

# --- Completion ---

# Stop timer before showing summary
stop_timer

# Clear timer line and ensure cursor is at start of line
if [ "$VERBOSE" = false ]; then
    # Move to top-left, clear that line, then move cursor back to current position
    echo -ne "\033[s\033[1;1H${ERASE_LINE}\033[u"
    echo  # Blank line after last status
fi

if [ "$VERBOSE" = true ]; then
    echo
    echo "========================================================================"
    echo "  Update Summary"
    echo "========================================================================"
fi

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo
if [ "$VERBOSE" = false ]; then
    echo -e "${BOLD}Summary${NC} (${execution_time}s)"
else
    log_info "Total execution time: ${execution_time} seconds"
fi
echo

# Display summary
if [ "$VERBOSE" = true ]; then
    if [ ${#SUCCEEDED_TASKS[@]} -gt 0 ]; then
        echo -e "${GREEN}✓ Successful tasks (${#SUCCEEDED_TASKS[@]}):${NC}"
        for task in "${SUCCEEDED_TASKS[@]}"; do
            echo "  • $task"
        done
        echo
    fi
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
    if [ "$VERBOSE" = false ]; then
        echo "Run with --verbose for detailed error information"
    fi
    exit 1
else
    echo -e "${GREEN}✓${NC} All updates completed successfully!"
    exit 0
fi
