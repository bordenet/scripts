#!/usr/bin/env bash
################################################################################
# Library: purge-stale-branches-lib.sh
################################################################################
# PURPOSE: Helper functions for purge-stale-claude-code-web-branches.sh
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/lib/purge-stale-branches-lib.sh"
################################################################################

# Display help information
show_help() {
    cat << EOF
NAME
    purge-stale-claude-code-web-branches.sh - Clean up stale Claude Code branches

SYNOPSIS
    purge-stale-claude-code-web-branches.sh [OPTIONS]
    purge-stale-claude-code-web-branches.sh --all [--what-if]

DESCRIPTION
    Interactive tool to identify and delete stale Claude Code web branches.

    Provides a safe, menu-driven interface to review and delete Claude Code
    web branches (claude/*) that are no longer needed. Shows human-readable
    timestamps and requires confirmation before each deletion.

    Features:
    • Interactive menu with numbered selection
    • Human-readable age display (m/h/d/w/y ago)
    • Per-branch confirmation with commit details
    • Handles both local and remote branches
    • Live timer during operations
    • Comprehensive summary of actions taken

OPTIONS
    --all
        Process all branches sequentially (still requires per-branch confirmation).
        Without this flag, displays interactive menu for selection.

    --what-if
        Dry-run mode: show what would be deleted without making any changes.
        No branches will be deleted locally or remotely.

    -h, --help
        Display this help message and exit

PLATFORM
    Cross-platform (macOS, Linux, WSL)

DEPENDENCIES
    • git - Version control system

EXAMPLES
    # Interactive menu mode (default)
    ./purge-stale-claude-code-web-branches.sh

    # Process all branches with confirmations
    ./purge-stale-claude-code-web-branches.sh --all

    # Dry-run to see what would be deleted
    ./purge-stale-claude-code-web-branches.sh --all --what-if

SAFETY FEATURES
    • Shows commit details before deletion
    • Requires explicit confirmation per branch
    • Never deletes main/master branches
    • Never deletes currently checked out branch
    • Detailed error reporting

BRANCH INFORMATION
    For each branch, shows:
    • Last commit timestamp (human-readable)
    • Last commit author
    • Last commit message
    • Location (local/remote/both)

AUTHOR
    Matt J Bordenet

SEE ALSO
    git(1), git-branch(1), git-push(1)

EOF
    exit 0
}

# Calculate human-readable age from timestamp
calculate_age() {
    local commit_timestamp=$1
    local now
    now=$(date +%s)
    local age_seconds=$((now - commit_timestamp))

    local minutes=$((age_seconds / 60))
    local hours=$((age_seconds / 3600))
    local days=$((age_seconds / 86400))
    local weeks=$((age_seconds / 604800))
    local years=$((age_seconds / 31536000))

    if [ $years -gt 0 ]; then
        echo "${years}y ago"
    elif [ $weeks -gt 0 ]; then
        echo "${weeks}w ago"
    elif [ $days -gt 0 ]; then
        echo "${days}d ago"
    elif [ $hours -gt 0 ]; then
        echo "${hours}h ago"
    else
        echo "${minutes}m ago"
    fi
}

# Format timestamp for display
format_timestamp() {
    local timestamp=$1
    date -r "$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || date -d "@$timestamp" "+%Y-%m-%d %H:%M:%S" 2>/dev/null
}

# Delete a branch (both local and remote as applicable)
delete_branch() {
    local branch_name=$1
    local location=$2
    local what_if=$3
    local failed=false

    if [ "$what_if" = true ]; then
        # Dry-run mode - don't actually delete
        return 0
    fi

    if [[ "$location" == *"local"* ]]; then
        if ! git branch -D "$branch_name" &> /dev/null; then
            failed=true
        fi
    fi

    if [[ "$location" == *"remote"* ]]; then
        # Remove 'origin/' prefix for remote deletion
        local remote_branch="${branch_name#origin/}"
        if ! git push origin --delete "$remote_branch" &> /dev/null; then
            failed=true
        fi
    fi

    # Return status
    if [ "$failed" = true ]; then
        return 1
    else
        return 0
    fi
}

