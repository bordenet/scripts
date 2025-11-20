#!/usr/bin/env bash
################################################################################
# Library: bu-lib.sh
################################################################################
# PURPOSE: Helper functions for bu.sh (macOS system update script)
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/lib/bu-lib.sh"
################################################################################

# Display help information
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
    Matt J Bordenet

SEE ALSO
    brew(1), npm(1), mas(1), pip(1), softwareupdate(8)

EOF
    exit 0
}

# Timer functions
show_timer() {
    # shellcheck disable=SC2154  # start_time is set in calling script
    local elapsed=$(($(date +%s) - start_time))
    local minutes=$((elapsed / 60))
    local seconds=$((elapsed % 60))
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local timer_text
    timer_text=$(printf "%02d:%02d" "$minutes" "$seconds")
    local timer_pos=$((cols - 6))
    echo -ne "${SAVE_CURSOR}\033[1;${timer_pos}H\033[43;30m ${timer_text} ${NC}${RESTORE_CURSOR}"
}

timer_loop() {
    while kill -0 $$ 2>/dev/null; do
        show_timer
        sleep 1
    done
}

start_timer() {
    # shellcheck disable=SC2154  # VERBOSE is set in calling script
    if [ "$VERBOSE" = false ]; then
        timer_loop &
        TIMER_PID=$!
    fi
}

stop_timer() {
    # shellcheck disable=SC2154  # TIMER_PID is set in calling script
    if [ -n "$TIMER_PID" ] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null
    fi
}

# Status update functions
update_status() {
    # shellcheck disable=SC2154  # VERBOSE and ERASE_LINE are set in calling script
    if [ "$VERBOSE" = false ]; then
        echo -ne "${ERASE_LINE}\r$*"
    fi
}

complete_status() {
    # shellcheck disable=SC2154  # VERBOSE and ERASE_LINE are set in calling script
    if [ "$VERBOSE" = false ]; then
        echo -e "${ERASE_LINE}\r$*"
    fi
}

# Logging functions
log_info() {
    # shellcheck disable=SC2154  # VERBOSE is set in calling script
    if [ "$VERBOSE" = true ]; then
        echo "[INFO] $*"
    fi
}

log_success() {
    # shellcheck disable=SC2154  # VERBOSE is set in calling script
    if [ "$VERBOSE" = true ]; then
        echo "[SUCCESS] $*"
    fi
}

log_warning() {
    # shellcheck disable=SC2154  # VERBOSE is set in calling script
    if [ "$VERBOSE" = true ]; then
        echo "[WARNING] $*"
    fi
}

log_error() {
    # shellcheck disable=SC2154  # VERBOSE is set in calling script
    if [ "$VERBOSE" = true ]; then
        echo "[ERROR] $*" >&2
    fi
}

# Utility functions
command_exists() {
    command -v "$1" &> /dev/null
}

# Execute command with retry logic
retry_command() {
    local task_name=$1
    local spinner_text=$2
    shift 2
    local attempt=1
    # shellcheck disable=SC2154  # MAX_RETRIES is set in calling script
    local max_attempts=$MAX_RETRIES

    log_info "Starting: $task_name"

    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            # shellcheck disable=SC2154  # YELLOW, NC, RETRY_DELAY are set in calling script
            update_status "${YELLOW}↻${NC} $spinner_text (retry $attempt/$max_attempts)..."
            log_warning "Retry attempt $attempt of $max_attempts for: $task_name"
            sleep $RETRY_DELAY
        else
            update_status "  $spinner_text..."
        fi

        # Execute command and capture output
        local output
        if output=$("$@" 2>&1); then
            # shellcheck disable=SC2154  # GREEN, NC, SUCCEEDED_TASKS are set in calling script
            complete_status "${GREEN}✓${NC} $spinner_text"
            log_success "$task_name completed"
            SUCCEEDED_TASKS+=("$task_name")
            return 0
        fi

        local exit_code=$?
        log_warning "$task_name failed (attempt $attempt/$max_attempts, exit code: $exit_code)"

        if [ $attempt -eq $max_attempts ]; then
            # shellcheck disable=SC2154  # RED, NC, FAILED_TASKS are set in calling script
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
safe_command() {
    local task_name=$1
    local spinner_text=$2
    shift 2

    log_info "Starting: $task_name"
    update_status "  $spinner_text..."

    local output
    if output=$("$@" 2>&1); then
        # shellcheck disable=SC2154  # GREEN, NC, SUCCEEDED_TASKS are set in calling script
        complete_status "${GREEN}✓${NC} $spinner_text"
        log_success "$task_name completed"
        SUCCEEDED_TASKS+=("$task_name")
        return 0
    else
        local exit_code=$?
        # shellcheck disable=SC2154  # RED, NC, FAILED_TASKS are set in calling script
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

