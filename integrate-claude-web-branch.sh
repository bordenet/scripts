#!/bin/bash
# -----------------------------------------------------------------------------
# Claude Code Web Branch Integration Tool
# Integrates Claude Code web branches via PR workflow with minimal output
# Platform: Cross-platform (macOS, Linux, WSL)
# -----------------------------------------------------------------------------

set -uo pipefail

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
TIMER_PID=""
BRANCH_NAME=""
MAIN_BRANCH=""
PR_NUMBER=""

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

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    integrate-claude-web-branch.sh - Integrate Claude Code web branches via PR

SYNOPSIS
    integrate-claude-web-branch.sh <branch-name>
    integrate-claude-web-branch.sh -h|--help

DESCRIPTION
    Integrates a Claude Code web branch into the main branch via PR workflow.

    This script automates the complete integration workflow:
    1. Validates the branch exists locally and remotely
    2. Pulls latest main branch to avoid conflicts
    3. Creates a pull request against main
    4. Merges the pull request
    5. Pushes the merged changes to origin
    6. Optionally cleans up the feature branch

    Features live timer and inline status updates for clean, minimal output.

ARGUMENTS
    branch-name
        The Claude Code web branch name to integrate
        Example: claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH

OPTIONS
    -h, --help
        Display this help message and exit

PLATFORM
    Cross-platform (macOS, Linux, WSL)

DEPENDENCIES
    • git - Version control system
    • gh - GitHub CLI (for PR operations)

EXAMPLES
    # Integrate a Claude Code web branch
    ./integrate-claude-web-branch.sh claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH

NOTES
    This script requires:
    - Current directory must be a git repository
    - GitHub CLI (gh) must be installed and authenticated
    - Branch must exist both locally and on origin
    - User must have push permissions to the repository

AUTHOR
    Claude Code

SEE ALSO
    git(1), gh(1), git-pull(1), git-merge(1)

EOF
    exit 0
}

# --- Argument Parsing ---
if [ $# -eq 0 ]; then
    echo -e "${RED}Error:${NC} Branch name required"
    echo "Usage: $0 <branch-name>"
    echo "Try '$0 --help' for more information"
    exit 1
fi

case "$1" in
    -h|--help)
        show_help
        ;;
    *)
        BRANCH_NAME="$1"
        ;;
esac

# --- Validation ---
start_time=$(date +%s)

# Clear screen and start
clear
echo -e "${BOLD}Claude Code Branch Integration${NC}: $BRANCH_NAME\n"
start_timer

# Ensure timer stops on exit
trap stop_timer EXIT

# Check if we're in a git repository
update_status "  Validating git repository..."
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    complete_status "${RED}✗${NC} Not a git repository"
    echo
    echo -e "${RED}Error:${NC} Current directory is not a git repository"
    exit 1
fi
complete_status "${GREEN}✓${NC} Git repository validated"

# Check if gh CLI is installed
update_status "  Checking GitHub CLI..."
if ! command -v gh &> /dev/null; then
    complete_status "${RED}✗${NC} GitHub CLI not found"
    echo
    echo -e "${RED}Error:${NC} GitHub CLI (gh) is not installed"
    echo "Install with: brew install gh"
    exit 1
fi
complete_status "${GREEN}✓${NC} GitHub CLI available"

# Check if gh is authenticated
update_status "  Verifying GitHub authentication..."
if ! gh auth status &> /dev/null; then
    complete_status "${RED}✗${NC} GitHub authentication failed"
    echo
    echo -e "${RED}Error:${NC} GitHub CLI is not authenticated"
    echo "Run: gh auth login"
    exit 1
fi
complete_status "${GREEN}✓${NC} GitHub authenticated"

# Detect main branch
update_status "  Detecting main branch..."
MAIN_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
if [ -z "$MAIN_BRANCH" ]; then
    if git show-ref --quiet refs/heads/main; then
        MAIN_BRANCH="main"
    elif git show-ref --quiet refs/heads/master; then
        MAIN_BRANCH="master"
    else
        complete_status "${RED}✗${NC} Could not detect main branch"
        echo
        echo -e "${RED}Error:${NC} Unable to determine main branch (main/master)"
        exit 1
    fi
fi
complete_status "${GREEN}✓${NC} Main branch: $MAIN_BRANCH"

# Check if branch exists locally
update_status "  Checking branch existence..."
if ! git show-ref --quiet refs/heads/"$BRANCH_NAME"; then
    complete_status "${RED}✗${NC} Branch not found locally"
    echo
    echo -e "${RED}Error:${NC} Branch '$BRANCH_NAME' does not exist locally"
    exit 1
fi
complete_status "${GREEN}✓${NC} Branch exists locally"

# --- Integration Workflow ---

# Fetch latest from origin
update_status "  Fetching latest from origin..."
if git fetch origin &> /dev/null; then
    complete_status "${GREEN}✓${NC} Fetched latest from origin"
else
    complete_status "${RED}✗${NC} Failed to fetch from origin"
    exit 1
fi

# Switch to main branch
update_status "  Switching to $MAIN_BRANCH branch..."
if git checkout "$MAIN_BRANCH" &> /dev/null; then
    complete_status "${GREEN}✓${NC} Switched to $MAIN_BRANCH"
else
    complete_status "${RED}✗${NC} Failed to switch to $MAIN_BRANCH"
    exit 1
fi

# Pull latest main
update_status "  Pulling latest $MAIN_BRANCH..."
if git pull origin "$MAIN_BRANCH" &> /dev/null; then
    complete_status "${GREEN}✓${NC} Pulled latest $MAIN_BRANCH"
else
    complete_status "${RED}✗${NC} Failed to pull $MAIN_BRANCH"
    exit 1
fi

# Switch back to feature branch
update_status "  Switching to $BRANCH_NAME..."
if git checkout "$BRANCH_NAME" &> /dev/null; then
    complete_status "${GREEN}✓${NC} Switched to $BRANCH_NAME"
else
    complete_status "${RED}✗${NC} Failed to switch to $BRANCH_NAME"
    exit 1
fi

# Push branch to origin (in case it's not there)
update_status "  Pushing $BRANCH_NAME to origin..."
if git push -u origin "$BRANCH_NAME" &> /dev/null; then
    complete_status "${GREEN}✓${NC} Pushed branch to origin"
else
    complete_status "${RED}✗${NC} Failed to push branch"
    exit 1
fi

# Create pull request
update_status "  Creating pull request..."
if PR_OUTPUT=$(gh pr create --base "$MAIN_BRANCH" --head "$BRANCH_NAME" --fill 2>&1); then
    PR_NUMBER=$(echo "$PR_OUTPUT" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
    complete_status "${GREEN}✓${NC} Created PR #$PR_NUMBER"
else
    # Check if PR already exists
    if echo "$PR_OUTPUT" | grep -q "already exists"; then
        PR_NUMBER=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' 2>/dev/null)
        if [ -n "$PR_NUMBER" ]; then
            complete_status "${BLUE}•${NC} PR #$PR_NUMBER already exists"
        else
            complete_status "${RED}✗${NC} Failed to create PR"
            echo
            echo "$PR_OUTPUT"
            exit 1
        fi
    else
        complete_status "${RED}✗${NC} Failed to create PR"
        echo
        echo "$PR_OUTPUT"
        exit 1
    fi
fi

# Merge pull request
update_status "  Merging PR #$PR_NUMBER..."
if gh pr merge "$PR_NUMBER" --merge --delete-branch=false &> /dev/null; then
    complete_status "${GREEN}✓${NC} Merged PR #$PR_NUMBER"
else
    complete_status "${RED}✗${NC} Failed to merge PR"
    echo
    echo -e "${RED}Error:${NC} Failed to merge PR #$PR_NUMBER"
    echo "You may need to resolve conflicts or check PR status"
    exit 1
fi

# Switch back to main
update_status "  Switching to $MAIN_BRANCH..."
if git checkout "$MAIN_BRANCH" &> /dev/null; then
    complete_status "${GREEN}✓${NC} Switched to $MAIN_BRANCH"
else
    complete_status "${RED}✗${NC} Failed to switch to $MAIN_BRANCH"
    exit 1
fi

# Pull the merged changes
update_status "  Pulling merged changes..."
if git pull origin "$MAIN_BRANCH" &> /dev/null; then
    complete_status "${GREEN}✓${NC} Pulled merged changes"
else
    complete_status "${RED}✗${NC} Failed to pull merged changes"
    exit 1
fi

# Ask about branch cleanup
echo
read -r -p "Delete local branch '$BRANCH_NAME'? [y/N]: " DELETE_LOCAL
if [[ "$DELETE_LOCAL" =~ ^[Yy]$ ]]; then
    update_status "  Deleting local branch..."
    if git branch -D "$BRANCH_NAME" &> /dev/null; then
        complete_status "${GREEN}✓${NC} Deleted local branch"
    else
        complete_status "${YELLOW}⊘${NC} Could not delete local branch"
    fi
fi

# Stop timer and show summary
stop_timer
echo -ne "\033[1;1H${ERASE_LINE}"  # Clear timer line
echo

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo
echo -e "${BOLD}Summary${NC} (${execution_time}s)"
echo
echo -e "${GREEN}✓${NC} Branch '$BRANCH_NAME' successfully integrated into $MAIN_BRANCH"
echo -e "${GREEN}✓${NC} PR #$PR_NUMBER merged and changes pulled"
echo

exit 0
