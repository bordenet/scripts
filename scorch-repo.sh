#!/usr/bin/env bash
################################################################################
# Script Name: scorch-repo.sh
################################################################################
# PURPOSE: Remove build cruft by deleting files listed in .gitignore
# USAGE: ./scorch-repo.sh [OPTIONS] [DIRECTORY]
# PLATFORM: macOS | Linux
################################################################################

# Strict error handling
set -euo pipefail

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/scorch-repo-lib.sh
source "$SCRIPT_DIR/lib/scorch-repo-lib.sh" || {
    echo "ERROR: Cannot load library: $SCRIPT_DIR/lib/scorch-repo-lib.sh" >&2
    exit 1
}

################################################################################
# Constants
################################################################################

# shellcheck disable=SC2034  # VERSION may be used in future enhancements
readonly VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"
# shellcheck disable=SC2034  # SCRIPT_NAME may be used in future enhancements
readonly SCRIPT_NAME

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Timer variables
SCRIPT_START_TIME=$(date +%s)
TIMER_PID=""

################################################################################
# Global Variables
################################################################################

WHAT_IF=false
FORCE=false
VERBOSE=false
INTERACTIVE=false
RECURSIVE=false
ALL_MODE=false
TARGET_DIR="."

# Statistics
TOTAL_FILES_DELETED=0
TOTAL_DIRS_DELETED=0
TOTAL_SIZE_FREED=0
REPOS_PROCESSED=0
REPOS_SKIPPED=0

################################################################################
# Functions
################################################################################

# Function: update_timer
# Description: Update wall clock timer in top-right corner
update_timer() {
    local start_time="$1"
    local cols

    while true; do
        cols=$(tput cols 2>/dev/null || echo 80)
        local elapsed=$(($(date +%s) - start_time))
        local hours=$((elapsed / 3600))
        local minutes=$(((elapsed % 3600) / 60))
        local seconds=$((elapsed % 60))

        local timer_text
        printf -v timer_text "[%02d:%02d:%02d]" "$hours" "$minutes" "$seconds"

        local timer_col=$((cols - ${#timer_text}))

        echo -ne "\033[s"
        echo -ne "\033[1;${timer_col}H"
        echo -ne "\033[33;40m${timer_text}\033[0m"
        echo -ne "\033[u"

        sleep 1
    done
}

# Function: start_timer
# Description: Start the wall clock timer
start_timer() {
    update_timer "$SCRIPT_START_TIME" &
    TIMER_PID=$!
}

# Function: stop_timer
# Description: Stop the wall clock timer
stop_timer() {
    if [[ -n "$TIMER_PID" ]] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null || true
        wait "$TIMER_PID" 2>/dev/null || true
    fi
}

# Function: cleanup
# Description: Cleanup on exit (called by trap)
# shellcheck disable=SC2329  # Function is invoked via trap
cleanup() {
    stop_timer
}
trap cleanup EXIT INT TERM

# Function: log_info
# Description: Log informational message (respects verbose flag)
log_info() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

# Function: log_success
# Description: Log success message
log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

# Function: log_warning
# Description: Log warning message
log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Function: log_error
# Description: Log error message to stderr
log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Function: ask_yes_no_timed
# Description: Ask yes/no question with timeout (defaults to No)
# Parameters:
#   $1 - Question to ask
#   $2 - Timeout in seconds (default: 10)
# Returns: 0 for yes, 1 for no
ask_yes_no_timed() {
    local question="$1"
    local timeout="${2:-10}"
    local response

    echo -ne "${YELLOW}[?]${NC} $question [y/N] (timeout ${timeout}s): "

    if read -t "$timeout" -r response; then
        case "$response" in
            [yY]|[yY][eE][sS])
                echo
                return 0
                ;;
            *)
                echo
                return 1
                ;;
        esac
    else
        echo
        log_info "Timeout - defaulting to No"
        return 1
    fi
}

################################################################################
# Argument Parsing
################################################################################

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --what-if)
            WHAT_IF=true
            shift
            ;;
        -f|--force)
            FORCE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -i|--interactive)
            # shellcheck disable=SC2034  # Reserved for future use
            INTERACTIVE=true
            shift
            ;;
        -r|--recursive)
            RECURSIVE=true
            shift
            ;;
        --all)
            ALL_MODE=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 2
            ;;
        *)
            TARGET_DIR="$1"
            shift
            ;;
    esac
done

# Validate arguments
if [[ "$RECURSIVE" == true ]] && [[ "$ALL_MODE" == false ]]; then
    log_error "The -r/--recursive flag requires --all flag"
    echo "Use --help for usage information"
    exit 2
fi

# Resolve target directory to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)" || {
    log_error "Directory not found: $TARGET_DIR"
    exit 1
}

################################################################################
# Main Script
################################################################################

# Start timer
start_timer

echo -e "${BOLD}Scorch Repository - Build Cruft Removal${NC}"
echo

# Collect repositories
repos=()

if [[ "$RECURSIVE" == true ]] || [[ "$ALL_MODE" == true ]]; then
    # Find repositories
    while IFS= read -r repo; do
        repos+=("$repo")
    done < <(find_git_repos "$TARGET_DIR" "$RECURSIVE")

    if [[ ${#repos[@]} -eq 0 ]]; then
        log_error "No git repositories found in $TARGET_DIR"
        exit 1
    fi

    echo "Found ${#repos[@]} repositories"
    echo
else
    # Single repository mode
    if [[ ! -d "$TARGET_DIR/.git" ]]; then
        log_error "Not a git repository: $TARGET_DIR"
        exit 1
    fi
    repos=("$TARGET_DIR")
fi

# Safety confirmation (unless what-if mode)
if [[ "$WHAT_IF" == false ]]; then
    echo -e "${BOLD}${YELLOW}⚠️  WARNING ⚠️${NC}"
    echo "This will delete files matching .gitignore patterns in ${#repos[@]} repository/repositories."
    echo ".env* files will be protected."
    echo

    if [[ "$FORCE" == true ]]; then
        echo -e "${RED}${BOLD}FORCE MODE ENABLED - This is DANGEROUS!${NC}"
        echo
    fi

    if ! ask_yes_no_timed "Continue with deletion?" 10; then
        echo "Operation cancelled."
        exit 0
    fi
    echo
fi

# Process repositories
if [[ "$ALL_MODE" == true ]]; then
    # Process all repositories
    for repo in "${repos[@]}"; do
        process_repository "$repo"
        echo
    done
else
    # Interactive menu mode (if multiple repos found somehow)
    if [[ ${#repos[@]} -eq 1 ]]; then
        process_repository "${repos[0]}"
    else
        # Show menu
        echo "Select a repository to process:"
        for i in "${!repos[@]}"; do
            printf "%3d) %s\n" "$((i+1))" "$(basename "${repos[$i]}")"
        done
        echo

        read -r -p "Enter number (or 'all'): " choice
        echo

        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#repos[@]} ]]; then
            process_repository "${repos[$((choice-1))]}"
        elif [[ "$choice" == "all" ]]; then
            for repo in "${repos[@]}"; do
                process_repository "$repo"
                echo
            done
        else
            log_error "Invalid selection"
            exit 1
        fi
    fi
fi

# Stop timer and show summary
stop_timer

echo
echo -e "${BOLD}Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Repositories processed: $REPOS_PROCESSED"
echo "Repositories skipped: $REPOS_SKIPPED"

if [[ "$WHAT_IF" == false ]]; then
    echo "Files deleted: $TOTAL_FILES_DELETED"
    echo "Directories deleted: $TOTAL_DIRS_DELETED"
    echo "Total space freed: $(human_readable_size "$TOTAL_SIZE_FREED")"
else
    echo "Mode: WHAT-IF (no changes made)"
fi

# Calculate total execution time
SCRIPT_END_TIME=$(date +%s)
TOTAL_ELAPSED=$((SCRIPT_END_TIME - SCRIPT_START_TIME))
hours=$((TOTAL_ELAPSED / 3600))
minutes=$(((TOTAL_ELAPSED % 3600) / 60))
seconds=$((TOTAL_ELAPSED % 60))

echo
printf "Total execution time: %02d:%02d:%02d\n" "$hours" "$minutes" "$seconds"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

exit 0

