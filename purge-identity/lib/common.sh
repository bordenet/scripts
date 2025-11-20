#!/usr/bin/env bash
################################################################################
# Script Name: lib/common.sh
################################################################################
# PURPOSE: Common functions for purge-identity tool
# USAGE: Source this file from main script
# PLATFORM: macOS
################################################################################

# This library provides:
# - Logging functions
# - Timer display
# - Cleanup handlers
# - Display/UI functions
# - Safety functions
# - Discovery helpers

# Source all library modules
PURGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=purge-identity/lib/utils.sh
source "$PURGE_LIB_DIR/utils.sh"
# shellcheck source=purge-identity/lib/helpers.sh
source "$PURGE_LIB_DIR/helpers.sh"
# shellcheck source=purge-identity/lib/help.sh
source "$PURGE_LIB_DIR/help.sh"
# shellcheck source=purge-identity/lib/scanners-browsers.sh
source "$PURGE_LIB_DIR/scanners-browsers.sh"
# shellcheck source=purge-identity/lib/scanners-system.sh
source "$PURGE_LIB_DIR/scanners-system.sh"
# shellcheck source=purge-identity/lib/deleters-keychain.sh
source "$PURGE_LIB_DIR/deleters-keychain.sh"
# shellcheck source=purge-identity/lib/deleters-apps.sh
source "$PURGE_LIB_DIR/deleters-apps.sh"
# shellcheck source=purge-identity/lib/ui.sh
source "$PURGE_LIB_DIR/ui.sh"
# shellcheck source=purge-identity/lib/processing.sh
source "$PURGE_LIB_DIR/processing.sh"

# -----------------------------------------------------------------------------
# ANSI color codes (must be set by parent script before sourcing)
# These are declared as globals in the main script
# -----------------------------------------------------------------------------

# Expected globals from parent:
# RED, GREEN, YELLOW, CYAN, NC, BOLD
# SAVE_CURSOR, RESTORE_CURSOR, MOVE_TO_TOP_RIGHT
# LOG_DIR, LOG_FILE, START_TIME, TIMER_PID
# ERROR_MESSAGES, ERROR_REMEDIATION
# DISCOVERED_IDENTITIES, IDENTITY_LOCATIONS
# EMAIL_PATTERN, PRESERVED_PATTERNS

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------

# Initialize logging system
init_logging() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S) || {
        echo "ERROR: Failed to get timestamp" >&2
        exit 1
    }
    LOG_FILE="${LOG_DIR}/purge-identity-${timestamp}.log"

    # Create log file
    touch "$LOG_FILE" || {
        echo "ERROR: Failed to create log file: $LOG_FILE" >&2
        exit 1
    }

    log "INFO" "Purge Identity Tool v${VERSION} started"
    log "INFO" "Command: $0 $*"
    log "INFO" "Platform: $(uname -s) $(uname -r)"
    log "INFO" "User: $(whoami)"

    # Cleanup old logs (>24 hours)
    find "$LOG_DIR" -name "purge-identity-*.log" -mtime +1 -delete 2>/dev/null || true

    # Set up trap for cleanup on exit
    trap 'cleanup_on_exit' EXIT INT TERM
}

# Log message to file and optionally to console
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE" 2>/dev/null || true

    # Also echo to console if verbose mode
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo "[${level}] ${message}"
    fi
}

# Log and display error
log_error() {
    local message="$1"
    log "ERROR" "$message"
    echo -e "${RED}✗${NC} $message" >&2
}

# Log and display success
log_success() {
    local message="$1"
    log "INFO" "$message"
    echo -e "${GREEN}✓${NC} $message"
}

# Log and display info
log_info() {
    local message="$1"
    log "INFO" "$message"
    echo "$message"
}

# -----------------------------------------------------------------------------
# Timer Functions
# -----------------------------------------------------------------------------

# Start background timer display
start_timer() {
    START_TIME=$(date +%s)

    # Background timer update process
    (
        while true; do
            update_timer_display
            sleep 5
        done
    ) &

    TIMER_PID=$!
    log "DEBUG" "Timer started (PID: $TIMER_PID)"
}

# Update timer display in top-right corner
update_timer_display() {
    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))

    # Only display if we're in an interactive terminal
    if [[ -t 1 ]]; then
        printf "${SAVE_CURSOR}${MOVE_TO_TOP_RIGHT}${YELLOW}[%02d:%02d:%02d]${NC}${RESTORE_CURSOR}" \
            "$hours" "$minutes" "$seconds"
    fi
}

# Stop timer
stop_timer() {
    if [[ -n "$TIMER_PID" ]] && ps -p "$TIMER_PID" > /dev/null 2>&1; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null || true
        log "DEBUG" "Timer stopped"
    fi
}

# Get formatted elapsed time
get_elapsed_time() {
    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
}

# -----------------------------------------------------------------------------
# Cleanup and Exit
# -----------------------------------------------------------------------------

cleanup_on_exit() {
    stop_timer
    log "INFO" "Script exiting (elapsed: $(get_elapsed_time))"
}

# -----------------------------------------------------------------------------
# Display Functions
# -----------------------------------------------------------------------------

# Display script header
display_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║            macOS Identity Purge Tool v${VERSION}               ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo

    if [[ "$WHAT_IF_MODE" == true ]]; then
        echo -e "${YELLOW}Running in WHAT-IF mode (dry-run - no deletions will occur)${NC}"
        echo
    fi
}

# Display section header
display_section_header() {
    local title="$1"
    echo
    echo -e "${CYAN}▶ ${title}${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..60})${NC}"
}

# Display help documentation
# show_help function now in purge-identity/lib/help.sh

# -----------------------------------------------------------------------------
# Safety Functions
# -----------------------------------------------------------------------------

# Check if a file should be preserved (never deleted)
is_preserved_file() {
    local filepath="$1"

    # Check against preserved patterns
    for pattern in "${PRESERVED_PATTERNS[@]}"; do
        case "$filepath" in
            *$pattern*)
                log "DEBUG" "Preserved file detected: $filepath (matched: $pattern)"
                return 0  # File is preserved
                ;;
        esac
    done

    # Additional safety checks
    # Preserve files in cloud storage directories
    if [[ "$filepath" =~ /CloudStorage/ ]]; then
        log "DEBUG" "Preserved file in CloudStorage: $filepath"
        return 0
    fi

    return 1  # File is not preserved
}

# Add error to collection
add_error() {
    local message="$1"
    local remediation="$2"

    ERROR_MESSAGES+=("$message")
    ERROR_REMEDIATION+=("$remediation")

    log "ERROR" "$message"
    log "ERROR" "Remediation: $remediation"
}

# Check if sudo is required and request if needed
require_sudo() {
    local reason="$1"

    # Check if we already have sudo cached
    if sudo -n true 2>/dev/null; then
        return 0
    fi

    # Request sudo with clear messaging
    echo -e "${YELLOW}Requesting elevated privileges for ${reason}...${NC}"
    if sudo -v; then
        log "INFO" "Sudo granted for: $reason"
        return 0
    else
        log "ERROR" "Sudo denied for: $reason"
        return 1
    fi
}

# Check if an app is running
is_app_running() {
    local app_name="$1"
    pgrep -x "$app_name" > /dev/null 2>&1
}

# Prompt to quit an application
prompt_quit_app() {
    local app_name="$1"

    if ! is_app_running "$app_name"; then
        return 0  # App not running
    fi

    echo
    echo -e "${YELLOW}⚠ ${app_name} is currently running.${NC}"
    echo "  Browser databases are locked while the app is open."
    echo

    read -p "Quit ${app_name} now? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "User chose to quit $app_name"

        # Try to quit gracefully
        osascript -e "tell application \"$app_name\" to quit" 2>/dev/null || true

        # Wait up to 10 seconds for app to quit
        local count=0
        while is_app_running "$app_name" && [[ $count -lt 20 ]]; do
            sleep 0.5
            ((count++))
        done

        if is_app_running "$app_name"; then
            log_error "${app_name} did not quit. Please quit manually and re-run."
            return 1
        else
            log_success "${app_name} quit successfully"
            return 0
        fi
    else
        log "INFO" "User chose not to quit $app_name"
        return 1
    fi
}

# Confirm a potentially dangerous deletion
confirm_deletion() {
    local description="$1"

    echo
    echo -e "${YELLOW}⚠ WARNING:${NC} About to delete: ${description}"
    echo -e "${YELLOW}  This operation is PERMANENT and cannot be undone.${NC}"
    echo

    read -p "Continue with deletion? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "User confirmed deletion: $description"
        return 0
    else
        log "INFO" "User cancelled deletion: $description"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Discovery Helper Functions
# -----------------------------------------------------------------------------

# Add a discovered identity to the global arrays
add_discovered_identity() {
    local email="$1"
    local location="$2"

    # Skip empty emails
    [[ -z "$email" ]] && return

    # If TARGET_EMAIL is set, only process that specific email
    if [[ -n "$TARGET_EMAIL" ]] && [[ "$email" != "$TARGET_EMAIL" ]]; then
        return
    fi

    # Validate email format (basic sanitation - prevent command injection)
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log "WARN" "Invalid email format detected, skipping: $email"
        return
    fi

    # Sanitize email (remove any shell metacharacters just in case)
    email="${email//[;<>\`\$\(\)]/}"

    # Increment total count
    if [[ -n "${DISCOVERED_IDENTITIES[$email]}" ]]; then
        DISCOVERED_IDENTITIES[$email]=$((DISCOVERED_IDENTITIES[$email] + 1))
    else
        DISCOVERED_IDENTITIES[$email]=1
    fi

    # Append location
    if [[ -n "${IDENTITY_LOCATIONS[$email]}" ]]; then
        IDENTITY_LOCATIONS[$email]="${IDENTITY_LOCATIONS[$email]},$location"
    else
        IDENTITY_LOCATIONS[$email]="$location"
    fi

    log "DEBUG" "Found $email in $location"
}
