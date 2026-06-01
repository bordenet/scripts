#!/usr/bin/env bash
################################################################################
# Library: bu-lib.sh
################################################################################
# PURPOSE: Helper functions for bu.sh (macOS system update script)
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/lib/bu-lib.sh"
################################################################################

# Ensure required dependencies are available
# Checks for Homebrew and coreutils (for timeout/gtimeout)
ensure_dependencies() {
    # Check for Homebrew first - it's required for everything else
    if ! command -v brew &>/dev/null; then
        echo "Error: Homebrew is required but not installed." >&2
        echo "Install it from https://brew.sh" >&2
        exit 1
    fi

    # Check for timeout (GNU coreutils)
    # On macOS, GNU timeout is installed as 'gtimeout' by coreutils
    if ! command -v timeout &>/dev/null && ! command -v gtimeout &>/dev/null; then
        echo "Installing coreutils (required for timeout command)..."
        if ! brew install coreutils; then
            echo "Error: Failed to install coreutils" >&2
            exit 1
        fi
        echo "coreutils installed successfully"
    fi

    # If timeout doesn't exist but gtimeout does, create alias function
    if ! command -v timeout &>/dev/null && command -v gtimeout &>/dev/null; then
        # Export function so subshells can use it
        # shellcheck disable=SC2329  # invoked indirectly via 'timeout' in calling script
        timeout() { gtimeout "$@"; }
        export -f timeout
    fi
}

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
    • code (optional) - VS Code CLI for extension updates
    • cursor (optional) - Cursor CLI for extension updates

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
        kill "$TIMER_PID" 2>/dev/null || true
        wait "$TIMER_PID" 2>/dev/null || true
    fi
    TIMER_PID=""
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

# Execute command with retry logic and real-time progress
retry_command() {
    local task_name=$1
    local spinner_text=$2
    shift 2
    local attempt=1
    # shellcheck disable=SC2154  # MAX_RETRIES is set in calling script
    local max_attempts=$MAX_RETRIES

    log_info "Starting: $task_name"

    while [ "$attempt" -le "$max_attempts" ]; do
        if [ "$attempt" -gt 1 ]; then
            # shellcheck disable=SC2154  # YELLOW, NC, RETRY_DELAY are set in calling script
            update_status "${YELLOW}↻${NC} $spinner_text (retry $attempt/$max_attempts)..."
            log_warning "Retry attempt $attempt of $max_attempts for: $task_name"
            sleep "$RETRY_DELAY"
        else
            update_status "  $spinner_text..."
        fi

        # Check if this is a brew upgrade command that needs real-time progress
        local show_progress=false
        if [[ "$*" =~ ^brew\ upgrade ]]; then
            show_progress=true
        fi

        # Execute command and capture output
        local output exit_code
        if [ "$show_progress" = true ] && [ "$VERBOSE" = false ]; then
            # Stream output with real-time inline updates for brew upgrade
            local tmpfile logfile
            tmpfile=$(mktemp)
            logfile=$(mktemp)

            # Run brew upgrade in background, streaming output
            "$@" > "$tmpfile" 2>&1 &
            local brew_pid=$!

            # Monitor output and update status line in real-time
            local current_package=""
            while kill -0 $brew_pid 2>/dev/null; do
                if [ -f "$tmpfile" ]; then
                    # Look for package being upgraded
                    local latest_package
                    latest_package=$(tail -20 "$tmpfile" | grep -E "^==> (Upgrading|Installing|Downloading)" | tail -1 | sed -E 's/^==> (Upgrading|Installing|Downloading) //' | awk '{print $1}')

                    if [ -n "$latest_package" ] && [ "$latest_package" != "$current_package" ]; then
                        current_package="$latest_package"
                        # shellcheck disable=SC2154
                        update_status "  $spinner_text ${CYAN}$current_package${NC}"
                    fi
                fi
                sleep 0.5
            done

            # Wait for brew to finish and get exit code
            wait $brew_pid
            exit_code=$?
            output=$(cat "$tmpfile")

            # Clean up temp files
            cat "$tmpfile" > "$logfile"
            rm -f "$tmpfile"

            # Parse output to show final summary
            if [ $exit_code -eq 0 ]; then
                local upgrade_count
                upgrade_count=$(echo "$output" | grep -cE "^==> (Upgrading|Installing)" || true)
                if [ "$upgrade_count" -gt 0 ]; then
                    # shellcheck disable=SC2154
                    complete_status "${GREEN}✓${NC} $spinner_text ($upgrade_count packages)"
                else
                    # shellcheck disable=SC2154
                    complete_status "${GREEN}✓${NC} $spinner_text (up to date)"
                fi
                log_success "$task_name completed"
                SUCCEEDED_TASKS+=("$task_name")
                rm -f "$logfile"
                return 0
            else
                rm -f "$logfile"
            fi
        else
            # Original behavior for non-brew commands
            if output=$("$@" 2>&1); then
                # shellcheck disable=SC2154  # GREEN, NC, SUCCEEDED_TASKS are set in calling script
                complete_status "${GREEN}✓${NC} $spinner_text"
                log_success "$task_name completed"
                SUCCEEDED_TASKS+=("$task_name")
                return 0
            else
                exit_code=$?
            fi
        fi

        log_warning "$task_name failed (attempt $attempt/$max_attempts, exit code: $exit_code)"

        if [ "$attempt" -eq "$max_attempts" ]; then
            # shellcheck disable=SC2154  # RED, NC, FAILED_TASKS are set in calling script
            complete_status "${RED}✗${NC} $spinner_text"
            log_error "$task_name failed after $max_attempts attempts"
            if [ "$VERBOSE" = true ]; then
                log_error "Last error output:"
                # shellcheck disable=SC2001  # no clean bash substitute for multiline indent
                echo "$output" | sed 's/^/  /' >&2
            fi
            FAILED_TASKS+=("$task_name")
            return 1
        fi

        ((attempt++))
    done
}

# Shared helper: update extensions for any VS Code-compatible editor.
# Cross-platform: works on macOS and Linux wherever the CLI is in PATH.
# Usage: _update_editor_extensions "VS Code" "code"
_update_editor_extensions() {
    local display_name=$1
    local cli=$2
    local task_name="${display_name} extension updates"

    if ! command_exists "$cli"; then
        log_warning "${display_name} CLI (${cli}) not found, skipping extension updates"
        SKIPPED_TASKS+=("$task_name")
        return 0
    fi

    log_info "Updating ${display_name} extensions..."
    update_status "  Updating ${display_name} extensions..."

    local output
    if output=$("$cli" --update-extensions 2>&1); then
        # shellcheck disable=SC2154  # GREEN, NC, SUCCEEDED_TASKS are set in calling script
        complete_status "${GREEN}✓${NC} Updating ${display_name} extensions"
        log_success "${display_name} extensions updated"
        SUCCEEDED_TASKS+=("$task_name")
        return 0
    else
        local exit_code=$?
        # shellcheck disable=SC2154  # RED, NC, FAILED_TASKS are set in calling script
        complete_status "${RED}✗${NC} Updating ${display_name} extensions"
        log_error "${display_name} extension update failed (exit code: $exit_code)"
        if [ "$VERBOSE" = true ] && [ -n "$output" ]; then
            log_error "Error output:"
            # shellcheck disable=SC2001  # no clean bash substitute for multiline indent
            echo "$output" | sed 's/^/  /' >&2
        fi
        FAILED_TASKS+=("$task_name")
        return 1
    fi
}

update_vscode_extensions()  { _update_editor_extensions "VS Code" "code";   }
update_cursor_extensions()  { _update_editor_extensions "Cursor"  "cursor";  }

# Upgrade all outdated brew packages, escalating strategies until nothing remains
# or every avenue is exhausted. Stages:
#   1. brew upgrade — standard batch
#   2. brew update + brew upgrade — catches mid-run releases
#   3. per-package brew upgrade — isolates stuck items, with timeout + stderr capture
#
# Bookkeeping invariant: exactly ONE entry per logical task in the summary arrays.
# Pinned formulae go to SKIPPED_TASKS, never to FAILED_TASKS. brew query failures
# (vs "nothing outdated") are surfaced distinctly.
brew_upgrade_with_escalation() {
    local task_name="Homebrew package upgrades"
    local remaining query_err

    # Stage 1 — standard upgrade. We do bookkeeping at the function level
    # (one entry per logical task), so we don't route through retry_command,
    # which would push its own per-attempt entries and create duplicates
    # whenever stages 2/3 recover.
    log_info "Stage 1: brew upgrade"
    update_status "  Upgrading Homebrew packages..."
    local s1_out
    s1_out=$(brew upgrade 2>&1) || true

    if ! remaining=$(brew outdated -q 2>&1); then
        query_err=$remaining
        complete_status "${RED}✗${NC} Upgrading Homebrew packages"
        log_error "brew outdated query failed: $query_err"
        FAILED_TASKS+=("${task_name} (brew outdated query failed)")
        return 1
    fi

    if [ -z "$remaining" ]; then
        local upgrade_count
        upgrade_count=$(grep -cE "^==> (Upgrading|Installing)" <<< "$s1_out" || true)
        if [ "$upgrade_count" -gt 0 ]; then
            complete_status "${GREEN}✓${NC} Upgrading Homebrew packages ($upgrade_count packages)"
        else
            complete_status "${GREEN}✓${NC} Upgrading Homebrew packages (up to date)"
        fi
        log_success "$task_name completed"
        SUCCEEDED_TASKS+=("$task_name")
        return 0
    fi

    # Stage 2 — refresh catalog and retry. Handles versions released between
    # the script's initial `brew update` and this point.
    local count
    count=$(grep -c . <<< "$remaining")
    log_warning "Stage 1 left $count package(s) outdated; refreshing catalog"
    update_status "  Refreshing brew catalog (stage 2, $count remaining)..."

    local update_out
    if ! update_out=$(brew update 2>&1); then
        # `brew update` failed (network, auth, corrupt tap). Continue escalation
        # with stale catalog — Stage 3 may still salvage individual packages.
        log_warning "brew update failed in stage 2 (continuing with stale catalog)"
        if [ "$VERBOSE" = true ]; then
            printf '%s\n' "$update_out" | tail -3 | sed 's/^/    /' >&2
        fi
    fi

    update_status "  Upgrading Homebrew packages (stage 2, $count remaining)..."
    # Capture stage 2 output for diagnostics (mirrors stages 1 and 3).
    local s2_out
    s2_out=$(brew upgrade 2>&1) || true

    if ! remaining=$(brew outdated -q 2>&1); then
        query_err=$remaining
        complete_status "${RED}✗${NC} Upgrading Homebrew packages"
        log_error "brew outdated query failed after stage 2: $query_err"
        if [ "$VERBOSE" = true ] && [ -n "$s2_out" ]; then
            printf '%s\n' "$s2_out" | tail -5 | sed 's/^/    /' >&2
        fi
        FAILED_TASKS+=("${task_name} (brew outdated query failed)")
        return 1
    fi

    if [ -z "$remaining" ]; then
        complete_status "${GREEN}✓${NC} Upgrading Homebrew packages (stage 2 recovered)"
        log_success "$task_name completed via stage 2"
        SUCCEEDED_TASKS+=("$task_name")
        return 0
    fi

    # Stage 3 — per-package upgrade with progress, stderr capture, and timeout.
    # `timeout 300` prevents a single wedged bottle from hanging the whole script.
    count=$(grep -c . <<< "$remaining")
    log_warning "Stage 2 left $count package(s) outdated; per-package retry"

    # Pinned formulae are intentionally held back — route them to SKIPPED, not FAILED.
    local pinned
    pinned=$(brew list --pinned 2>/dev/null || true)

    local i=0
    local failures=()
    local skipped_pinned=()
    local pkg
    while IFS= read -r pkg; do
        [ -z "$pkg" ] && continue
        i=$((i + 1))

        if [ -n "$pinned" ] && grep -qxF "$pkg" <<< "$pinned"; then
            log_info "Skipping pinned package: $pkg"
            skipped_pinned+=("$pkg")
            continue
        fi

        update_status "  Stage 3: $i/$count ${CYAN}$pkg${NC}..."
        log_info "Attempting individual upgrade: $pkg"

        # Initialize pkg_rc defensively: if the substitution is interrupted
        # by a signal before either branch runs, `set -u` would otherwise trip.
        local pkg_out=""
        local pkg_rc=0
        pkg_out=$(timeout 300 brew upgrade "$pkg" 2>&1) || pkg_rc=$?
        if [ "$pkg_rc" -ne 0 ]; then
            local reason
            if [ "$pkg_rc" -eq 124 ]; then
                reason="timed out after 300s"
            else
                # First Error: line is usually the actionable cause; fall back to last line
                reason=$(grep -m1 -E "^Error:" <<< "$pkg_out" | sed 's/^Error: *//' | head -c 200)
                [ -z "$reason" ] && reason=$(printf '%s\n' "$pkg_out" | tail -n1 | head -c 200)
                [ -z "$reason" ] && reason="exit code $pkg_rc"
            fi
            log_warning "Individual upgrade failed: $pkg ($reason)"
            if [ "$VERBOSE" = true ] && [ -n "$pkg_out" ]; then
                printf '%s\n' "$pkg_out" | tail -10 | sed 's/^/      /' >&2
            fi
            failures+=("$pkg: $reason")
        fi
    done <<< "$remaining"

    if [ "${#skipped_pinned[@]}" -gt 0 ]; then
        SKIPPED_TASKS+=("Pinned packages (intentionally held): ${skipped_pinned[*]}")
    fi

    # Final outdated check, with pinned filtered out
    if ! remaining=$(brew outdated -q 2>&1); then
        query_err=$remaining
        complete_status "${RED}✗${NC} Upgrading Homebrew packages"
        log_error "brew outdated query failed after stage 3: $query_err"
        FAILED_TASKS+=("${task_name} (brew outdated query failed)")
        return 1
    fi

    local stuck_count=0
    if [ -n "$remaining" ]; then
        while IFS= read -r pkg; do
            [ -z "$pkg" ] && continue
            if [ -n "$pinned" ] && grep -qxF "$pkg" <<< "$pinned"; then
                continue
            fi
            stuck_count=$((stuck_count + 1))
        done <<< "$remaining"
    fi

    if [ "$stuck_count" -eq 0 ]; then
        complete_status "${GREEN}✓${NC} Upgrading Homebrew packages (stage 3 recovered)"
        log_success "$task_name completed via stage 3"
        SUCCEEDED_TASKS+=("$task_name")
        return 0
    fi

    complete_status "${RED}✗${NC} Upgrading Homebrew packages ($stuck_count stuck)"
    if [ "${#failures[@]}" -gt 0 ]; then
        local f
        for f in "${failures[@]}"; do
            FAILED_TASKS+=("brew upgrade $f")
        done
    else
        FAILED_TASKS+=("${task_name} (still outdated after stage 3)")
    fi
    return 1
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
            # shellcheck disable=SC2001  # no clean bash substitute for multiline indent
            echo "$output" | sed 's/^/  /' >&2
        fi
        FAILED_TASKS+=("$task_name")
        return 1
    fi
}
