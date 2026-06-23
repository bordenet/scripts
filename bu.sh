#!/usr/bin/env bash
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }
# -----------------------------------------------------------------------------
# Script Name: bu.sh
# Description: Comprehensive macOS system update and cleanup
# Platform: macOS only
# Usage: ./bu.sh [-v|--verbose]
# -----------------------------------------------------------------------------

# Do NOT exit on error - we want to continue through failures
set -u  # Exit on undefined variables
set -o pipefail  # Catch errors in pipes

# Source library functions
# Resolve symlinks to get actual script location
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
# shellcheck source=lib/bu-lib.sh
source "$SCRIPT_DIR/lib/bu-lib.sh"
ensure_dependencies  # Check/install coreutils for timeout command

# Suppress Homebrew env hints (tap trust warnings, etc.) — they leak to the
# terminal via /dev/tty and corrupt the status-line display.
export HOMEBREW_NO_ENV_HINTS=1
# Keep existing taps allowed by default (current behaviour, no behavioural change).
export HOMEBREW_NO_REQUIRE_TAP_TRUST=1

# --- Colors for Output (exported for library use) ---
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export BOLD='\033[1m'
export NC='\033[0m' # No Color

# --- Global Variables (exported for library use) ---
export FAILED_TASKS=()
export SUCCEEDED_TASKS=()
export SKIPPED_TASKS=()
export MAX_RETRIES=3
export RETRY_DELAY=5
export VERBOSE=false

# ANSI cursor control (exported for library use)
export ERASE_LINE='\033[2K'
export SAVE_CURSOR='\033[s'
export RESTORE_CURSOR='\033[u'
export TIMER_PID=""

# --- Helper Functions ---
# Helper functions now in lib/bu-lib.sh

# Parse arguments
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) show_help ;;
        -v|--verbose) VERBOSE=true; shift ;;
        *) echo "Unknown option: $1" >&2; echo "Use -h or --help for usage information" >&2; exit 1 ;;
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
# Store main script PID so background loop can check if parent is still alive
MAIN_PID=$$
while true; do sudo -n true; sleep 60; kill -0 "$MAIN_PID" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!

if [ "$VERBOSE" = false ]; then
    # Clear the screen for clean output
    clear
    echo -e "${BOLD}System Update & Cleanup${NC}\n"
    start_timer
fi

# Ensure timer, sudo keepalive, and any background editor jobs are reaped on exit.
# Brace-wrapped with `|| true` so a failure in one cleanup step doesn't
# skip the next (set -u makes naive trap chaining fragile).
trap '{ cleanup_editor_jobs || true; stop_timer || true; [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true; }' EXIT

# --- Background editor extension updates ---
# Kick off VS Code and Cursor extension updates now so they run concurrently
# with brew / npm / mas / softwareupdate. Results are reaped pre-summary.
start_background_editor_updates

# --- Homebrew Updates ---
if [ "$VERBOSE" = true ]; then
    echo
    echo "========================================================================"
    echo "  Homebrew Updates"
    echo "========================================================================"
fi

retry_command "Homebrew update" "Updating Homebrew" brew update

# Upgrade with escalation: standard → refresh+retry → per-package.
# In Homebrew 5.x, `brew upgrade` handles both formulae and casks, so no
# separate --cask pass is needed. The escalation handles mid-run releases
# and isolates any stuck packages instead of giving up on the first miss.
brew_upgrade_with_escalation

safe_command "Homebrew cleanup" "Cleaning up Homebrew" brew cleanup -s

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
            # shellcheck disable=SC2001  # no clean bash substitute for multiline indent
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

# (VS Code + Cursor extension updates were launched in the background after
# sudo+timer setup; reaped pre-summary below.)

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
                # shellcheck disable=SC2001  # no clean bash substitute for multiline indent
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

# Check available updates first (fast); skip install when nothing is pending.
# softwareupdate --all --install --force hangs indefinitely when no updates are
# available, turning a no-op run into a guaranteed 10-minute timeout.
update_status "  Checking for macOS updates..."
available=$(timeout 60 sudo softwareupdate -l 2>&1)
list_exit=$?
if [ "$list_exit" -eq 124 ]; then
    complete_status "${YELLOW}⊘${NC} macOS software updates (list check timed out)"
    SKIPPED_TASKS+=("macOS software updates (list timed out)")
elif [ "$list_exit" -ne 0 ]; then
    complete_status "${YELLOW}⊘${NC} macOS software updates (could not list — check System Preferences)"
    SKIPPED_TASKS+=("macOS software updates")
elif echo "$available" | grep -qi "no new software available"; then
    complete_status "${GREEN}✓${NC} macOS software updates (up to date)"
    SUCCEEDED_TASKS+=("macOS software updates")
else
    # Updates listed — install them; failure here is actionable (we know updates exist)
    update_status "  Installing macOS updates (may take several minutes)..."
    # Note: -R (restart) flag removed — OS restarts should require explicit user action
    if timeout 600 sudo softwareupdate --all --install --force >/dev/null 2>&1; then
        complete_status "${GREEN}✓${NC} macOS software updates"
        log_success "macOS software updates completed"
        SUCCEEDED_TASKS+=("macOS software updates")
    else
        install_exit=$?
        if [ "$install_exit" -eq 124 ]; then
            complete_status "${RED}✗${NC} macOS software updates (install timed out after 10 minutes)"
            if [ "$VERBOSE" = true ]; then
                log_error "macOS software update install timed out — updates are available but were not applied"
                log_info "You can manually check: System Preferences > Software Update"
            fi
            FAILED_TASKS+=("macOS software updates (install timed out)")
        else
            complete_status "${RED}✗${NC} macOS software updates (install failed — check System Preferences)"
            if [ "$VERBOSE" = true ]; then
                log_error "macOS software update install failed (exit $install_exit)"
                log_info "You can manually check: System Preferences > Software Update"
            fi
            FAILED_TASKS+=("macOS software updates (install failed)")
        fi
    fi
fi

# --- Reap background editor extension updates ---
# By this point brew / npm / mas / softwareupdate have finished. Wait reaps
# the editor jobs (usually already done) and records results in the summary.
wait_background_editor_updates

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

if [ "$VERBOSE" = false ]; then
    echo -e "${BOLD}Summary${NC} (${execution_time}s)"
else
    log_info "Total execution time: ${execution_time} seconds"
fi

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
