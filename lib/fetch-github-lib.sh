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
# Requires arrays: UPDATED_REPOS, STASH_CONFLICT_REPOS, SKIPPED_REPOS, FAILED_REPOS
# Requires colors: GREEN, YELLOW, RED, BOLD, NC
show_summary() {
    local execution_time=$1
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
        return 1
    fi
    echo -e "\n${GREEN}✓${NC} All repositories processed successfully!"
    return 0
}

