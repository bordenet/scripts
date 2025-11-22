#!/bin/bash
# -----------------------------------------------------------------------------
# Quiet GitHub fetcher — updates all repos in a directory with minimal output
# Platform: Cross-platform
# -----------------------------------------------------------------------------

set -uo pipefail

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/fetch-github-lib.sh
source "$SCRIPT_DIR/lib/fetch-github-lib.sh"

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ANSI cursor control
ERASE_LINE='\033[2K'
SAVE_CURSOR='\033[s'
RESTORE_CURSOR='\033[u'

# --- Global Variables ---
UPDATED_REPOS=()
SKIPPED_REPOS=()
FAILED_REPOS=()
TIMER_PID=""
TIMER_WAS_RUNNING=false

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
    timer_loop &
    TIMER_PID=$!
    TIMER_WAS_RUNNING=true
}

# Stop timer
stop_timer() {
    if [ -n "$TIMER_PID" ] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null
    fi
}

# Update current line with status
update_status() {
    echo -ne "${ERASE_LINE}\r$*"
}

# Complete current line
complete_status() {
    echo -e "${ERASE_LINE}\r$*"
}

# --- Helper Functions (show_help and find_repos_recursive in lib/fetch-github-lib.sh) ---

# Updates a single repository
update_repo() {
    local dir=$1
    local repo_name="${dir%/}"

    update_status "  Updating ${repo_name}..."

    pushd "$dir" > /dev/null || {
        complete_status "${RED}✗${NC} ${repo_name} (failed to enter directory)"
        FAILED_REPOS+=("$repo_name: failed to enter directory")
        return 1
    }

    # Check if this is an empty/uninitialized repo
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
        complete_status "${YELLOW}⊘${NC} ${repo_name} (empty repository, skipped)"
        SKIPPED_REPOS+=("$repo_name: empty repository")
        popd > /dev/null || return
        return 0
    fi

    # Detect default branch
    DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
    if [ -z "$DEFAULT_BRANCH" ]; then
        if git show-ref --quiet refs/heads/main; then
            DEFAULT_BRANCH="main"
        elif git show-ref --quiet refs/heads/master; then
            DEFAULT_BRANCH="master"
        else
            DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        fi
    fi

    # If still no branch, skip this repo
    if [ -z "$DEFAULT_BRANCH" ] || [ "$DEFAULT_BRANCH" = "HEAD" ]; then
        complete_status "${YELLOW}⊘${NC} ${repo_name} (detached HEAD or no branch, skipped)"
        SKIPPED_REPOS+=("$repo_name: detached HEAD or no branch")
        popd > /dev/null || return
        return 0
    fi

    # Check for local changes
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        complete_status "${YELLOW}⊘${NC} ${repo_name} (local changes, skipped)"
        SKIPPED_REPOS+=("$repo_name: has local changes")
        popd > /dev/null || return
        return 0
    fi

    # Pull quietly (fast-forward only to avoid merge conflicts)
    if OUTPUT=$(git pull --ff-only origin "$DEFAULT_BRANCH" 2>&1); then
        if grep -q "Already up to date" <<< "$OUTPUT"; then
            complete_status "${BLUE}•${NC} ${repo_name}"
        else
            complete_status "${GREEN}✓${NC} ${repo_name} (updated)"
            UPDATED_REPOS+=("$repo_name")
        fi
    else
        complete_status "${RED}✗${NC} ${repo_name} (pull failed)"
        FAILED_REPOS+=("$repo_name: $OUTPUT")
    fi

    popd > /dev/null || return
}

# --- Main Script ---

# Default to menu mode
MENU_MODE=true
TARGET_DIR="$HOME/GitHub"
RECURSIVE_MODE=false

# Parse arguments
if [ $# -gt 0 ]; then
    case "$1" in
        -h|--help)
            show_help
            ;;
        --all)
            MENU_MODE=false
            TARGET_DIR="${2:-$HOME/GitHub}"
            ;;
        ...)
            MENU_MODE=false
            RECURSIVE_MODE=true
            TARGET_DIR="${2:-.}"
            ;;
        *)
            TARGET_DIR="$1"
            # Check if second argument is ...
            if [ "${2:-}" = "..." ]; then
                MENU_MODE=false
                RECURSIVE_MODE=true
            fi
            ;;
    esac
fi

start_time=$(date +%s)

# --- Self-Update Check ---
# Check if this script's own repo needs updating
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/.git" ]; then
    pushd "$SCRIPT_DIR" > /dev/null || exit
    git fetch origin > /dev/null 2>&1
    LOCAL=$(git rev-parse @ 2>/dev/null)
    REMOTE=$(git rev-parse '@{u}' 2>/dev/null)

    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        echo "⚠️  WARNING: The scripts repository itself has updates available!"
        echo "   This script may be out of date. Consider updating it first:"
        echo "   cd $SCRIPT_DIR && git pull origin main"
        echo
        read -t 15 -r -p "   Continue anyway? [y/N] (auto-No in 15s): " REPLY || REPLY="n"
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo "   Exiting. Please update the scripts repo first."
            popd > /dev/null || exit
            exit 0
        fi
        echo
    fi
    popd > /dev/null || exit
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
fi

cd "$TARGET_DIR" || exit

# Start output
clear
echo -e "${BOLD}Git Repository Updates${NC}: $TARGET_DIR\n"
start_timer

# Ensure timer stops on exit
trap stop_timer EXIT

# Collect repositories based on mode
repos=()
if [ "$RECURSIVE_MODE" = true ]; then
    update_status "  Searching recursively for repositories..."
    find_repos_recursive "." repos
    complete_status "${BLUE}Found ${#repos[@]} repositories${NC}"
elif [ "$MENU_MODE" = true ]; then
    for dir in */; do
        if [ -d "$dir/.git" ]; then
            repos+=("$dir")
        else
            # Check second level if first level isn't a git repo
            for subdir in "$dir"*/; do
                if [ -d "$subdir/.git" ]; then
                    repos+=("$subdir")
                fi
            done
        fi
    done
else
    # --all mode (non-recursive)
    for dir in */; do
        if [ -d "$dir/.git" ]; then
            repos+=("$dir")
        else
            # Check second level if first level isn't a git repo
            for subdir in "$dir"*/; do
                if [ -d "$subdir/.git" ]; then
                    repos+=("$subdir")
                fi
            done
        fi
    done
fi

if [ ${#repos[@]} -eq 0 ]; then
    stop_timer
    echo
    echo "No Git repositories found in $TARGET_DIR"
    exit 0
fi

if [ "$MENU_MODE" = true ]; then
    # Stop timer during menu interaction
    stop_timer
    # Clear entire screen and redisplay header without timer
    clear
    echo -e "${BOLD}Git Repository Updates${NC}: $TARGET_DIR\n"

    echo "Select a repository to update:"
    for i in "${!repos[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${repos[$i]%/}"
    done
    echo

    read -r -p "Enter number (or 'all'): " choice
    echo

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#repos[@]}" ]; then
        # Single repo - no timer needed for quick operation
        update_repo "${repos[$((choice-1))]}"
    elif [ "$choice" == "all" ]; then
        # Multiple repos - restart timer
        start_timer
        for dir in "${repos[@]}"; do
            update_repo "$dir"
        done
    else
        echo "Invalid selection."
        exit 1
    fi
else
    # Auto mode (--all or ...)
    for dir in "${repos[@]}"; do
        update_repo "$dir"
    done
fi

# Stop timer and show summary
stop_timer
# Only clear timer line if timer was actually running
if [ "$TIMER_WAS_RUNNING" = true ]; then
    echo -ne "\033[s\033[1;1H${ERASE_LINE}\033[u"  # Clear timer line, restore cursor
fi
echo  # Blank line after last status

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo
echo -e "${BOLD}Summary${NC} (${execution_time}s)"
echo

if [ ${#UPDATED_REPOS[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Updated (${#UPDATED_REPOS[@]}):${NC}"
    for repo in "${UPDATED_REPOS[@]}"; do
        echo "  • $repo"
    done
    echo
fi

if [ ${#SKIPPED_REPOS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Skipped (${#SKIPPED_REPOS[@]}):${NC}"
    for repo in "${SKIPPED_REPOS[@]}"; do
        echo "  • $repo"
    done
    echo
fi

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed (${#FAILED_REPOS[@]}):${NC}"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "  • $repo"
    done
    echo
    exit 1
fi

echo -e "${GREEN}✓${NC} All repositories processed successfully!"
exit 0
