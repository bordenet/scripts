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
    fetch-github-projects.sh ... [DIRECTORY]
    fetch-github-projects.sh [DIRECTORY] ...

DESCRIPTION
    Updates all Git repositories in a directory with minimal output. By default,
    presents an interactive menu to select which repository to update. Can also
    update all repositories automatically.

    By default, searches up to 2 levels deep. Use ... for unlimited recursion.

    Uses 'git pull --ff-only' to safely update repositories. Repositories with
    divergent branches will be reported as failed and require manual intervention.

    Checks if the script's own repository needs updating before processing other
    repos to prevent running outdated versions.

    Features live timer and inline status updates for clean, minimal output.

OPTIONS
    --all
        Skip interactive menu and update all repositories automatically.
        Searches up to 2 levels deep (*/  and */*/).

    ...
        Recursive mode: searches all subdirectories for git repositories.
        Can be used as first argument or second argument after directory.

    -h, --help
        Display this help message and exit.

ARGUMENTS
    DIRECTORY
        Target directory containing Git repositories. Default: ~/GitHub

PLATFORM
    Cross-platform (macOS, Linux, WSL)
    Compatible with Bash 3.2+ (macOS default)

EXAMPLES
    # Interactive menu mode (default)
    ./fetch-github-projects.sh

    # Update all repos in default directory (2 levels deep)
    ./fetch-github-projects.sh --all

    # Update all repos in custom directory (2 levels deep)
    ./fetch-github-projects.sh --all /path/to/repos

    # Recursively update all repos in current directory
    ./fetch-github-projects.sh ... .

    # Recursively update all repos in custom directory
    ./fetch-github-projects.sh /path/to/repos ...

    # Interactive menu for custom directory
    ./fetch-github-projects.sh /path/to/repos

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

