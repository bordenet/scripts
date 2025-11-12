#!/bin/bash
# -----------------------------------------------------------------------------
# Quiet GitHub fetcher — updates all repos in a directory with minimal output
# Platform: Cross-platform
# -----------------------------------------------------------------------------

set -euo pipefail

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    fetch-github-projects.sh - Update Git repositories with minimal output

SYNOPSIS
    fetch-github-projects.sh [OPTIONS] [DIRECTORY]
    fetch-github-projects.sh --all [DIRECTORY]

DESCRIPTION
    Updates all Git repositories in a directory with minimal output. By default,
    presents an interactive menu to select which repository to update. Can also
    update all repositories automatically.

    Checks if the script's own repository needs updating before processing other
    repos to prevent running outdated versions.

OPTIONS
    --all
        Skip interactive menu and update all repositories automatically.

    -h, --help
        Display this help message and exit.

ARGUMENTS
    DIRECTORY
        Target directory containing Git repositories. Default: ~/GitHub

PLATFORM
    Cross-platform (macOS, Linux, WSL)

EXAMPLES
    # Interactive menu mode (default)
    ./fetch-github-projects.sh

    # Update all repos in default directory
    ./fetch-github-projects.sh --all

    # Update all repos in custom directory
    ./fetch-github-projects.sh --all /path/to/repos

    # Interactive menu for custom directory
    ./fetch-github-projects.sh /path/to/repos

AUTHOR
    Claude Code

SEE ALSO
    git-pull(1), git-fetch(1)

EOF
    exit 0
}

# --- Helper Functions ---

# Updates a single repository
update_repo() {
    local dir=$1
    pushd "$dir" > /dev/null

    # Detect default branch
    DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
    if [ -z "$DEFAULT_BRANCH" ]; then
        if git show-ref --quiet refs/heads/main; then
            DEFAULT_BRANCH="main"
        elif git show-ref --quiet refs/heads/master; then
            DEFAULT_BRANCH="master"
        else
            DEFAULT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        fi
    fi

    # Check for local changes
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo "⚠️  Local changes detected in ${dir%/}."
        echo -n "   Revert and sync? [y/N] (auto-No in 10s): "

        read -t 10 -r REPLY || REPLY="n"
        if [[ "$REPLY" =~ ^[Yy]$ ]]; then
            echo "   Reverting local changes..."
            git reset --hard > /dev/null 2>&1
            git clean -fd > /dev/null 2>&1
        else
            echo "   Skipping ${dir%/}."
            popd > /dev/null
            return
        fi
    fi

    # Pull quietly
    OUTPUT=$(git pull origin "$DEFAULT_BRANCH" 2>&1)
    STATUS=$?

    if [ $STATUS -eq 0 ]; then
        if ! grep -q "Already up to date" <<< "$OUTPUT"; then
            echo "✅ ${dir%/}: updated ($DEFAULT_BRANCH)"
        else
            echo "• ${dir%/}: up to date"
        fi
    else
        echo "⚠️  ${dir%/}: pull failed ($DEFAULT_BRANCH)"
        echo "$OUTPUT" | sed 's/^/   /'
    fi

    popd > /dev/null
}

# --- Main Script ---

# Default to menu mode
MENU_MODE=true
TARGET_DIR="$HOME/GitHub"

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
        *)
            TARGET_DIR="$1"
            ;;
    esac
fi

start_time=$(date +%s)

# --- Self-Update Check ---
# Check if this script's own repo needs updating
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -d "$SCRIPT_DIR/.git" ]; then
    pushd "$SCRIPT_DIR" > /dev/null
    git fetch origin > /dev/null 2>&1
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)

    if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
        echo "⚠️  WARNING: The scripts repository itself has updates available!"
        echo "   This script may be out of date. Consider updating it first:"
        echo "   cd $SCRIPT_DIR && git pull origin main"
        echo
        read -t 15 -p "   Continue anyway? [y/N] (auto-No in 15s): " REPLY || REPLY="n"
        if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
            echo "   Exiting. Please update the scripts repo first."
            popd > /dev/null
            exit 0
        fi
        echo
    fi
    popd > /dev/null
fi

echo "Updating Git repositories in: $TARGET_DIR"
echo

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
fi

cd "$TARGET_DIR"

if [ "$MENU_MODE" = true ]; then
    repos=()
    for dir in */; do
        if [ -d "$dir/.git" ]; then
            repos+=("$dir")
        fi
    done

    if [ ${#repos[@]} -eq 0 ]; then
        echo "No Git repositories found in $TARGET_DIR"
        exit 0
    fi

    echo "Select a repository to update:"
    for i in "${!repos[@]}"; do
        printf "%3d) %s\n" "$((i+1))" "${repos[$i]%/}"
    done
    echo

    read -p "Enter number (or 'all'): " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#repos[@]}" ]; then
        update_repo "${repos[$((choice-1))]}"
    elif [ "$choice" == "all" ]; then
        for dir in "${repos[@]}"; do
            update_repo "$dir"
        done
    else
        echo "Invalid selection."
        exit 1
    fi
else
    for dir in */; do
        if [ -d "$dir/.git" ]; then
            update_repo "$dir"
        fi
    done
fi

end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo
echo "Finished updating repositories in ${execution_time}s."
