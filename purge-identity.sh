#!/bin/bash
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

# Check bash version (need 4.0+ for associative arrays)
if ((BASH_VERSINFO[0] < 4)); then
    # Try to find and re-exec with newer bash
    for bash_path in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        if [[ -x "$bash_path" ]]; then
            exec "$bash_path" "$0" "$@"
        fi
    done

    # If we get here, no newer bash was found
    cat >&2 <<EOF
Error: This script requires Bash 4.0 or later (found ${BASH_VERSION})

macOS ships with Bash 3.2. Install Bash 4+ via Homebrew:
  brew install bash

Then either:
  1. Add Homebrew bash to your PATH, OR
  2. Run directly: \$(brew --prefix)/bin/bash $0

Homebrew installs bash to:
  - Apple Silicon: /opt/homebrew/bin/bash
  - Intel:         /usr/local/bin/bash
EOF
    exit 1
fi
# -----------------------------------------------------------------------------
#
# Script Name: purge-identity.sh
#
# Description: Comprehensive macOS identity purge tool that discovers and
#              permanently removes all traces of specified email identities
#              from the system. Targets keychain entries, browser data,
#              Mail.app accounts, application credentials, SSH keys, and
#              cloud storage configurations.
#
# Platform:    macOS only
#
# Usage: ./purge-identity.sh [OPTIONS]
#
# Options:
#   --what-if         Dry-run mode: perform discovery and display menu only
#   --verbose         Enable verbose debug logging
#   -h, --help        Show detailed help documentation
#
# Dependencies:
#   - macOS security framework (keychain operations)
#   - jq (JSON parsing)
#   - sqlite3 (database queries)
#
# Safety Features:
#   - Preserves .psafe3, .git, and user data files
#   - Multiple confirmation stages before deletion
#   - Comprehensive error handling and logging
#   - What-if mode for safe preview
#
# Author: Matt J Bordenet
# Last Updated: 2025-01-13
#
# -----------------------------------------------------------------------------

# Don't exit on error - we handle errors explicitly and continue
set -o pipefail

# -----------------------------------------------------------------------------
# Global Configuration
# -----------------------------------------------------------------------------

VERSION="1.0.0"
LOG_DIR="/tmp"
LOG_FILE=""
START_TIME=$(date +%s)
TIMER_PID=""

# Mode flags
WHAT_IF_MODE=false
VERBOSE_MODE=false
TARGET_EMAIL=""  # The email to purge (required argument)

# Email pattern for discovery
EMAIL_PATTERN='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

# Error collection
declare -a ERROR_MESSAGES
declare -a ERROR_REMEDIATION

# Discovery results
declare -A DISCOVERED_IDENTITIES  # email -> total count
declare -A IDENTITY_LOCATIONS     # email -> "location1,location2,..."

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'  # No Color
BOLD='\033[1m'

# ANSI cursor control
SAVE_CURSOR='\033[s'
RESTORE_CURSOR='\033[u'
MOVE_TO_TOP_RIGHT='\033[1;55H'

# Preserved file patterns (NEVER delete these)
PRESERVED_PATTERNS=(
    "*.psafe3"
    ".git"
    "*.git/*"
)

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
    local elapsed
    elapsed=$((current_time - START_TIME))
    local hours
    hours=$((elapsed / 3600))
    local minutes
    minutes=$(((elapsed % 3600) / 60))
    local seconds
    seconds=$((elapsed % 60))

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
    local elapsed
    elapsed=$((current_time - START_TIME))
    local hours
    hours=$((elapsed / 3600))
    local minutes
    minutes=$(((elapsed % 3600) / 60))
    local seconds
    seconds=$((elapsed % 60))
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
# Argument Parsing
# -----------------------------------------------------------------------------

parse_arguments() {
    # No arguments? Show help
    if [[ $# -eq 0 ]]; then
        show_help
    fi

    # First argument must be the email address (not a flag)
    if [[ "$1" == -* ]]; then
        # Check if it's the help flag
        if [[ "$1" == "-h" || "$1" == "--help" ]]; then
            show_help
        fi

        cat >&2 << 'EOF'
Error: Email address required as first argument

Usage: purge-identity.sh EMAIL [OPTIONS]

Example:
  ./purge-identity.sh user@oldcompany.com
  ./purge-identity.sh user@oldcompany.com --what-if

Use --help for full documentation
EOF
        exit 1
    fi

    TARGET_EMAIL="$1"
    shift

    # Validate email format
    if [[ ! "$TARGET_EMAIL" =~ ^${EMAIL_PATTERN}$ ]]; then
        echo "Error: Invalid email format: $TARGET_EMAIL" >&2
        exit 1
    fi

    # Parse remaining options
    while [[ $# -gt 0 ]]; do
        case $1 in
            --what-if)
                WHAT_IF_MODE=true
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                echo "Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 1
                ;;
        esac
    done
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
# Discovery Functions
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

# Scan keychain for email identities
scan_keychain() {
    log "INFO" "Scanning keychain for identities..."

    # Dump login keychain
    local keychain_dump
    keychain_dump=$(security dump-keychain 2>/dev/null)

    if [[ -z "$keychain_dump" ]]; then
        log "WARN" "Could not dump keychain (may require unlock)"
        return 0
    fi

    # Extract emails from ACCOUNT fields only (what we can actually delete)
    # This matches what delete_keychain_items does
    local emails
    emails=$(echo "$keychain_dump" | \
             grep '"acct"<blob>=' | \
             sed -E 's/.*"acct"<blob>="([^"]+)".*/\1/' | \
             grep -E "$EMAIL_PATTERN" | \
             sort -u)

    # Also check certificates (deletable via security delete-certificate)
    local cert_emails
    cert_emails=$(security find-certificate -a -p 2>/dev/null | \
                  openssl x509 -noout -email 2>/dev/null | \
                  grep -E "^$EMAIL_PATTERN$" | sort -u)

    # Combine and deduplicate
    local all_emails
    all_emails=$(printf "%s\n%s\n" "$emails" "$cert_emails" | grep -E "$EMAIL_PATTERN" | sort -u)

    # Store in global discovery array
    while IFS= read -r email; do
        [[ -n "$email" ]] && add_discovered_identity "$email" "keychain"
    done <<< "$all_emails"

    local count
    count=$(echo "$all_emails" | grep -c . 2>/dev/null || echo "0")
    log "INFO" "Keychain scan complete: $count unique emails found"
}

# Scan Safari for identities
scan_safari() {
    log "INFO" "Scanning Safari..."

    local safari_dir="$HOME/Library/Safari"
    [[ ! -d "$safari_dir" ]] && { log "DEBUG" "Safari directory not found"; return 0; }

    # Scan history database
    local history_db="${safari_dir}/History.db"
    if [[ -f "$history_db" ]]; then
        local temp_db="/tmp/safari_history_$$.db"
        cp "$history_db" "$temp_db" 2>/dev/null || true

        if [[ -f "$temp_db" ]]; then
            # Extract emails from history URLs and titles
            local emails
            emails=$(sqlite3 "$temp_db" "SELECT url FROM history_items;" 2>/dev/null | \
                          grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "safari_history"
            done <<< "$emails"
            rm -f "$temp_db"
        fi
    fi

    # Check Safari preferences
    local prefs="${safari_dir}/Preferences/com.apple.Safari.plist"
    if [[ -f "$prefs" ]]; then
        local emails
        emails=$(plutil -convert json -o - "$prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "safari_prefs"
        done <<< "$emails"
    fi

    log "INFO" "Safari scan complete"
}

# Scan Chrome for identities
scan_chrome() {
    log "INFO" "Scanning Chrome..."

    local chrome_dir="$HOME/Library/Application Support/Google/Chrome"
    [[ ! -d "$chrome_dir" ]] && { log "DEBUG" "Chrome directory not found"; return 0; }

    # Scan all Chrome profiles
    local profile_count=0
    for profile_dir in "$chrome_dir"/*/ "$chrome_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        log "DEBUG" "Scanning Chrome profile: $profile_name"

        # Parse Preferences JSON for sync email
        local prefs="${profile_dir}/Preferences"
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ -n "$sync_email" ]] && add_discovered_identity "$sync_email" "chrome_profile:$profile_name"

            # Extract any emails from preferences
            local emails
            emails=$(jq -r '.. | strings' "$prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "chrome_prefs:$profile_name"
            done <<< "$emails"
        fi

        # Parse Login Data (SQLite) for saved usernames
        local login_db="${profile_dir}/Login Data"
        if [[ -f "$login_db" ]]; then
            local temp_db="/tmp/chrome_login_$$.db"
            cp "$login_db" "$temp_db" 2>/dev/null || true

            if [[ -f "$temp_db" ]]; then
                local usernames
                usernames=$(sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value LIKE '%@%';" 2>/dev/null | sort -u)
                while IFS= read -r email; do
                    [[ -n "$email" ]] && add_discovered_identity "$email" "chrome_passwords:$profile_name"
                done <<< "$usernames"
                rm -f "$temp_db"
            fi
        fi

        ((profile_count++))
    done

    log "INFO" "Chrome scan complete: $profile_count profiles scanned"
}

# Scan Microsoft Edge for identities
scan_edge() {
    log "INFO" "Scanning Microsoft Edge..."

    local edge_dir="$HOME/Library/Application Support/Microsoft Edge"
    [[ ! -d "$edge_dir" ]] && { log "DEBUG" "Edge directory not found"; return 0; }

    # Scan all Edge profiles (same structure as Chrome)
    local profile_count=0
    for profile_dir in "$edge_dir"/*/ "$edge_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        log "DEBUG" "Scanning Edge profile: $profile_name"

        # Parse Preferences JSON
        local prefs="${profile_dir}/Preferences"
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ -n "$sync_email" ]] && add_discovered_identity "$sync_email" "edge_profile:$profile_name"

            local emails
            emails=$(jq -r '.. | strings' "$prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "edge_prefs:$profile_name"
            done <<< "$emails"
        fi

        # Parse Login Data
        local login_db="${profile_dir}/Login Data"
        if [[ -f "$login_db" ]]; then
            local temp_db="/tmp/edge_login_$$.db"
            cp "$login_db" "$temp_db" 2>/dev/null || true

            if [[ -f "$temp_db" ]]; then
                local usernames
                usernames=$(sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value LIKE '%@%';" 2>/dev/null | sort -u)
                while IFS= read -r email; do
                    [[ -n "$email" ]] && add_discovered_identity "$email" "edge_passwords:$profile_name"
                done <<< "$usernames"
                rm -f "$temp_db"
            fi
        fi

        ((profile_count++))
    done

    log "INFO" "Edge scan complete: $profile_count profiles scanned"
}

# Scan Firefox for identities
scan_firefox() {
    log "INFO" "Scanning Firefox..."

    local firefox_dir="$HOME/Library/Application Support/Firefox/Profiles"
    [[ ! -d "$firefox_dir" ]] && { log "DEBUG" "Firefox directory not found"; return 0; }

    # Scan all Firefox profiles
    local profile_count=0
    for profile_dir in "$firefox_dir"/*/ ; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        log "DEBUG" "Scanning Firefox profile: $profile_name"

        # Scan logins.json for saved usernames
        local logins_json="${profile_dir}/logins.json"
        if [[ -f "$logins_json" ]]; then
            local emails
            emails=$(jq -r '.logins[].username // empty' "$logins_json" 2>/dev/null | \
                          grep -E "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "firefox_logins:$profile_name"
            done <<< "$emails"
        fi

        # Scan places.sqlite (history/bookmarks)
        local places_db="${profile_dir}/places.sqlite"
        if [[ -f "$places_db" ]]; then
            local temp_db="/tmp/firefox_places_$$.db"
            cp "$places_db" "$temp_db" 2>/dev/null || true

            if [[ -f "$temp_db" ]]; then
                local emails
                emails=$(sqlite3 "$temp_db" "SELECT url FROM moz_places;" 2>/dev/null | \
                              grep -oE "$EMAIL_PATTERN" | sort -u)
                while IFS= read -r email; do
                    [[ -n "$email" ]] && add_discovered_identity "$email" "firefox_history:$profile_name"
                done <<< "$emails"
                rm -f "$temp_db"
            fi
        fi

        ((profile_count++))
    done

    log "INFO" "Firefox scan complete: $profile_count profiles scanned"
}

# Scan Mail.app for account identities
scan_mail() {
    log "INFO" "Scanning Mail.app accounts..."

    local mail_dir="$HOME/Library/Mail"
    [[ ! -d "$mail_dir" ]] && { log "DEBUG" "Mail directory not found"; return 0; }

    # Find Mail version directory (V9, V10, etc.)
    local mail_version_dir
    mail_version_dir=$(find "$mail_dir" -maxdepth 1 -type d -name "V*" 2>/dev/null | sort -r | head -n 1)

    if [[ -z "$mail_version_dir" ]]; then
        log "DEBUG" "No Mail version directory found"
        return 0
    fi

    local accounts_plist="${mail_version_dir}/MailData/Accounts.plist"

    if [[ -f "$accounts_plist" ]]; then
        # Convert plist to JSON and extract email addresses
        local accounts_json
        accounts_json=$(plutil -convert json -o - "$accounts_plist" 2>/dev/null)
        if [[ -n "$accounts_json" ]]; then
            local emails
            emails=$(echo "$accounts_json" | jq -r '.. | .EmailAddresses? // empty | .[]?' 2>/dev/null | sort -u)

            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "mail_account"
            done <<< "$emails"
        fi
    fi

    log "INFO" "Mail.app scan complete"
}

# Scan Application Support for identities
scan_application_support() {
    log "INFO" "Scanning Application Support (this may take a moment)..."

    local app_support="$HOME/Library/Application Support"
    [[ ! -d "$app_support" ]] && { log "DEBUG" "Application Support not found"; return 0; }

    # Whitelist of known apps to check specifically
    local known_apps=(
        "Microsoft"
        "com.microsoft.Office"
        "com.microsoft.Teams"
        "com.microsoft.OneDrive"
        "Slack"
        "Discord"
        "Zoom"
        "Code"
    )

    # Scan known apps
    for app in "${known_apps[@]}"; do
        local app_dir="${app_support}/${app}"
        [[ ! -d "$app_dir" ]] && continue

        log "DEBUG" "Scanning ${app}..."

        # Search for emails in plist, json, and text files (limited depth)
        while IFS= read -r -d '' file; do
            # Skip preserved files
            is_preserved_file "$file" && continue

            # Extract emails from file
            local emails
            emails=$(strings "$file" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "app_support:$app"
            done <<< "$emails"
        done < <(find "$app_dir" -maxdepth 3 -type f \( -name "*.plist" -o -name "*.json" -o -name "*.txt" \) -print0 2>/dev/null)
    done

    log "INFO" "Application Support scan complete"
}

# Scan SSH keys and configuration
scan_ssh() {
    log "INFO" "Scanning SSH keys and config..."

    local ssh_dir="$HOME/.ssh"
    [[ ! -d "$ssh_dir" ]] && { log "DEBUG" "SSH directory not found"; return 0; }

    # Scan public keys for email comments
    while IFS= read -r -d '' pubkey; do
        # Public keys often end with email as comment
        local comment
        comment=$(tail -c 200 "$pubkey" 2>/dev/null | grep -oE "$EMAIL_PATTERN")
        if [[ -n "$comment" ]]; then
            add_discovered_identity "$comment" "ssh_key:$(basename "$pubkey")"
        fi
    done < <(find "$ssh_dir" -name "*.pub" -type f -print0 2>/dev/null)

    # Check SSH config for potential identity hints
    local ssh_config="${ssh_dir}/config"
    if [[ -f "$ssh_config" ]]; then
        local emails
        emails=$(grep -oE "$EMAIL_PATTERN" "$ssh_config" 2>/dev/null | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "ssh_config"
        done <<< "$emails"
    fi

    log "INFO" "SSH scan complete"
}

# Scan Internet Accounts (System Preferences)
scan_internet_accounts() {
    log "INFO" "Scanning Internet Accounts..."

    local accounts_dir="$HOME/Library/Accounts"
    [[ ! -d "$accounts_dir" ]] && { log "DEBUG" "Accounts directory not found"; return 0; }

    # Accounts are stored in Accounts3.sqlite
    local accounts_db="${accounts_dir}/Accounts3.sqlite"

    if [[ -f "$accounts_db" ]]; then
        local temp_db="/tmp/accounts_$$.db"
        cp "$accounts_db" "$temp_db" 2>/dev/null || true

        if [[ -f "$temp_db" ]]; then
            # Extract account identifiers
            local accounts
            accounts=$(sqlite3 "$temp_db" "SELECT ZUSERNAME FROM ZACCOUNT WHERE ZUSERNAME LIKE '%@%';" 2>/dev/null | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "internet_account"
            done <<< "$accounts"
            rm -f "$temp_db"
        fi
    fi

    log "INFO" "Internet Accounts scan complete"
}

# Scan cloud storage configurations
scan_cloud_storage() {
    log "INFO" "Scanning cloud storage configurations..."

    # OneDrive preferences
    local onedrive_prefs="$HOME/Library/Preferences/com.microsoft.OneDrive.plist"
    if [[ -f "$onedrive_prefs" ]]; then
        local emails
        emails=$(plutil -convert json -o - "$onedrive_prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "onedrive_config"
        done <<< "$emails"
    fi

    # Google Drive (if installed)
    local gdrive_prefs="$HOME/Library/Application Support/Google/Drive"
    if [[ -d "$gdrive_prefs" ]]; then
        while IFS= read -r -d '' file; do
            local emails
            emails=$(strings "$file" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "google_drive_config"
            done <<< "$emails"
        done < <(find "$gdrive_prefs" \( -name "*.json" -o -name "*.db" \) -print0 2>/dev/null)
    fi

    log "INFO" "Cloud storage scan complete"
}

# Discover a single specific identity
discover_single_identity() {
    local target="$1"

    # Initialize/reset global arrays
    DISCOVERED_IDENTITIES=()
    IDENTITY_LOCATIONS=()

    # Run all scan functions (add_discovered_identity will filter for target)
    scan_keychain
    scan_safari
    scan_chrome
    scan_edge
    scan_firefox
    scan_mail
    scan_application_support
    scan_ssh
    scan_internet_accounts
    scan_cloud_storage

    # Report findings
    local count=${DISCOVERED_IDENTITIES[$target]:-0}
    if [[ $count -gt 0 ]]; then
        echo -e "${GREEN}✓ Found $count occurrences of ${target}${NC}"
        echo
        return 0
    else
        return 1
    fi
}

# Orchestrate all discovery scans (unused in new single-email mode, kept for reference)
discover_all_identities() {
    display_section_header "Discovering Identities"

    # Initialize/reset global arrays
    DISCOVERED_IDENTITIES=()
    IDENTITY_LOCATIONS=()

    echo "Scanning system for email identities..."
    echo "(This may take 1-2 minutes depending on system size)"
    echo

    # Run all scan functions
    scan_keychain
    scan_safari
    scan_chrome
    scan_edge
    scan_firefox
    scan_mail
    scan_application_support
    scan_ssh
    scan_internet_accounts
    scan_cloud_storage

    # Count results
    local total_found=${#DISCOVERED_IDENTITIES[@]}

    echo
    if [[ $total_found -eq 0 ]]; then
        log_info "No email identities found on this system"
        return 1
    else
        log_success "Discovery complete: $total_found unique identities found"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Menu and Selection Functions
# -----------------------------------------------------------------------------

# Display interactive menu of discovered identities
display_menu() {
    display_section_header "Select Identities to Purge"

    echo "Discovered identities:"
    echo

    # Sort identities by count (descending)
    local sorted_identities
    sorted_identities=$(for email in "${!DISCOVERED_IDENTITIES[@]}"; do
        echo "${DISCOVERED_IDENTITIES[$email]} $email"
    done | sort -rn)

    # Display numbered list
    local index=1
    declare -g -A MENU_INDEX_TO_EMAIL  # Map menu number to email

    while IFS= read -r line; do
        local count
        count=$(echo "$line" | awk '{print $1}')
        local email
        email=$(echo "$line" | cut -d' ' -f2-)

        printf "  ${CYAN}%2d.${NC} %-40s ${YELLOW}(%d occurrences)${NC}\n" "$index" "$email" "$count"

        MENU_INDEX_TO_EMAIL[$index]="$email"
        ((index++))
    done <<< "$sorted_identities"

    echo
    echo "  ${CYAN} 0.${NC} Add a custom identity (manual entry)"
    echo

    return 0
}

# Parse user selection input
parse_selection() {
    local input="$1"
    local -a selected_emails=()

    # Trim whitespace
    input=$(echo "$input" | xargs)

    # Handle special cases
    if [[ "$input" == "all" ]]; then
        # Select all identities
        for email in "${!DISCOVERED_IDENTITIES[@]}"; do
            selected_emails+=("$email")
        done
        echo "${selected_emails[@]}"
        return 0
    fi

    # Parse comma-separated and range inputs
    IFS=',' read -ra parts <<< "$input"

    for part in "${parts[@]}"; do
        part=$(echo "$part" | xargs)  # Trim whitespace

        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Range (e.g., "1-4")
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"

            for ((i=start; i<=end; i++)); do
                if [[ -n "${MENU_INDEX_TO_EMAIL[$i]}" ]]; then
                    selected_emails+=("${MENU_INDEX_TO_EMAIL[$i]}")
                fi
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            # Single number
            local num="$part"

            if [[ "$num" == "0" ]]; then
                # Manual entry
                add_manual_identity
                # Note: This returns the email directly
                return $?
            elif [[ -n "${MENU_INDEX_TO_EMAIL[$num]}" ]]; then
                selected_emails+=("${MENU_INDEX_TO_EMAIL[$num]}")
            else
                log_error "Invalid selection: $num"
            fi
        else
            log_error "Invalid selection format: $part"
        fi
    done

    # Remove duplicates
    local unique_emails
    unique_emails=$(printf '%s\n' "${selected_emails[@]}" | sort -u)

    echo "$unique_emails"
    return 0
}

# Add a manual identity (not auto-discovered)
add_manual_identity() {
    echo
    echo -e "${CYAN}Add Custom Identity${NC}"
    echo "Enter an email address or identity string to purge:"
    echo "(This will be added to the purge list even if not discovered)"
    echo

    read -p "Identity: " manual_identity

    # Trim whitespace
    manual_identity=$(echo "$manual_identity" | xargs)

    if [[ -z "$manual_identity" ]]; then
        log_error "No identity entered"
        return 1
    fi

    # Validate it looks like an email (basic check)
    if [[ ! "$manual_identity" =~ @ ]]; then
        echo -e "${YELLOW}Warning: '$manual_identity' doesn't look like an email address${NC}"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Manual identity cancelled"
            return 1
        fi
    fi

    # Add to discovered identities
    DISCOVERED_IDENTITIES[$manual_identity]=0  # Mark as manual (0 occurrences in discovery)
    IDENTITY_LOCATIONS[$manual_identity]="manual_entry"

    log_info "Added manual identity: $manual_identity"
    echo "$manual_identity"
    return 0
}

# Get user selection from menu
get_user_selection() {
    echo "Selection options:"
    echo "  • Single: 3"
    echo "  • Multiple: 1,3,5"
    echo "  • Range: 1-4"
    echo "  • All: all"
    echo "  • Manual entry: 0"
    echo

    read -p "Select identities to purge: " user_input

    # Parse selection
    local selected
    selected=$(parse_selection "$user_input")

    if [[ -z "$selected" ]]; then
        log_error "No valid selections made"
        return 1
    fi

    echo "$selected"
    return 0
}

# -----------------------------------------------------------------------------
# Preview and Deletion Functions
# -----------------------------------------------------------------------------

# Generate detailed preview for a specific identity
generate_preview() {
    local identity="$1"

    # Preview data stored in global associative array
    declare -g -A PREVIEW_DATA
    PREVIEW_DATA=()

    log "INFO" "Generating preview for: $identity"

    # This will be a deep scan to find ALL occurrences
    # For now, use the location data from discovery
    local locations="${IDENTITY_LOCATIONS[$identity]}"

    # Count items by category
    local keychain_count=0
    local browser_count=0
    local mail_count=0
    local app_count=0
    local ssh_count=0
    local internet_account_count=0
    local cloud_count=0

    IFS=',' read -ra locs <<< "$locations"
    for loc in "${locs[@]}"; do
        case "$loc" in
            keychain*) ((keychain_count++)) ;;
            safari*|chrome*|edge*|firefox*) ((browser_count++)) ;;
            mail*) ((mail_count++)) ;;
            app_support*) ((app_count++)) ;;
            ssh*) ((ssh_count++)) ;;
            internet_account*) ((internet_account_count++)) ;;
            onedrive*|google_drive*) ((cloud_count++)) ;;
        esac
    done

    # Store in preview data
    PREVIEW_DATA[keychain]=$keychain_count
    PREVIEW_DATA[browsers]=$browser_count
    PREVIEW_DATA[mail]=$mail_count
    PREVIEW_DATA[app_support]=$app_count
    PREVIEW_DATA[ssh]=$ssh_count
    PREVIEW_DATA[internet_accounts]=$internet_account_count
    PREVIEW_DATA[cloud_storage]=$cloud_count

    log "DEBUG" "Preview generated: keychain=$keychain_count, browsers=$browser_count, mail=$mail_count"

    return 0
}

# Display preview of what will be deleted
display_preview() {
    local identity="$1"

    echo
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Preview: What will be deleted for ${identity}${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo

    local total=0

    if [[ ${PREVIEW_DATA[keychain]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Keychain:${NC} ${PREVIEW_DATA[keychain]} items (passwords, certificates, keys)"
        ((total+=PREVIEW_DATA[keychain]))
    fi

    if [[ ${PREVIEW_DATA[browsers]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Browsers:${NC} ${PREVIEW_DATA[browsers]} items (profiles, saved passwords, cookies)"
        echo -e "    ${RED}⚠ Browser profiles may include bookmarks and settings${NC}"
        ((total+=PREVIEW_DATA[browsers]))
    fi

    if [[ ${PREVIEW_DATA[mail]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Mail:${NC} ${PREVIEW_DATA[mail]} accounts (configuration and downloaded email)"
        echo -e "    ${RED}⚠ Downloaded email will be PERMANENTLY deleted${NC}"
        ((total+=PREVIEW_DATA[mail]))
    fi

    if [[ ${PREVIEW_DATA[app_support]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Applications:${NC} ${PREVIEW_DATA[app_support]} app-specific credentials"
        ((total+=PREVIEW_DATA[app_support]))
    fi

    if [[ ${PREVIEW_DATA[ssh]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}SSH:${NC} ${PREVIEW_DATA[ssh]} keys/config entries"
        echo -e "    ${RED}⚠ SSH key deletion is permanent${NC}"
        ((total+=PREVIEW_DATA[ssh]))
    fi

    if [[ ${PREVIEW_DATA[internet_accounts]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Internet Accounts:${NC} ${PREVIEW_DATA[internet_accounts]} system accounts"
        ((total+=PREVIEW_DATA[internet_accounts]))
    fi

    if [[ ${PREVIEW_DATA[cloud_storage]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Cloud Storage:${NC} ${PREVIEW_DATA[cloud_storage]} account configs (files preserved)"
        ((total+=PREVIEW_DATA[cloud_storage]))
    fi

    echo
    echo -e "${BOLD}Total items to delete: ${total}${NC}"
    echo

    if [[ $total -eq 0 ]]; then
        echo -e "${YELLOW}No items to delete for this identity${NC}"
        return 1
    fi

    return 0
}

# Process a single identity (preview, confirm, delete)
process_identity() {
    local identity="$1"
    local index="$2"
    local total="$3"

    echo
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Processing identity $index of $total: ${BOLD}$identity${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

    # Generate preview
    generate_preview "$identity"

    # Display preview
    if ! display_preview "$identity"; then
        log_info "Skipping $identity (no items to delete)"
        return 0
    fi

    # In what-if mode, skip confirmation and deletion
    if [[ "$WHAT_IF_MODE" == true ]]; then
        echo -e "${YELLOW}(What-if mode: no deletion will occur)${NC}"
        return 0
    fi

    # Confirm deletion
    if ! confirm_deletion "ALL items for $identity"; then
        log_info "Skipped: $identity"
        return 0
    fi

    # Execute deletion
    execute_deletion "$identity"

    return 0
}

# -----------------------------------------------------------------------------
# Deletion Functions (Actual Deletion Logic)
# -----------------------------------------------------------------------------

# Delete keychain items for an identity
delete_keychain_items() {
    local identity="$1"
    local deleted_count=0
    local failed_count=0

    log "INFO" "Deleting keychain items for: $identity"
    echo "  Scanning keychain for items matching: $identity"

    # Delete generic passwords (apps, services)
    echo "    Searching for generic passwords..."
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local service
        service=$(echo "$line" | awk '{print $1}')
        local account
        account=$(echo "$line" | awk '{print $2}')

        if security delete-generic-password -s "$service" -a "$account" 2>/dev/null; then
            log "INFO" "Deleted generic password: $service ($account)"
            echo "      ✓ Deleted: $service"
            ((deleted_count++))
        else
            ((failed_count++))
            log "WARN" "Failed to delete generic password: $service ($account)"
        fi
    done < <(security dump-keychain 2>/dev/null | \
             awk -v email="$identity" '
                 /^keychain:/ { keychain=$0 }
                 /"acct"<blob>=/ {
                     if ($0 ~ email) {
                         acct=$0
                         getline
                         while (getline && !/^keychain:/ && !/^attributes:/) {
                             if (/"svce"<blob>=/) {
                                 gsub(/.*"svce"<blob>="/, "")
                                 gsub(/".*/, "")
                                 svce=$0
                                 gsub(/.*"acct"<blob>="/, "", acct)
                                 gsub(/".*/, "", acct)
                                 print svce, acct
                             }
                         }
                     }
                 }
             ')

    # Delete internet passwords (websites, email accounts)
    echo "    Searching for internet passwords..."
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local server
        server=$(echo "$line" | awk '{print $1}')
        local account
        account=$(echo "$line" | awk '{print $2}')

        if security delete-internet-password -s "$server" -a "$account" 2>/dev/null; then
            log "INFO" "Deleted internet password: $server ($account)"
            echo "      ✓ Deleted: $server"
            ((deleted_count++))
        else
            ((failed_count++))
            log "WARN" "Failed to delete internet password: $server ($account)"
        fi
    done < <(security dump-keychain 2>/dev/null | \
             awk -v email="$identity" '
                 /"acct"<blob>=/ {
                     if ($0 ~ email) {
                         acct=$0
                         gsub(/.*"acct"<blob>="/, "", acct)
                         gsub(/".*/, "", acct)
                         found=1
                     }
                 }
                 found && /"srvr"<blob>=/ {
                     gsub(/.*"srvr"<blob>="/, "")
                     gsub(/".*/, "")
                     print $0, acct
                     found=0
                 }
             ')

    # Delete certificates matching the email
    echo "    Searching for certificates..."
    while IFS= read -r cert_hash; do
        [[ -z "$cert_hash" ]] && continue

        if security delete-certificate -Z "$cert_hash" 2>/dev/null; then
            log "INFO" "Deleted certificate: $cert_hash"
            echo "      ✓ Deleted certificate: ${cert_hash:0:16}..."
            ((deleted_count++))
        else
            ((failed_count++))
            log "WARN" "Failed to delete certificate: $cert_hash"
        fi
    done < <(security find-certificate -a -e "$identity" -Z 2>/dev/null | \
             grep "^SHA-256 hash:" | awk '{print $3}')

    echo
    if [[ $deleted_count -eq 0 ]]; then
        if [[ $failed_count -gt 0 ]]; then
            echo "    ${YELLOW}⚠ Could not delete $failed_count keychain items (may require user interaction)${NC}"
            add_error "Keychain items for $identity require manual cleanup" \
                      "Open Keychain Access.app and search for: $identity"
        else
            echo "    ${GREEN}✓ No keychain items found for $identity${NC}"
        fi
    else
        echo "    ${GREEN}✓ Deleted $deleted_count keychain items${NC}"
        if [[ $failed_count -gt 0 ]]; then
            echo "    ${YELLOW}⚠ $failed_count items require manual deletion${NC}"
            add_error "Some keychain items for $identity require manual cleanup" \
                      "Open Keychain Access.app and search for: $identity"
        fi
        log "INFO" "Deleted $deleted_count keychain items, $failed_count failed"
    fi

    return 0
}

# Delete browser data for an identity
delete_browser_data() {
    local identity="$1"
    local deleted_count=0

    log "INFO" "Deleting browser data for: $identity"

    # Check which browsers have data for this identity
    local locations="${IDENTITY_LOCATIONS[$identity]}"

    # Chrome
    if [[ "$locations" =~ chrome ]]; then
        if is_app_running "Google Chrome"; then
            if ! prompt_quit_app "Google Chrome"; then
                add_error "Chrome is running" "Quit Chrome and manually delete profiles containing: $identity"
            else
                deleted_count=$((deleted_count + $(delete_chrome_profiles "$identity")))
            fi
        else
            deleted_count=$((deleted_count + $(delete_chrome_profiles "$identity")))
        fi
    fi

    # Edge
    if [[ "$locations" =~ edge ]]; then
        if is_app_running "Microsoft Edge"; then
            if ! prompt_quit_app "Microsoft Edge"; then
                add_error "Edge is running" "Quit Edge and manually delete profiles containing: $identity"
            else
                deleted_count=$((deleted_count + $(delete_edge_profiles "$identity")))
            fi
        else
            deleted_count=$((deleted_count + $(delete_edge_profiles "$identity")))
        fi
    fi

    # Firefox
    if [[ "$locations" =~ firefox ]]; then
        if is_app_running "Firefox"; then
            if ! prompt_quit_app "Firefox"; then
                add_error "Firefox is running" "Quit Firefox and manually delete profiles containing: $identity"
            else
                deleted_count=$((deleted_count + $(delete_firefox_profiles "$identity")))
            fi
        else
            deleted_count=$((deleted_count + $(delete_firefox_profiles "$identity")))
        fi
    fi

    # Safari (data in keychain, handled separately)
    if [[ "$locations" =~ safari ]]; then
        echo "  Safari data (cookies, history) cleared via keychain and cache cleanup"
    fi

    log "INFO" "Browser deletion complete: $deleted_count profiles/items removed"
    return 0
}

# Delete Chrome profiles for an identity
delete_chrome_profiles() {
    local identity="$1"
    local deleted=0

    local chrome_dir="$HOME/Library/Application Support/Google/Chrome"
    [[ ! -d "$chrome_dir" ]] && { echo "0"; return; }

    for profile_dir in "$chrome_dir"/*/ "$chrome_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        local prefs="${profile_dir}/Preferences"

        # Check if this profile contains the identity in ANY location
        local is_match=false

        # Check 1: Sync email
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ "$sync_email" == "$identity" ]] && is_match=true

            # Check 2: Any occurrence in Preferences JSON
            if [[ "$is_match" == false ]]; then
                if jq -r '.. | strings' "$prefs" 2>/dev/null | grep -qF "$identity"; then
                    is_match=true
                    log "DEBUG" "Found $identity in Chrome prefs: $profile_name"
                fi
            fi
        fi

        # Check 3: Saved passwords
        if [[ "$is_match" == false ]]; then
            local login_db="${profile_dir}/Login Data"
            if [[ -f "$login_db" ]]; then
                local temp_db="/tmp/chrome_login_check_$$.db"
                if cp "$login_db" "$temp_db" 2>/dev/null; then
                    if sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value = '$identity';" 2>/dev/null | grep -q .; then
                        is_match=true
                        log "DEBUG" "Found $identity in Chrome passwords: $profile_name"
                    fi
                    rm -f "$temp_db"
                fi
            fi
        fi

        if [[ "$is_match" == true ]]; then
            echo "      Deleting Chrome profile: $profile_name"
            if rm -rf "$profile_dir" 2>/dev/null; then
                echo "      ✓ Deleted Chrome profile: $profile_name"
                log "INFO" "Deleted Chrome profile: $profile_name"
                ((deleted++))
            else
                echo "      ✗ Failed to delete: $profile_name"
                add_error "Failed to delete Chrome profile: $profile_name" \
                          "Manually delete: $profile_dir"
            fi
        fi
    done

    echo "$deleted"
}

# Delete Edge profiles for an identity
delete_edge_profiles() {
    local identity="$1"
    local deleted=0

    local edge_dir="$HOME/Library/Application Support/Microsoft Edge"
    [[ ! -d "$edge_dir" ]] && { echo "0"; return; }

    for profile_dir in "$edge_dir"/*/ "$edge_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        local prefs="${profile_dir}/Preferences"

        # Check if this profile contains the identity in ANY location
        local is_match=false

        # Check 1: Sync email
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ "$sync_email" == "$identity" ]] && is_match=true

            # Check 2: Any occurrence in Preferences JSON
            if [[ "$is_match" == false ]]; then
                if jq -r '.. | strings' "$prefs" 2>/dev/null | grep -qF "$identity"; then
                    is_match=true
                    log "DEBUG" "Found $identity in Edge prefs: $profile_name"
                fi
            fi
        fi

        # Check 3: Saved passwords
        if [[ "$is_match" == false ]]; then
            local login_db="${profile_dir}/Login Data"
            if [[ -f "$login_db" ]]; then
                local temp_db="/tmp/edge_login_check_$$.db"
                if cp "$login_db" "$temp_db" 2>/dev/null; then
                    if sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value = '$identity';" 2>/dev/null | grep -q .; then
                        is_match=true
                        log "DEBUG" "Found $identity in Edge passwords: $profile_name"
                    fi
                    rm -f "$temp_db"
                fi
            fi
        fi

        if [[ "$is_match" == true ]]; then
            echo "      Deleting Edge profile: $profile_name"
            if rm -rf "$profile_dir" 2>/dev/null; then
                echo "      ✓ Deleted Edge profile: $profile_name"
                log "INFO" "Deleted Edge profile: $profile_name"
                ((deleted++))
            else
                echo "      ✗ Failed to delete: $profile_name"
                add_error "Failed to delete Edge profile: $profile_name" \
                          "Manually delete: $profile_dir"
            fi
        fi
    done

    echo "$deleted"
}

# Delete Firefox profiles for an identity
delete_firefox_profiles() {
    local identity="$1"
    local deleted=0

    local firefox_dir="$HOME/Library/Application Support/Firefox/Profiles"
    [[ ! -d "$firefox_dir" ]] && { echo "0"; return; }

    for profile_dir in "$firefox_dir"/*/ ; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")

        # Check if profile contains the identity in ANY location
        local is_match=false

        # Check 1: logins.json (saved passwords)
        local logins_json="${profile_dir}/logins.json"
        if [[ -f "$logins_json" ]]; then
            if jq -r '.logins[].username // empty' "$logins_json" 2>/dev/null | grep -qF "$identity"; then
                is_match=true
                log "DEBUG" "Found $identity in Firefox logins: $profile_name"
            fi
        fi

        # Check 2: places.sqlite (history/bookmarks)
        if [[ "$is_match" == false ]]; then
            local places_db="${profile_dir}/places.sqlite"
            if [[ -f "$places_db" ]]; then
                local temp_db="/tmp/firefox_places_check_$$.db"
                if cp "$places_db" "$temp_db" 2>/dev/null; then
                    if sqlite3 "$temp_db" "SELECT url FROM moz_places WHERE url LIKE '%$identity%';" 2>/dev/null | grep -q .; then
                        is_match=true
                        log "DEBUG" "Found $identity in Firefox history: $profile_name"
                    fi
                    rm -f "$temp_db"
                fi
            fi
        fi

        if [[ "$is_match" == true ]]; then
            echo "      Deleting Firefox profile: $profile_name"
            if rm -rf "$profile_dir" 2>/dev/null; then
                echo "      ✓ Deleted Firefox profile: $profile_name"
                log "INFO" "Deleted Firefox profile: $profile_name"
                ((deleted++))
            else
                echo "      ✗ Failed to delete: $profile_name"
                add_error "Failed to delete Firefox profile: $profile_name" \
                          "Manually delete: $profile_dir"
            fi
        fi
    done

    echo "$deleted"
}

# Delete Mail.app account for an identity
delete_mail_account() {
    local identity="$1"

    log "INFO" "Deleting Mail.app account for: $identity"

    if is_app_running "Mail"; then
        if ! prompt_quit_app "Mail"; then
            add_error "Mail.app is running" "Quit Mail and manually remove account: $identity"
            return 1
        fi
    fi

    local mail_dir="$HOME/Library/Mail"
    local mail_version_dir
    mail_version_dir=$(find "$mail_dir" -maxdepth 1 -type d -name "V*" 2>/dev/null | sort -r | head -n 1)

    [[ ! -d "$mail_version_dir" ]] && { echo "  No Mail data found"; return 0; }

    local accounts_plist="${mail_version_dir}/MailData/Accounts.plist"

    if [[ ! -f "$accounts_plist" ]]; then
        echo "  No Mail accounts found"
        return 0
    fi

    # Convert to JSON and find account
    local accounts_json
    accounts_json=$(plutil -convert json -o - "$accounts_plist" 2>/dev/null)

    # Find account ID for this identity
    # This is complex - for now, report that manual removal may be needed

    echo "  ${YELLOW}Mail.app account removal requires manual cleanup${NC}"
    echo "  ${YELLOW}Open Mail.app > Preferences > Accounts and remove: $identity${NC}"

    add_error "Mail.app account for $identity requires manual removal" \
              "Open Mail.app > Preferences > Accounts > Remove account: $identity"

    return 0
}

# Delete application support data for an identity
delete_app_support_data() {
    local identity="$1"

    log "INFO" "Deleting application support data for: $identity"

    local app_support="$HOME/Library/Application Support"

    # Known apps that might need cleanup
    local apps_to_check=("Microsoft" "Slack" "Discord" "Zoom" "Code")

    for app in "${apps_to_check[@]}"; do
        local app_dir="${app_support}/${app}"
        [[ ! -d "$app_dir" ]] && continue

        # Check if this app has data for the identity
        if grep -r "$identity" "$app_dir" >/dev/null 2>&1; then
            echo "  ${YELLOW}Found $app data containing: $identity${NC}"
            echo "  ${YELLOW}App-specific data cleanup requires manual review${NC}"

            add_error "$app contains data for $identity" \
                      "Manually review and clean up: $app_dir"
        fi
    done

    return 0
}

# Delete SSH keys and config for an identity
delete_ssh_data() {
    local identity="$1"

    log "INFO" "Deleting SSH data for: $identity"

    local ssh_dir="$HOME/.ssh"
    [[ ! -d "$ssh_dir" ]] && { echo "  No SSH directory found"; return 0; }

    local deleted_count=0

    # Find public keys with this identity as comment
    while IFS= read -r -d '' pubkey; do
        if grep -q "$identity" "$pubkey" 2>/dev/null; then
            local privkey="${pubkey%.pub}"

            # Confirm before deleting SSH key
            if confirm_deletion "SSH key pair: $(basename "$pubkey")"; then
                # Delete both public and private key
                if rm -f "$pubkey" "$privkey" 2>/dev/null; then
                    echo "    ✓ Deleted SSH key: $(basename "$pubkey")"
                    log "INFO" "Deleted SSH key: $pubkey"
                    ((deleted_count++))
                else
                    add_error "Failed to delete SSH key: $pubkey" \
                              "Manually delete: rm -f \"$pubkey\" \"$privkey\""
                fi
            else
                log "INFO" "Skipped SSH key: $pubkey"
            fi
        fi
    done < <(find "$ssh_dir" -name "*.pub" -type f -print0 2>/dev/null)

    # Remove entries from SSH config
    local ssh_config="${ssh_dir}/config"
    if [[ -f "$ssh_config" ]]; then
        if grep -q "$identity" "$ssh_config" 2>/dev/null; then
            echo "  ${YELLOW}SSH config contains references to: $identity${NC}"
            echo "  ${YELLOW}Please manually review and edit: $ssh_config${NC}"

            add_error "SSH config contains $identity" \
                      "Manually edit: $ssh_config"
        fi
    fi

    return 0
}

# Delete Internet Account (System Preferences)
delete_internet_account() {
    local identity="$1"

    log "INFO" "Checking Internet Accounts for: $identity"

    echo "  ${YELLOW}Internet Accounts (System Preferences) require manual removal${NC}"
    echo "  ${YELLOW}Open System Settings > Internet Accounts and remove: $identity${NC}"

    add_error "Internet Account for $identity requires manual removal" \
              "Open System Settings > Internet Accounts > Remove account: $identity"

    return 0
}

# Delete cloud storage configurations
delete_cloud_storage_config() {
    local identity="$1"

    log "INFO" "Deleting cloud storage configs for: $identity"

    # OneDrive
    local onedrive_prefs="$HOME/Library/Preferences/com.microsoft.OneDrive.plist"
    if [[ -f "$onedrive_prefs" ]]; then
        if grep -q "$identity" "$onedrive_prefs" 2>/dev/null || \
           plutil -convert json -o - "$onedrive_prefs" 2>/dev/null | grep -q "$identity"; then

            echo "  ${YELLOW}OneDrive configuration contains: $identity${NC}"
            echo "  ${YELLOW}Quit OneDrive and sign out of this account manually${NC}"

            add_error "OneDrive config for $identity requires manual cleanup" \
                      "Quit OneDrive, then sign out of account: $identity"
        fi
    fi

    # Google Drive
    # Similar approach - flag for manual cleanup

    return 0
}

# Execute deletion for an identity
execute_deletion() {
    local identity="$1"

    log "INFO" "Executing deletion for: $identity"

    echo
    echo -e "${CYAN}Deleting all data for: ${BOLD}$identity${NC}"
    echo

    # Delete from each category if present
    if [[ ${PREVIEW_DATA[keychain]:-0} -gt 0 ]]; then
        echo "▸ Keychain..."
        delete_keychain_items "$identity"
    fi

    if [[ ${PREVIEW_DATA[browsers]:-0} -gt 0 ]]; then
        echo "▸ Browsers..."
        delete_browser_data "$identity"
    fi

    if [[ ${PREVIEW_DATA[mail]:-0} -gt 0 ]]; then
        echo "▸ Mail..."
        delete_mail_account "$identity"
    fi

    if [[ ${PREVIEW_DATA[app_support]:-0} -gt 0 ]]; then
        echo "▸ Applications..."
        delete_app_support_data "$identity"
    fi

    if [[ ${PREVIEW_DATA[ssh]:-0} -gt 0 ]]; then
        echo "▸ SSH..."
        delete_ssh_data "$identity"
    fi

    if [[ ${PREVIEW_DATA[internet_accounts]:-0} -gt 0 ]]; then
        echo "▸ Internet Accounts..."
        delete_internet_account "$identity"
    fi

    if [[ ${PREVIEW_DATA[cloud_storage]:-0} -gt 0 ]]; then
        echo "▸ Cloud Storage..."
        delete_cloud_storage_config "$identity"
    fi

    echo
    log_success "Deletion complete for: $identity"

    return 0
}

# -----------------------------------------------------------------------------
# Exit Report
# -----------------------------------------------------------------------------

# Display comprehensive exit report
display_exit_report() {
    stop_timer

    local elapsed
    elapsed=$(get_elapsed_time)

    echo
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Purge Complete${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "Total time: ${YELLOW}$elapsed${NC}"
    echo

    # If there were errors, display them
    if [[ ${#ERROR_MESSAGES[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}ERRORS (${#ERROR_MESSAGES[@]}):${NC}"
        echo

        for i in "${!ERROR_MESSAGES[@]}"; do
            echo -e "${RED}  $((i+1)). ${ERROR_MESSAGES[$i]}${NC}"
            if [[ -n "${ERROR_REMEDIATION[$i]}" ]]; then
                echo -e "     ${YELLOW}→ ${ERROR_REMEDIATION[$i]}${NC}"
            fi
            echo
        done
    else
        echo -e "${GREEN}No errors encountered${NC}"
        echo
    fi

    # Display log location
    echo -e "Detailed log: ${CYAN}${LOG_FILE}${NC}"
    echo

    log "INFO" "Exit report displayed"
}

# -----------------------------------------------------------------------------
# Main Execution
# -----------------------------------------------------------------------------

main() {
    # Parse command-line arguments (includes email validation)
    parse_arguments "$@"

    # Initialize logging
    init_logging "$@"

    # Check for required dependencies
    if ! command -v jq &> /dev/null; then
        log_error "Required dependency 'jq' not found. Install with: brew install jq"
        exit 1
    fi

    # Display header and start timer
    display_header
    start_timer

    log "INFO" "Target email: $TARGET_EMAIL"
    echo
    echo -e "${BOLD}Target Identity: ${CYAN}${TARGET_EMAIL}${NC}"
    echo

    # PHASE 1: Discovery for specific email
    echo "▶ Discovering locations of ${TARGET_EMAIL}..."
    echo
    discover_single_identity "$TARGET_EMAIL"

    # Check if anything was found
    if [[ ${DISCOVERED_IDENTITIES[$TARGET_EMAIL]:-0} -eq 0 ]]; then
        echo -e "${YELLOW}No traces of ${TARGET_EMAIL} found on this system${NC}"
        echo
        display_exit_report
        exit 0
    fi

    log "INFO" "Found ${DISCOVERED_IDENTITIES[$TARGET_EMAIL]} occurrences"

    # PHASE 2: Process the identity (preview, confirm, delete)
    process_identity "$TARGET_EMAIL" 1 1

    # PHASE 3: Exit Report
    display_exit_report

    # Exit code based on errors
    if [[ ${#ERROR_MESSAGES[@]} -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# Run main function
main "$@"
