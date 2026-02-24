#!/usr/bin/env bash
################################################################################
# Library: fetch-github-lib.sh
################################################################################
# PURPOSE: Helper functions for fetch-github-projects.sh
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/lib/fetch-github-lib.sh"
################################################################################

# Display help information
show_help() {
    cat << EOF
NAME
    fetch-github-projects.sh - Update Git repositories with minimal output

SYNOPSIS
    fetch-github-projects.sh [OPTIONS] [DIRECTORY]
    fetch-github-projects.sh --all [DIRECTORY]
    fetch-github-projects.sh -r|--recursive [DIRECTORY]
    fetch-github-projects.sh [DIRECTORY] -r|--recursive

DESCRIPTION
    Updates all Git repositories in a directory with minimal output. By default,
    presents an interactive menu to select which repository to update. Can also
    update all repositories automatically.

    By default, searches up to 2 levels deep. Use -r or --recursive for unlimited
    recursion through all subdirectories.

    Uses 'git pull --ff-only' to safely update repositories. Repositories with
    divergent branches will be reported as failed and require manual intervention.

    Checks if the script's own repository needs updating before processing other
    repos to prevent running outdated versions.

    Features live timer and inline status updates for clean, minimal output.

OPTIONS
    --all
        Skip interactive menu and update ALL repositories automatically.
        Implies --recursive: searches all subdirectories for git repositories.

    -r, --recursive
        Recursive mode: searches all subdirectories for git repositories.
        Still shows interactive menu unless combined with --all.
        Can be used as first argument or second argument after directory.

    -v, --verbose
        Verbose mode: shows detailed INFO-level logs for each repository.
        Displays branch detection, local changes check, and pull output.
        Disables inline status updates and timer display.

    --what-if
        Dry-run mode: shows what would be updated without making changes.
        Fetches latest commits to check for updates but doesn't pull.
        Safe for checking repository status before actual updates.

    --merge
        Enable feature branch merging. When on a feature branch, merges
        origin/main (or default branch) into the current branch.

        Interactive mode: prompts per-repo with commit/file stats.
        With --all: shows batch preview, then merges all approved.

        Performs safe rollback if merge conflicts occur:
        - Stashes uncommitted changes (including untracked files)
        - Attempts merge
        - On conflict: aborts merge, restores stash, reports warning

        Skips ambiguous branches (release/*, hotfix/*, develop) with warning.

    -h, --help
        Display this help message and exit.

ARGUMENTS
    DIRECTORY
        Target directory containing Git repositories. Default: . (current directory)

PLATFORM
    Cross-platform (macOS, Linux, WSL)
    Compatible with Bash 3.2+ (macOS default)

EXAMPLES
    # Interactive menu mode (default, 2 levels deep)
    ./fetch-github-projects.sh

    # Interactive menu with recursive search
    ./fetch-github-projects.sh -r
    ./fetch-github-projects.sh /path/to/repos -r

    # Update all repos automatically (2 levels deep)
    ./fetch-github-projects.sh --all

    # Update all repos recursively without menu
    ./fetch-github-projects.sh --all -r
    ./fetch-github-projects.sh --all /path/to/repos -r

    # Update specific directory with verbose output
    ./fetch-github-projects.sh scripts --verbose

    # Update all with detailed logging
    ./fetch-github-projects.sh --all --verbose

    # Dry-run: check what would be updated without making changes
    ./fetch-github-projects.sh --all --what-if
    ./fetch-github-projects.sh scripts --what-if --verbose

    # Merge main into feature branch (interactive)
    ./fetch-github-projects.sh --merge .

    # Batch merge main into all feature branches
    ./fetch-github-projects.sh --all --merge ~/projects

    # Preview what would be merged without executing
    ./fetch-github-projects.sh --what-if --merge .

AUTHOR
    Matt J Bordenet

SEE ALSO
    git-pull(1), git-fetch(1)

EOF
    exit 0
}

# Recursively finds all git repositories
# Note: Uses eval for Bash 3.2 compatibility (macOS default)
find_repos_recursive() {
    local search_dir=$1
    local array_name=$2

    while IFS= read -r -d '' git_dir; do
        repo_dir="${git_dir%/.git}"
        eval "$array_name+=(\"$repo_dir\")"
    done < <(find "$search_dir" -name ".git" -type d -print0 2>/dev/null)
}

# --- Timer/Status Helper Functions ---
# These require global variables: start_time, TIMER_PID, TIMER_WAS_RUNNING, VERBOSE
# ANSI codes: SAVE_CURSOR, RESTORE_CURSOR, ERASE_LINE, NC (must be defined in main script)
# shellcheck disable=SC2154  # Variables are defined in main script

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
    # shellcheck disable=SC2034  # used in main script
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

# --- Summary Display Function ---
# Requires arrays: UPDATED_REPOS, MERGED_REPOS, STASH_CONFLICT_REPOS, SKIPPED_REPOS,
#                  FAILED_REPOS, MERGE_CONFLICT_REPOS, AMBIGUOUS_BRANCH_REPOS
# Requires colors: GREEN, YELLOW, RED, BLUE, BOLD, NC
show_summary() {
    local execution_time=$1
    local has_issues=false

    echo -e "\n${BOLD}Summary${NC} (${execution_time}s)"

    # Updated repos (fast-forward pulls)
    if [ ${#UPDATED_REPOS[@]} -gt 0 ]; then
        echo -e "${GREEN}✓ Updated (${#UPDATED_REPOS[@]}):${NC}"
        for repo in "${UPDATED_REPOS[@]}"; do
            echo "  • $repo"
        done
    fi

    # Merged repos (feature branch merges)
    if [ ${#MERGED_REPOS[@]} -gt 0 ]; then
        echo -e "${GREEN}✓ Merged (${#MERGED_REPOS[@]}):${NC}"
        for repo in "${MERGED_REPOS[@]}"; do
            echo "  • $repo"
        done
    fi

    # Merge conflicts (rolled back)
    if [ ${#MERGE_CONFLICT_REPOS[@]} -gt 0 ]; then
        echo -e "${RED}✗ Merge conflicts (${#MERGE_CONFLICT_REPOS[@]}):${NC}"
        for repo in "${MERGE_CONFLICT_REPOS[@]}"; do
            echo "  • $repo"
        done
        has_issues=true
    fi

    # Stash conflicts
    if [ ${#STASH_CONFLICT_REPOS[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Stash conflicts (${#STASH_CONFLICT_REPOS[@]}):${NC}"
        for repo in "${STASH_CONFLICT_REPOS[@]}"; do
            echo "  • $repo (run 'git stash pop' manually)"
        done
    fi

    # Ambiguous branches skipped
    if [ ${#AMBIGUOUS_BRANCH_REPOS[@]} -gt 0 ]; then
        echo -e "${BLUE}ℹ Ambiguous branches skipped (${#AMBIGUOUS_BRANCH_REPOS[@]}):${NC}"
        for repo in "${AMBIGUOUS_BRANCH_REPOS[@]}"; do
            echo "  • $repo"
        done
    fi

    # Other skipped repos
    if [ ${#SKIPPED_REPOS[@]} -gt 0 ]; then
        echo -e "${YELLOW}⊘ Skipped (${#SKIPPED_REPOS[@]}):${NC}"
        for repo in "${SKIPPED_REPOS[@]}"; do
            echo "  • $repo"
        done
    fi

    # Failed repos
    if [ ${#FAILED_REPOS[@]} -gt 0 ]; then
        echo -e "${RED}✗ Failed (${#FAILED_REPOS[@]}):${NC}"
        for repo in "${FAILED_REPOS[@]}"; do
            echo "  • $repo"
        done
        has_issues=true
    fi

    if [ "$has_issues" = true ]; then
        echo -e "\n${YELLOW}⚠${NC} Some repositories had issues. Review above."
        return 1
    fi

    echo -e "\n${GREEN}✓${NC} All repositories processed successfully!"
    return 0
}

################################################################################
# Branch Classification and Safety Functions
################################################################################

# Classify branch type: default, feature, or ambiguous
# Arguments: current_branch, default_branch
# Output: "default", "feature", or "ambiguous"
classify_branch() {
    local current_branch=$1
    local default_branch=$2

    # Check if on default branch
    if [ "$current_branch" = "$default_branch" ]; then
        echo "default"
        return 0
    fi

    # Check for ambiguous branch patterns
    case "$current_branch" in
        release/*|hotfix/*|develop|development|staging)
            echo "ambiguous"
            return 2
            ;;
    esac

    # Otherwise it's a feature branch
    echo "feature"
    return 1
}

# Check if repo is a shallow clone
# Returns: 0 if shallow, 1 if not
is_shallow_clone() {
    [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]
}

# Check if repo has active lock file
# Returns: 0 if locked, 1 if not
has_lock_file() {
    [ -f ".git/index.lock" ]
}

# Get merge preview stats: commits behind, files changed, lines changed
# Arguments: default_branch
# Output: "5 commits, 12 files, +340/-89" or "0 commits behind"
get_merge_stats() {
    local default_branch=$1
    local commits_behind files_changed lines_added lines_removed

    commits_behind=$(git rev-list --count HEAD.."origin/$default_branch" 2>/dev/null || echo "?")

    if [ "$commits_behind" = "0" ] || [ "$commits_behind" = "?" ]; then
        echo "0 commits behind"
        return
    fi

    # Get diffstat
    local diffstat
    diffstat=$(git diff --shortstat HEAD..."origin/$default_branch" 2>/dev/null || echo "")

    if [ -n "$diffstat" ]; then
        files_changed=$(echo "$diffstat" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
        lines_added=$(echo "$diffstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
        lines_removed=$(echo "$diffstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
        echo "$commits_behind commits, $files_changed files, +${lines_added}/-${lines_removed}"
    else
        echo "$commits_behind commits behind"
    fi
}

# Perform safe merge with automatic rollback on conflict
# Arguments: default_branch
# Output: "SUCCESS", "CONFLICT", "STASH_CONFLICT", or "STASH_FAILED"
# Returns: 0=success, 1=conflict (rolled back), 2=stash conflict (merge ok)
safe_merge_main() {
    local default_branch=$1
    local checkpoint_head stash_created=false stash_name

    checkpoint_head=$(git rev-parse HEAD)
    stash_name="fetch-github-projects $(date +%Y%m%d-%H%M%S) on $(git branch --show-current)"

    # Stash uncommitted changes (including untracked)
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        if ! git stash push -u -m "$stash_name" >/dev/null 2>&1; then
            echo "STASH_FAILED"
            return 1
        fi
        stash_created=true
    fi

    # Attempt merge
    if ! git merge "origin/$default_branch" --no-edit >/dev/null 2>&1; then
        # Rollback: abort merge or hard reset
        git merge --abort 2>/dev/null || git reset --hard "$checkpoint_head" 2>/dev/null
        # Restore stash
        [ "$stash_created" = true ] && git stash pop >/dev/null 2>&1
        echo "CONFLICT"
        return 1
    fi

    # Merge succeeded - restore stash
    if [ "$stash_created" = true ]; then
        if ! git stash pop >/dev/null 2>&1; then
            echo "STASH_CONFLICT"
            return 2
        fi
    fi

    echo "SUCCESS"
    return 0
}

# Preview feature branches that will be merged (for --all --merge batch confirmation)
# Arguments: repos array (passed by name reference in bash 4.3+, or as separate args)
# Returns: 0 if user confirms, 1 if user cancels
# Note: This function is called from fetch-github-projects.sh main script
preview_merge_candidates() {
    local candidates=()
    local original_dir
    original_dir=$(pwd)

    # Process all repo paths passed as arguments
    for repo_path in "$@"; do
        if [ -d "$repo_path/.git" ]; then
            cd "$repo_path" || continue
            local current_branch default_branch branch_type
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            default_branch=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
            [ -z "$default_branch" ] && default_branch="main"
            branch_type=$(classify_branch "$current_branch" "$default_branch")

            if [ "$branch_type" = "feature" ]; then
                # Quick fetch to get accurate stats
                git fetch origin "$default_branch:refs/remotes/origin/$default_branch" >/dev/null 2>&1 || true
                local stats
                stats=$(get_merge_stats "$default_branch")
                if [[ "$stats" != "0 commits behind" ]]; then
                    candidates+=("$repo_path ($current_branch): $stats")
                fi
            fi
            cd "$original_dir" || return 1
        fi
    done

    if [ ${#candidates[@]} -eq 0 ]; then
        echo -e "${BLUE}ℹ${NC} No feature branches need merging"
        return 0  # Still return success, just nothing to do
    fi

    echo ""
    echo -e "${YELLOW}${#candidates[@]} repos on feature branches will merge main:${NC}"
    for c in "${candidates[@]}"; do
        echo "  • $c"
    done
    echo ""
    read -r -p "Proceed with all merges? [y/n/list] " response
    case "$response" in
        [Yy]*) return 0 ;;
        [Ll]*|[Ll]ist)
            echo ""
            for c in "${candidates[@]}"; do echo "  $c"; done
            echo ""
            read -r -p "Proceed? [y/n] " response2
            [[ "$response2" =~ ^[Yy] ]] && return 0
            ;;
    esac
    return 1
}

