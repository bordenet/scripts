#!/usr/bin/env bash
################################################################################
# Library: integrate-claude-lib.sh
################################################################################
# PURPOSE: Helper functions for integrate-claude-web-branch.sh
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/lib/integrate-claude-lib.sh"
################################################################################

# Timer functions
show_timer() {
    # shellcheck disable=SC2154  # start_time is set in calling script
    local elapsed=$(($(date +%s) - start_time))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    local cols
    cols=$(tput cols 2>/dev/null || echo 80)
    local timer_text
    timer_text=$(printf "[%02d:%02d:%02d]" "$hours" "$minutes" "$seconds")
    local timer_pos=$((cols - ${#timer_text}))

    # Save cursor, move to top right, print timer (yellow on black), restore cursor
    echo -ne "${SAVE_CURSOR}\033[1;${timer_pos}H\033[33;40m${timer_text}\033[0m${RESTORE_CURSOR}"
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
}

stop_timer() {
    if [ -n "$TIMER_PID" ] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null
    fi
}

# Status update functions
update_status() {
    echo -ne "${ERASE_LINE}\r$*"
}

complete_status() {
    echo -e "${ERASE_LINE}\r$*"
}

# Display help information
show_help() {
    cat << EOF
NAME
    integrate-claude-web-branch.sh - Integrate Claude Code web branches via PR

SYNOPSIS
    integrate-claude-web-branch.sh [OPTIONS] <branch-name>
    integrate-claude-web-branch.sh -h|--help

DESCRIPTION
    Integrates a Claude Code web branch (remote-only) into main via PR workflow.

    TWO MODES:

    1. CREATE-ONLY MODE (--create-only flag):
       • Creates PR and shows URL
       • Exits without merging
       • Use when you want to review PR manually in browser

    2. FULL AUTO-MERGE MODE (default, no flags):
       • Creates PR
       • Checks mergability
       • Shows PR URL with 90-second countdown
       • Auto-merges after countdown (cancellable with Ctrl+C or 'n')
       • Pulls merged changes
       • Complete end-to-end integration

    WORKFLOW STEPS:
    1. Fetches latest from origin (including remote Claude branch)
    2. Validates the remote branch exists
    3. Pulls latest main branch
    4. Creates a pull request from remote branch
    5. [CREATE-ONLY: exits here] OR [FULL: continues below]
    6. Verifies PR can be merged (no conflicts, checks passing)
    7. Shows PR URL with 90-second countdown before auto-merge
    8. Merges the pull request
    9. Pulls merged changes into local main
    10. Leaves remote branch intact (use purge script to clean up later)

    Features live timer and inline status updates for clean, minimal output.

ARGUMENTS
    branch-name
        The Claude Code web branch name to integrate
        Example: claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH

OPTIONS
    --create-only
        Create the PR but don't merge it. Shows PR URL and exits.
        Use this when you want to review the PR manually before merging.

    --what-if
        Dry-run mode: show what would happen without making any changes.
        No branches will be pushed, no PRs created or merged.

    -h, --help
        Display this help message and exit

PLATFORM
    Cross-platform (macOS, Linux, WSL)

DEPENDENCIES
    • git - Version control system
    • gh - GitHub CLI (for PR operations)

EXAMPLES
    # Create PR only (don't merge) - for manual review
    ./integrate-claude-web-branch.sh --create-only claude/feature-branch-name

    # Integrate a Claude Code web branch (full workflow with auto-merge)
    ./integrate-claude-web-branch.sh claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH

    # Dry-run to see what would happen
    ./integrate-claude-web-branch.sh --what-if claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH

NOTES
    This script requires:
    - Must be run from within the target git repository
    - GitHub CLI (gh) must be installed and authenticated
    - Branch must exist on origin (created by Claude Code web)
    - User must have merge permissions to the repository
    - After 90 seconds, PR will auto-merge unless cancelled (Ctrl+C or 'n')

AUTHOR
    Matt J Bordenet

SEE ALSO
    git(1), gh(1), git-pull(1), git-merge(1)

EOF
    exit 0
}

# List available Claude Code branches
list_available_branches() {
    echo
    echo -e "${BLUE}Available Claude Code branches:${NC}"
    echo
    
    # Fetch latest from origin
    git fetch origin > /dev/null 2>&1
    
    # List all remote claude/* branches
    local branches
    branches=$(git branch -r | grep 'origin/claude/' | sed 's|origin/||' | sed 's/^[[:space:]]*//')
    
    if [ -z "$branches" ]; then
        echo "  (no Claude Code branches found)"
    else
        echo "$branches" | while IFS= read -r branch; do
            # Get last commit info
            local last_commit_date
            last_commit_date=$(git log -1 --format="%ar" "origin/$branch" 2>/dev/null || echo "unknown")
            local last_commit_msg
            last_commit_msg=$(git log -1 --format="%s" "origin/$branch" 2>/dev/null | head -c 60)
            
            printf "  ${GREEN}%-60s${NC} ${YELLOW}%s${NC}\n" "$branch" "($last_commit_date)"
            printf "    %s\n" "$last_commit_msg"
        done
    fi
    echo
}

