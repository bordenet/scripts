#!/usr/bin/env bash
# Quiet GitHub fetcher — updates all repos in a directory with minimal output
set -euo pipefail
# Source library functions
# Resolve symlinks to get actual script location
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
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
STASH_CONFLICT_REPOS=()
STASH_ALL=false
TIMER_PID=""
TIMER_WAS_RUNNING=false
# --- Helper Functions ---
show_timer() {
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
    timer_loop &
    TIMER_PID=$!
    TIMER_WAS_RUNNING=true
}
stop_timer() {
    if [ -n "$TIMER_PID" ] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null || true
        wait "$TIMER_PID" 2>/dev/null || true
    fi
    TIMER_PID=""
}
update_status() {
    if [ "$VERBOSE" = false ]; then
        echo -ne "${ERASE_LINE}\r$*"
    fi
}
complete_status() {
    if [ "$VERBOSE" = false ]; then
        echo -e "${ERASE_LINE}\r$*"
    fi
}
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "$*"
    fi
}
# Updates a single repository
update_repo() {
    local dir=$1
    local repo_name="${dir%/}"
    local show_progress=false
    if [ "$VERBOSE" = true ] || [ "${#repos[@]}" -gt 1 ]; then
        show_progress=true
    fi

    if [ "$show_progress" = true ]; then
        update_status "  Updating ${repo_name}..."
    fi
    log_verbose "INFO: Processing repository: $repo_name"
    pushd "$dir" > /dev/null || {
        if [ "$show_progress" = true ]; then
            complete_status "${RED}✗${NC} ${repo_name} (failed to enter directory)"
        fi
        log_verbose "ERROR: Failed to enter directory: $dir"
        FAILED_REPOS+=("$repo_name: failed to enter directory")
        return 1
    }
    log_verbose "INFO: Checking repository status..."
    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
        if [ "$show_progress" = true ]; then
            complete_status "${YELLOW}⊘${NC} ${repo_name} (empty repository, skipped)"
        fi
        log_verbose "WARN: Empty repository, skipping"
        SKIPPED_REPOS+=("$repo_name: empty repository")
        popd > /dev/null || return
        return 0
    fi
    log_verbose "INFO: Detecting default branch..."
    DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}' || true)
    if [ -z "$DEFAULT_BRANCH" ]; then
        if git show-ref --quiet refs/heads/main; then
            DEFAULT_BRANCH="main"
        elif git show-ref --quiet refs/heads/master; then
            DEFAULT_BRANCH="master"
        else
            DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        fi
    fi
    log_verbose "INFO: Default branch: $DEFAULT_BRANCH"
    if [ -z "$DEFAULT_BRANCH" ] || [ "$DEFAULT_BRANCH" = "HEAD" ]; then
        if [ "$show_progress" = true ]; then
            complete_status "${YELLOW}⊘${NC} ${repo_name} (detached HEAD or no branch, skipped)"
        fi
        log_verbose "WARN: Detached HEAD or no branch, skipping"
        SKIPPED_REPOS+=("$repo_name: detached HEAD or no branch")
        popd > /dev/null || return
        return 0
    fi
    log_verbose "INFO: Checking for local changes..."
    local has_local_changes=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        has_local_changes=true
    fi

    if [ "$has_local_changes" = true ]; then
        local do_stash=false
        if [ "$STASH_ALL" = true ]; then
            do_stash=true
            log_verbose "INFO: Auto-stashing (user selected 'all')"
        else
            # Stop timer during prompt to avoid visual interference
            stop_timer
            echo -ne "${ERASE_LINE}\r"
            echo -ne "${YELLOW}${repo_name}${NC} has local changes. Stash and pull? [y/n/a] "
            read -r stash_choice
            case "$stash_choice" in
                [Yy])
                    do_stash=true
                    ;;
                [Aa])
                    do_stash=true
                    STASH_ALL=true
                    ;;
                *)
                    if [ "$show_progress" = true ]; then
                        complete_status "${YELLOW}⊘${NC} ${repo_name} (local changes, skipped)"
                    fi
                    log_verbose "WARN: User declined to stash, skipping"
                    SKIPPED_REPOS+=("$repo_name: has local changes (user skipped)")
                    popd > /dev/null || return
                    # Restart timer if we were showing progress
                    if [ "$VERBOSE" = false ] && [ "${#repos[@]}" -gt 1 ]; then
                        start_timer
                    fi
                    return 0
                    ;;
            esac
            # Restart timer after prompt
            if [ "$VERBOSE" = false ] && [ "${#repos[@]}" -gt 1 ]; then
                start_timer
            fi
        fi

        if [ "$do_stash" = true ]; then
            log_verbose "INFO: Stashing local changes..."
            if ! git stash push -m "fetch-github-projects auto-stash" >/dev/null 2>&1; then
                if [ "$show_progress" = true ]; then
                    complete_status "${RED}✗${NC} ${repo_name} (stash failed)"
                fi
                log_verbose "ERROR: Failed to stash changes"
                FAILED_REPOS+=("$repo_name: stash failed")
                popd > /dev/null || return
                return 1
            fi
        fi
    fi
    if [ "$WHAT_IF" = true ]; then
        log_verbose "INFO: [WHAT-IF] Would pull latest changes from origin/$DEFAULT_BRANCH..."
        git fetch origin "$DEFAULT_BRANCH" >/dev/null 2>&1
        LOCAL=$(git rev-parse @ 2>/dev/null)
        REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH" 2>/dev/null)
        if [ "$LOCAL" = "$REMOTE" ]; then
            if [ "$show_progress" = true ]; then
                complete_status "${BLUE}•${NC} ${repo_name} [WHAT-IF: would skip, already up to date]"
            fi
            log_verbose "INFO: [WHAT-IF] Already up to date, would skip"
        else
            if [ "$show_progress" = true ]; then
                complete_status "${GREEN}✓${NC} ${repo_name} [WHAT-IF: would update]"
            fi
            log_verbose "INFO: [WHAT-IF] Would update from $LOCAL to $REMOTE"
            UPDATED_REPOS+=("$repo_name")
        fi
    else
        log_verbose "INFO: Pulling latest changes from origin/$DEFAULT_BRANCH..."
        if OUTPUT=$(git pull --ff-only origin "$DEFAULT_BRANCH" 2>&1); then
            if grep -q "Already up to date" <<< "$OUTPUT"; then
                if [ "$show_progress" = true ]; then
                    complete_status "${BLUE}•${NC} ${repo_name}"
                fi
                log_verbose "INFO: Already up to date"
            else
                if [ "$show_progress" = true ]; then
                    complete_status "${GREEN}✓${NC} ${repo_name} (updated)"
                fi
                log_verbose "INFO: Successfully updated"
                log_verbose "INFO: $OUTPUT"
                UPDATED_REPOS+=("$repo_name")
            fi

            # Pop stash if we stashed earlier
            if [ "$has_local_changes" = true ]; then
                log_verbose "INFO: Restoring stashed changes..."
                if ! git stash pop >/dev/null 2>&1; then
                    if [ "$show_progress" = true ]; then
                        complete_status "${YELLOW}⚠${NC} ${repo_name} (updated, stash pop failed - changes remain in stash)"
                    fi
                    log_verbose "WARN: Stash pop failed, changes remain in stash. Run 'git stash pop' manually."
                    STASH_CONFLICT_REPOS+=("$repo_name")
                else
                    log_verbose "INFO: Stashed changes restored successfully"
                fi
            fi
        else
            if [ "$show_progress" = true ]; then
                complete_status "${RED}✗${NC} ${repo_name} (pull failed)"
            fi
            log_verbose "ERROR: Pull failed: $OUTPUT"
            FAILED_REPOS+=("$repo_name: $OUTPUT")

            # Try to restore stash even if pull failed
            if [ "$has_local_changes" = true ]; then
                log_verbose "INFO: Attempting to restore stashed changes after failed pull..."
                if ! git stash pop >/dev/null 2>&1; then
                    log_verbose "WARN: Stash pop also failed"
                    STASH_CONFLICT_REPOS+=("$repo_name")
                fi
            fi
        fi
    fi
    popd > /dev/null || return
}
# --- Main Script ---
MENU_MODE=true
TARGET_DIR=""
RECURSIVE_MODE=false
VERBOSE=false
WHAT_IF=false
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --all)
            MENU_MODE=false
            RECURSIVE_MODE=true  # --all implies recursive search
            shift
            ;;
        -r|--recursive)
            RECURSIVE_MODE=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --what-if)
            WHAT_IF=true
            shift
            ;;
        *)
            TARGET_DIR="$1"
            MENU_MODE=false  # Directory argument disables menu mode
            shift
            ;;
    esac
done
if [ -z "$TARGET_DIR" ]; then
    # Always default to current directory
    TARGET_DIR="."
fi
start_time=$(date +%s)
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
log_verbose "INFO: Target directory: $TARGET_DIR"
log_verbose "INFO: Menu mode: $MENU_MODE"
log_verbose "INFO: Recursive mode: $RECURSIVE_MODE"
log_verbose "INFO: Verbose mode: $VERBOSE"
# --- Self-Update Check ---
if [ -d "$SCRIPT_DIR/.git" ]; then
    log_verbose "INFO: Checking if scripts repository needs updating..."
    pushd "$SCRIPT_DIR" > /dev/null || exit
    # Disable git prompts to prevent hanging on credential/passphrase prompts
    # Use || true to prevent script exit when upstream branch is not configured
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -oBatchMode=yes" timeout 10 git fetch origin > /dev/null 2>&1 || true
    LOCAL=$(git rev-parse @ 2>/dev/null || true)
    REMOTE=$(git rev-parse '@{u}' 2>/dev/null || true)

    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        echo "⚠️  WARNING: The scripts repository itself has updates available!"
        echo "   This script may be out of date. Consider updating it first:"
        echo "   cd $SCRIPT_DIR && git pull origin main"
        read -t 15 -r -p "   Continue anyway? [y/N] (auto-No in 15s): " REPLY || REPLY="n"
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo "   Exiting. Please update the scripts repo first."
            popd > /dev/null || exit
            exit 0
        fi
    fi
    popd > /dev/null || exit
fi
cd "$TARGET_DIR" || exit
DISPLAY_DIR="$(pwd)"
if [ "$VERBOSE" = false ]; then
    clear
    echo -e "${BOLD}Git Repository Updates${NC}: $DISPLAY_DIR"
    echo
    start_timer
else
    echo -e "${BOLD}Git Repository Updates${NC}: $DISPLAY_DIR"
    echo
fi

trap stop_timer EXIT

repos=()
if [ "$RECURSIVE_MODE" = true ]; then
    update_status "  Searching recursively for repositories..."
    log_verbose "INFO: Searching recursively for repositories..."
    find_repos_recursive "." repos
    complete_status "${BLUE}Found ${#repos[@]} repositories${NC}"
    log_verbose "INFO: Found ${#repos[@]} repositories"
else
    # Menu mode (non-recursive): look for child git repos (up to 2 levels deep)
    for dir in */; do
        if [ -d "$dir/.git" ]; then
            repos+=("$dir")
        else
            for subdir in "$dir"*/; do
                if [ -d "$subdir/.git" ]; then
                    repos+=("$subdir")
                fi
            done
        fi
    done
    # If no child repos found but current dir is a repo, include it
    if [ ${#repos[@]} -eq 0 ] && [ -d ".git" ]; then
        repos+=(".")
    fi
fi

if [ ${#repos[@]} -eq 0 ]; then
    stop_timer
    echo
    echo "No Git repositories found in $TARGET_DIR"
    exit 0
fi

log_verbose "INFO: Repositories found: ${#repos[@]}"

if [ "$MENU_MODE" = true ]; then
    # Stop timer during menu interaction
    stop_timer
    # Clear entire screen and redisplay header without timer
    if [ "$VERBOSE" = false ]; then
        clear
        echo -e "${BOLD}Git Repository Updates${NC}: $DISPLAY_DIR\n"
    fi

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
        # Multiple repos - restart timer if not verbose
        if [ "$VERBOSE" = false ]; then
            start_timer
        fi
        for dir in "${repos[@]}"; do
            update_repo "$dir"
        done
    else
        echo "Invalid selection."
        exit 1
    fi
else
    for dir in "${repos[@]}"; do
        update_repo "$dir"
    done
fi

stop_timer
if [ "$VERBOSE" = false ]; then
    echo -ne "${ERASE_LINE}\r"
    if [ "$TIMER_WAS_RUNNING" = true ]; then
        echo -ne "\033[s\033[1;1H${ERASE_LINE}\r${BOLD}Git Repository Updates${NC}: $DISPLAY_DIR\033[u"
    fi
fi

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo -e "\n${BOLD}Summary${NC} (${execution_time}s)"

if [ ${#UPDATED_REPOS[@]} -gt 0 ]; then
    echo -e "${GREEN}✓ Updated (${#UPDATED_REPOS[@]}):${NC}"
    for repo in "${UPDATED_REPOS[@]}"; do
        echo "  • $repo"
    done
fi

if [ ${#STASH_CONFLICT_REPOS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⚠ Stash conflicts (${#STASH_CONFLICT_REPOS[@]}):${NC}"
    for repo in "${STASH_CONFLICT_REPOS[@]}"; do
        echo "  • $repo (run 'git stash pop' manually)"
    done
fi

if [ ${#SKIPPED_REPOS[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Skipped (${#SKIPPED_REPOS[@]}):${NC}"
    for repo in "${SKIPPED_REPOS[@]}"; do
        echo "  • $repo"
    done
fi

if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed (${#FAILED_REPOS[@]}):${NC}"
    for repo in "${FAILED_REPOS[@]}"; do
        echo "  • $repo"
    done
    exit 1
fi

echo -e "\n${GREEN}✓${NC} All repositories processed successfully!"
exit 0
