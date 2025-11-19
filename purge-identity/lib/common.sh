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
show_help() {
    cat << 'EOF'
NAME
    purge-identity.sh - Comprehensive macOS identity purge tool

SYNOPSIS
    purge-identity.sh EMAIL [OPTIONS]

DESCRIPTION
    Permanently removes all traces of a SPECIFIED email identity from macOS.
    You must explicitly provide the email address to purge - there is no
    auto-discovery menu to prevent accidental deletions.

    Targets authentication credentials, cached data, and configuration
    references while preserving actual user data files.

    The tool provides comprehensive discovery across:
      • Keychain (passwords, certificates, keys)
      • Browsers (Safari, Chrome, Edge, Firefox)
      • Mail.app (accounts and mailboxes)
      • Application Support (app-specific credentials)
      • SSH (keys and configuration)
      • Internet Accounts (system-level accounts)
      • Cloud storage (OneDrive, Google Drive configs)

    SAFETY FEATURES:
      • What-if mode for safe preview before execution
      • Multiple confirmation stages before deletion
      • Explicit warnings for one-way door operations
      • Comprehensive logging of all operations
      • Preserves .psafe3, .git, and user data files

ARGUMENTS
    EMAIL
        The email address to purge. This is REQUIRED - the script will not
        run without an explicitly specified email address.

OPTIONS
    --what-if
        Dry-run mode. Discover where the email exists and show what would
        be deleted without actually deleting anything.

    --verbose
        Enable verbose debug logging to console. All operations are always
        logged to /tmp/purge-identity-YYYYMMDD-HHMMSS.log regardless.

    -h, --help
        Display this help message and exit.

WORKFLOW
    1. Email Validation
       - Validates the provided email format
       - Ensures explicit user intent

    2. Discovery Phase
       - Scans system for the specified email only
       - Reports all locations where found

    3. Preview & Confirmation
       - Detailed preview of what will be deleted
       - Explicit confirmation required
       - Warnings for risky operations (data loss, system impact)

    4. Deletion & Exit Report
       - Performs deletions only after confirmation
       - Summary of all operations performed
       - Comprehensive error listing with remediation steps
       - Log file location for detailed review

EXAMPLES
    # Safe preview: see where an email exists without deleting
    ./purge-identity.sh user@oldcompany.com --what-if

    # Delete all traces of a specific email
    ./purge-identity.sh user@oldcompany.com

    # Verbose mode for debugging
    ./purge-identity.sh user@oldcompany.com --verbose

WARNINGS
    This tool performs PERMANENT DELETIONS. Deleted data cannot be recovered.

    Specifically:
      • Mail.app mailboxes are DELETED (not archived)
      • Browser profiles are DELETED (bookmarks, history, all settings)
      • SSH keys are DELETED (ensure keys not needed elsewhere)
      • Keychain entries are DELETED (passwords unrecoverable)

    ALWAYS run --what-if mode first to verify operations before committing.

    The tool preserves:
      • .psafe3 files (Password Safe databases)
      • .git directories (repository history)
      • User data files in cloud storage directories
      • Application data files (only configs/credentials deleted)

PLATFORM
    macOS only - Script will exit with error on other platforms

DEPENDENCIES
    • macOS security framework (built-in)
    • jq (JSON parsing) - install via: brew install jq
    • sqlite3 (built-in on macOS)

EXIT CODES
    0    Success
    1    Error occurred (check log file for details)
    2    User cancelled operation

LOGGING
    All operations are logged to:
      /tmp/purge-identity-YYYYMMDD-HHMMSS.log

    Logs are automatically cleaned up after 24 hours.

EXAMPLES OF IDENTITIES
    • Former employer accounts (user@oldcompany.com)
    • Deleted service accounts (user@deletedservice.com)
    • Deprecated personal emails (old.email@provider.com)

AUTHOR
    Matt J Bordenet

SEE ALSO
    security(1), sqlite3(1), jq(1)

EOF
    exit 0
}

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
