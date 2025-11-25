#!/usr/bin/env bash

set -euo pipefail

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

export VERSION="1.0.0"
export LOG_DIR="/tmp"
export LOG_FILE=""
export START_TIME
START_TIME=$(date +%s)
export TIMER_PID=""

# Mode flags
export WHAT_IF_MODE=false
export VERBOSE_MODE=false
export TARGET_EMAIL=""  # The email to purge (required argument)

# Email pattern for discovery
export EMAIL_PATTERN='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'

# Error collection
export ERROR_MESSAGES=()
export ERROR_REMEDIATION=()

# Discovery results (exported for library use)
export DISCOVERED_IDENTITIES
declare -gA DISCOVERED_IDENTITIES  # email -> total count
export IDENTITY_LOCATIONS
declare -gA IDENTITY_LOCATIONS     # email -> "location1,location2,..."

# ANSI color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export CYAN='\033[0;36m'
export NC='\033[0m'  # No Color
export BOLD='\033[1m'

# ANSI cursor control
export SAVE_CURSOR='\033[s'
export RESTORE_CURSOR='\033[u'
export MOVE_TO_TOP_RIGHT='\033[1;55H'

# Preserved file patterns (NEVER delete these) - exported for library use
export PRESERVED_PATTERNS=(
    "*.psafe3"
    ".git"
    "*.git/*"
)

# -----------------------------------------------------------------------------
# Logging Functions
# -----------------------------------------------------------------------------

# Initialize logging system
# Utility functions now in purge-identity/lib/utils.sh

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
# Helper functions now in purge-identity/lib/helpers.sh

# -----------------------------------------------------------------------------
# Discovery Functions
# -----------------------------------------------------------------------------

# Add a discovered identity to the global arrays
# Processing functions now in purge-identity/lib/processing.sh

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
