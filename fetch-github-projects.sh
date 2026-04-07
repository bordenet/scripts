#!/usr/bin/env bash
# PURPOSE: Fetch and fast-forward all git repos in a directory with minimal output
# USAGE: fetch-github-projects.sh [--all] [-r] [-v] [--what-if] [--merge] [DIRECTORY]
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
# shellcheck disable=SC2034  # Used by lib/fetch-github-lib.sh
SAVE_CURSOR='\033[s'
# shellcheck disable=SC2034  # Used by lib/fetch-github-lib.sh
RESTORE_CURSOR='\033[u'
# --- Global Variables ---
# shellcheck disable=SC2034  # All populated via eval indirect reference in _report() or fetch-github-lib.sh
declare -a UPDATED_REPOS=() SKIPPED_REPOS=() FAILED_REPOS=() STASH_CONFLICT_REPOS=() MERGE_CONFLICT_REPOS=() MERGED_REPOS=() AMBIGUOUS_BRANCH_REPOS=()
# shellcheck disable=SC2034
TIMER_PID=""
STASH_ALL=false; TIMER_WAS_RUNNING=false; MERGE_MODE=false; MERGE_BATCH_CONFIRMED=false

# SSH batch mode to prevent hanging on auth prompts
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -oBatchMode=yes"

# Helper functions (show_timer, timer_loop, start_timer, stop_timer, update_status,
# complete_status, log_verbose, show_summary) are defined in lib/fetch-github-lib.sh
# Updates a single repository
update_repo() {
    local dir=$1
    local repo_name="${dir%/}"
    local show_progress=false
    [ "$VERBOSE" = true ] || [ "${#repos[@]}" -gt 1 ] && show_progress=true

    # Helper: report status, log, track in array, popd, and return
    # Usage: _report "color" "icon" "suffix" "LOG_LEVEL: msg" "ARRAY_NAME" ["entry"]
    _report() {
        local color=$1 icon=$2 suffix=$3 log_msg=$4 arr=${5:-}
        local entry=${6:-"$repo_name: $suffix"}
        [ "$show_progress" = true ] && complete_status "${color}${icon}${NC} ${repo_name}${suffix:+ ($suffix)}"
        log_verbose "$log_msg"
        # Safe indirect array append — arr names are hardcoded constants from callers
        # Use printf %q to escape entry value and prevent injection via repo names
        if [ -n "$arr" ]; then
            local escaped_entry
            printf -v escaped_entry '%q' "$entry"
            eval "$arr+=($escaped_entry)"
        fi
    }

    [ "$show_progress" = true ] && update_status "  Updating ${repo_name}..."
    log_verbose "INFO: Processing repository: $repo_name"
    pushd "$dir" > /dev/null || {
        _report "$RED" "✗" "failed to enter directory" "ERROR: Failed to enter directory: $dir" "FAILED_REPOS"
        return 1
    }

    if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
        _report "$YELLOW" "⊘" "empty repository, skipped" "WARN: Empty repository, skipping" "SKIPPED_REPOS" "$repo_name: empty repository"
        popd > /dev/null || return; return 0
    fi

    if ! git remote get-url origin >/dev/null 2>&1; then
        _report "$YELLOW" "⊘" "no remote, skipped" "WARN: No origin remote configured, skipping" "SKIPPED_REPOS" "$repo_name: no origin remote"
        popd > /dev/null || return; return 0
    fi

    log_verbose "INFO: Detecting default branch..."
    DEFAULT_BRANCH=$(timeout 10 git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}' || true)
    if [ -z "$DEFAULT_BRANCH" ]; then
        if git show-ref --quiet refs/heads/main; then DEFAULT_BRANCH="main"
        elif git show-ref --quiet refs/heads/master; then DEFAULT_BRANCH="master"
        else DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null); fi
    fi
    log_verbose "INFO: Default branch: $DEFAULT_BRANCH"

    local CURRENT_BRANCH
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    log_verbose "INFO: Current branch: $CURRENT_BRANCH"

    if [ -z "$DEFAULT_BRANCH" ] || [ "$DEFAULT_BRANCH" = "HEAD" ]; then
        _report "$YELLOW" "⊘" "detached HEAD or no branch, skipped" "WARN: Detached HEAD or no branch, skipping" "SKIPPED_REPOS" "$repo_name: detached HEAD or no branch"
        popd > /dev/null || return; return 0
    fi
    # Reject repos already in conflict state — stashing unmerged files is unsafe
    if git ls-files --unmerged 2>/dev/null | grep -q .; then
        _report "$RED" "✗" "unresolved conflicts, skipped" \
            "ERROR: Repository has unmerged files. Run 'git status' to inspect." "FAILED_REPOS"
        popd > /dev/null || return; return 1
    fi

    local has_local_changes=false stash_created=false
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then has_local_changes=true; fi
    if [ "$has_local_changes" = true ] && [ "$WHAT_IF" != true ]; then
        local do_stash=false
        if [ "$STASH_ALL" = true ]; then
            do_stash=true

        else
            stop_timer
            echo -ne "${ERASE_LINE}\r"
            echo -ne "${YELLOW}${repo_name}${NC} has local changes. Stash and pull? [y/n/a] "
            read -r stash_choice
            case "$stash_choice" in
                [Yy]) do_stash=true ;;
                [Aa]) do_stash=true; STASH_ALL=true ;;
                *)
                    _report "$YELLOW" "⊘" "local changes, skipped" "WARN: User declined to stash, skipping" "SKIPPED_REPOS" "$repo_name: has local changes (user skipped)"
                    popd > /dev/null || return
                    [ "$VERBOSE" = false ] && [ "${#repos[@]}" -gt 1 ] && start_timer
                    return 0 ;;
            esac
            [ "$VERBOSE" = false ] && [ "${#repos[@]}" -gt 1 ] && start_timer
        fi
        if [ "$do_stash" = true ]; then
            if ! git stash push -m "fetch-github-projects auto-stash" >/dev/null 2>&1; then
                _report "$RED" "✗" "stash failed" "ERROR: Failed to stash changes" "FAILED_REPOS"
                popd > /dev/null || return; return 1
            fi
            stash_created=true
        fi
    fi

    _restore_stash() {
        if [ "$stash_created" = true ]; then
            stash_created=false
            if ! git stash pop >/dev/null 2>&1; then
                # Stash pop conflicted; conflict markers remain in place.
                # Git keeps the stash entry intact on a conflicted pop.
                _report "$RED" "✗" "stash pop conflicted (run: git stash list)" \
                    "ERROR: Stash pop conflicted. Run 'git stash list' and 'git stash apply stash@{0}' to recover." "STASH_CONFLICT_REPOS"
            fi
        fi
    }
    # Fetch latest remote state
    if ! timeout 10 git fetch origin "$DEFAULT_BRANCH:refs/remotes/origin/$DEFAULT_BRANCH" >/dev/null 2>&1; then
        _restore_stash
        _report "$RED" "✗" "fetch failed" "ERROR: Fetch failed" "FAILED_REPOS"
        popd > /dev/null || return; return 1
    fi

    local branch_type; branch_type=$(classify_branch "$CURRENT_BRANCH" "$DEFAULT_BRANCH")
    if [ "$branch_type" = "ambiguous" ]; then
        _restore_stash
        _report "$YELLOW" "⊘" "$CURRENT_BRANCH, ambiguous branch skipped" "INFO: Ambiguous branch pattern, skipping" "AMBIGUOUS_BRANCH_REPOS" "$repo_name ($CURRENT_BRANCH)"
        popd > /dev/null || return; return 0
    fi

    if [ "$MERGE_MODE" = true ] && [ "$branch_type" = "feature" ]; then
        if is_shallow_clone; then
            _restore_stash
            _report "$YELLOW" "⊘" "shallow clone, merge skipped" "WARN: Shallow clone detected, skipping merge" "SKIPPED_REPOS" "$repo_name: shallow clone"
            popd > /dev/null || return; return 0
        fi
        if has_lock_file; then
            _restore_stash
            _report "$YELLOW" "⊘" "locked by another process" "WARN: Repository locked, skipping" "SKIPPED_REPOS" "$repo_name: locked"
            popd > /dev/null || return; return 0
        fi
    fi

    LOCAL=$(git rev-parse HEAD 2>/dev/null)
    REMOTE=$(git rev-parse "origin/$DEFAULT_BRANCH" 2>/dev/null)
    BASE=$(git merge-base HEAD "origin/$DEFAULT_BRANCH" 2>/dev/null || echo "")

    if [ "$WHAT_IF" = true ]; then
        if [ "$LOCAL" = "$REMOTE" ]; then
            _report "$BLUE" "•" "WHAT-IF: would skip, already up to date" "INFO: [WHAT-IF] Already up to date"
        elif [ "$branch_type" = "feature" ] && [ "$MERGE_MODE" = true ]; then
            local merge_stats; merge_stats=$(get_merge_stats "$DEFAULT_BRANCH")
            _report "$GREEN" "✓" "WHAT-IF: would merge $DEFAULT_BRANCH ($merge_stats)" \
                "INFO: [WHAT-IF] Would merge $DEFAULT_BRANCH into $CURRENT_BRANCH ($merge_stats)" \
                "MERGED_REPOS" "$repo_name ($CURRENT_BRANCH would merge $DEFAULT_BRANCH)"
        elif [ "$LOCAL" = "$BASE" ]; then
            _report "$GREEN" "✓" "WHAT-IF: would update" "INFO: [WHAT-IF] Would fast-forward" "UPDATED_REPOS" "$repo_name"
        elif [ "$REMOTE" = "$BASE" ]; then
            # Local is ahead of remote default branch — nothing to pull
            _report "$BLUE" "•" "WHAT-IF: would skip, ahead of origin/$DEFAULT_BRANCH" "INFO: [WHAT-IF] Local branch is ahead of origin/$DEFAULT_BRANCH, nothing to pull"
        else
            _report "$YELLOW" "⊘" "WHAT-IF: diverged, needs manual merge" \
                "WARN: [WHAT-IF] Branches have diverged" "SKIPPED_REPOS" "$repo_name: diverged (use --merge on feature branches)"
        fi
    else
        if [ "$LOCAL" = "$REMOTE" ]; then
            _restore_stash
            _report "$BLUE" "•" "" "INFO: Already up to date"
        elif [ "$LOCAL" = "$BASE" ]; then
            if OUTPUT=$(git pull --ff-only origin "$DEFAULT_BRANCH" 2>&1); then
                _report "$GREEN" "✓" "updated" "INFO: Successfully updated" "UPDATED_REPOS" "$repo_name"
                _restore_stash
            else
                if [ "$stash_created" != true ]; then
                    local local_ahead; local_ahead=$(git rev-list --count "origin/$DEFAULT_BRANCH"..HEAD 2>/dev/null || echo "0")
                    if [ "$local_ahead" -gt 0 ]; then
                        _report "$RED" "✗" "pull failed (has $local_ahead unpushed commit(s))" "ERROR: Pull failed and repo has unpushed commits — refusing to reset" "FAILED_REPOS" "$repo_name: has unpushed commits"
                    elif git fetch origin "$DEFAULT_BRANCH" --quiet 2>/dev/null && \
                       git reset --hard "origin/$DEFAULT_BRANCH" --quiet 2>/dev/null; then
                        _report "$GREEN" "✓" "reset to origin" "INFO: Successfully reset to origin/$DEFAULT_BRANCH" "UPDATED_REPOS" "$repo_name"
                    else
                        _report "$RED" "✗" "pull + reset failed" "ERROR: Pull and reset both failed: $OUTPUT" "FAILED_REPOS" "$repo_name: $OUTPUT"
                    fi
                else
                    _report "$RED" "✗" "pull failed" "ERROR: Pull failed: $OUTPUT" "FAILED_REPOS" "$repo_name: $OUTPUT"
                    _restore_stash
                fi
            fi
        elif [ "$branch_type" = "feature" ] && [ "$MERGE_MODE" = true ]; then
            local merge_stats; merge_stats=$(get_merge_stats "$DEFAULT_BRANCH")
            if [[ "$merge_stats" == "0 commits behind" ]]; then
                _restore_stash
                _report "$BLUE" "•" "$CURRENT_BRANCH, up to date with $DEFAULT_BRANCH" "INFO: Feature branch already up to date"
                popd > /dev/null || return; return 0
            fi
            if [ "$MERGE_BATCH_CONFIRMED" != true ] && { [ "$MENU_MODE" = true ] || [ "$RECURSIVE_MODE" != true ]; }; then
                stop_timer
                echo -ne "${ERASE_LINE}\r"
                echo -e "${YELLOW}${repo_name}${NC} ($CURRENT_BRANCH) is $merge_stats"
                echo -n "  Merge $DEFAULT_BRANCH into $CURRENT_BRANCH? [y/n] "
                read -r merge_response
                if [[ ! "$merge_response" =~ ^[Yy] ]]; then
                    _restore_stash
                    _report "$YELLOW" "⊘" "$CURRENT_BRANCH, user declined merge" "INFO: User declined merge" "SKIPPED_REPOS" "$repo_name ($CURRENT_BRANCH): user declined"
                    [ "$VERBOSE" = false ] && [ "${#repos[@]}" -gt 1 ] && start_timer
                    popd > /dev/null || return; return 0
                fi
                [ "$VERBOSE" = false ] && [ "${#repos[@]}" -gt 1 ] && start_timer
            fi
            local merge_result; merge_result=$(safe_merge_main "$DEFAULT_BRANCH") || true
            _restore_stash
            case "$merge_result" in
                SUCCESS)   _report "$GREEN" "✓" "$CURRENT_BRANCH → merged $DEFAULT_BRANCH" "INFO: Merge succeeded" "MERGED_REPOS" "$repo_name ($CURRENT_BRANCH → merged $DEFAULT_BRANCH)" ;;
                CONFLICT)  _report "$RED" "✗" "$CURRENT_BRANCH → conflict, rolled back" "ERROR: Merge conflict" "MERGE_CONFLICT_REPOS" "$repo_name ($CURRENT_BRANCH): merge conflict, rolled back" ;;
                STASH_CONFLICT)
                    _report "$YELLOW" "⚠" "$CURRENT_BRANCH → merged, stash needs manual pop" "WARN: Stash conflict after merge" "MERGED_REPOS" "$repo_name ($CURRENT_BRANCH → merged, stash conflict)"
                    STASH_CONFLICT_REPOS+=("$repo_name") ;;
                STASH_FAILED) _report "$RED" "✗" "$CURRENT_BRANCH, stash failed" "ERROR: Stash failed before merge" "FAILED_REPOS" "$repo_name: stash failed before merge" ;;
                *) _report "$RED" "✗" "$CURRENT_BRANCH, unexpected: $merge_result" "ERROR: Unexpected merge result: $merge_result" "FAILED_REPOS" "$repo_name: unexpected merge result" ;;
            esac
        elif [ "$REMOTE" = "$BASE" ]; then
            _restore_stash
            _report "$BLUE" "•" "ahead of origin/$DEFAULT_BRANCH" "INFO: Local branch is ahead of origin/$DEFAULT_BRANCH, nothing to pull"
        else
            _restore_stash
            _report "$YELLOW" "⊘" "diverged" "WARN: Branches have diverged, cannot fast-forward" "SKIPPED_REPOS" "$repo_name: diverged (use --merge on feature branches)"
        fi
    fi
    popd > /dev/null || return
}
# --- Main Script ---
MENU_MODE=true; TARGET_DIR=""; RECURSIVE_MODE=false; VERBOSE=false; WHAT_IF=false
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) show_help ;;
        --all)       MENU_MODE=false; RECURSIVE_MODE=true; shift ;;
        -r|--recursive) RECURSIVE_MODE=true; shift ;;
        -v|--verbose)   VERBOSE=true; shift ;;
        --what-if)      WHAT_IF=true; shift ;;
        --merge)        MERGE_MODE=true; shift ;;
        *)              TARGET_DIR="$1"; MENU_MODE=false; shift ;;
    esac
done
[ -z "$TARGET_DIR" ] && TARGET_DIR="."
start_time=$(date +%s)
[ ! -d "$TARGET_DIR" ] && echo "Error: Directory not found: $TARGET_DIR" && exit 1
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
log_verbose "INFO: Target directory: $TARGET_DIR"
log_verbose "INFO: Menu=$MENU_MODE Recursive=$RECURSIVE_MODE Verbose=$VERBOSE"
# --- Self-Update Check ---
if [ -d "$SCRIPT_DIR/.git" ] || [ -f "$SCRIPT_DIR/.git" ]; then
    log_verbose "INFO: Checking if scripts repository needs updating..."
    pushd "$SCRIPT_DIR" > /dev/null || exit
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -oBatchMode=yes" timeout 10 git fetch origin > /dev/null 2>&1 || true
    LOCAL=$(git rev-parse @ 2>/dev/null || true)
    REMOTE=$(git rev-parse '@{u}' 2>/dev/null || true)
    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        echo "⚠️  WARNING: The scripts repository itself has updates available!"
        echo "   cd $SCRIPT_DIR && git pull origin main"
        read -t 15 -r -p "   Continue anyway? [y/N] (auto-No in 15s): " REPLY || REPLY="n"
        [[ ! "$REPLY" =~ ^[Yy]$ ]] && echo "   Exiting." && popd > /dev/null && exit 0
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
    echo -e "${BOLD}Git Repository Updates${NC}: $DISPLAY_DIR\n"
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
    # Follows symlinks (bash globs do this implicitly) with dedup via canonical path
    # Uses newline-delimited string for Bash 3.2 compatibility (no associative arrays)
    _seen_canonical=""
    for dir in */; do
        if [ -d "$dir/.git" ] || [ -f "$dir/.git" ]; then
            _canonical=$(cd "$dir" 2>/dev/null && pwd -P) || continue
            if ! echo "$_seen_canonical" | grep -qxF "$_canonical" 2>/dev/null; then
                _seen_canonical="${_seen_canonical}${_canonical}
"
                repos+=("$dir")
            fi
        else
            for subdir in "$dir"*/; do
                if [ -d "$subdir/.git" ] || [ -f "$subdir/.git" ]; then
                    _canonical=$(cd "$subdir" 2>/dev/null && pwd -P) || continue
                    if ! echo "$_seen_canonical" | grep -qxF "$_canonical" 2>/dev/null; then
                        _seen_canonical="${_seen_canonical}${_canonical}
"
                        repos+=("$subdir")
                    fi
                fi
            done
        fi
    done
    unset _seen_canonical _canonical
    # If no child repos found but current dir is a repo, include it
    if [ ${#repos[@]} -eq 0 ] && { [ -d ".git" ] || [ -f ".git" ]; }; then
        repos+=(".")
    fi
fi
if [ ${#repos[@]} -eq 0 ]; then
    stop_timer
    echo -e "\nNo Git repositories found in $TARGET_DIR"
    exit 0
fi
log_verbose "INFO: Repositories found: ${#repos[@]}"

# Batch confirmation for --all --merge (or non-menu mode with --merge)
if [ "$MENU_MODE" = false ] && [ "$MERGE_MODE" = true ] && [ "$WHAT_IF" != true ]; then
    stop_timer
    if ! preview_merge_candidates "${repos[@]}"; then
        echo -e "${YELLOW}Merge cancelled by user${NC}"
        exit 0
    fi
    MERGE_BATCH_CONFIRMED=true  # Skip per-repo prompts since user already confirmed
    [ "$VERBOSE" = false ] && start_timer
fi

if [ "$MENU_MODE" = true ]; then
    stop_timer  # Stop timer during menu interaction
    if [ "$VERBOSE" = false ]; then clear; echo -e "${BOLD}Git Repository Updates${NC}: $DISPLAY_DIR\n"; fi
    echo "Select a repository to update:"
    for i in "${!repos[@]}"; do printf "%3d) %s\n" "$((i+1))" "${repos[$i]%/}"; done
    echo; read -r -p "Enter number (or 'all'): " choice; echo
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#repos[@]}" ]; then
        update_repo "${repos[$((choice-1))]}"
    elif [ "$choice" == "all" ]; then
        [ "$VERBOSE" = false ] && start_timer
        for dir in "${repos[@]}"; do update_repo "$dir"; done
    else
        echo "Invalid selection."; exit 1
    fi
else
    for dir in "${repos[@]}"; do update_repo "$dir"; done
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

# Use library function for summary display
if ! show_summary "$execution_time"; then
    exit 1
fi
exit 0
