#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Claude Code Web Branch Integration Tool
# Integrates Claude Code web branches via PR workflow with minimal output
# Platform: Cross-platform (macOS, Linux, WSL)
# -----------------------------------------------------------------------------


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
# shellcheck source=lib/integrate-claude-lib.sh
source "$SCRIPT_DIR/lib/integrate-claude-lib.sh"

# --- Colors for Output ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ANSI cursor control
ERASE_LINE='\033[2K'
# Unused: SAVE_CURSOR='\033[s'
# Unused: RESTORE_CURSOR='\033[u'

# --- Global Variables ---
export TIMER_PID=""  # Used in lib
BRANCH_NAME=""
MAIN_BRANCH=""
PR_NUMBER=""
WHAT_IF=false
CREATE_ONLY=false
VERBOSE=false

# --- Functions ---

# Logs verbose messages when --verbose flag is set.
log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo "[VERBOSE] $1" >&2
  fi
}

# --- Argument Parsing ---
[ $# -eq 0 ] && { echo -e "${RED}Error:${NC} Branch name required\nUsage: $0 [--what-if] <branch-name>\nTry '$0 --help' for more information"; exit 1; }
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help) show_help ;;
        --create-only) CREATE_ONLY=true; shift ;;
        --what-if) WHAT_IF=true; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        -*) echo -e "${RED}Error:${NC} Unknown option: $1\nTry '$0 --help' for more information"; exit 1 ;;
        *) BRANCH_NAME="$1"; shift ;;
    esac
done
[ -z "$BRANCH_NAME" ] && { echo -e "${RED}Error:${NC} Branch name required\nUsage: $0 [--what-if] <branch-name>\nTry '$0 --help' for more information"; exit 1; }

# --- Validation ---
start_time=$(date +%s)

# Clear screen and start
clear
if [ "$WHAT_IF" = true ]; then
    echo -e "${BOLD}Claude Code Branch Integration${NC} ${YELLOW}[DRY-RUN]${NC}: $BRANCH_NAME\n"
elif [ "$CREATE_ONLY" = true ]; then
    echo -e "${BOLD}Claude Code Branch Integration${NC} ${GREEN}[CREATE-ONLY]${NC}: $BRANCH_NAME\n"
else
    echo -e "${BOLD}Claude Code Branch Integration${NC}: $BRANCH_NAME\n"
fi
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

# Fetch latest from origin (including remote Claude branches)
update_status "  Fetching latest from origin..."
log_verbose "Running git fetch origin"
if git fetch origin &> /dev/null; then
    complete_status "${GREEN}✓${NC} Fetched latest from origin"
    log_verbose "Fetch completed successfully"
else
    complete_status "${RED}✗${NC} Failed to fetch from origin"
    exit 1
fi

# Detect main branch (use || true to prevent pipefail from killing script)
update_status "  Detecting main branch..."
log_verbose "Querying remote HEAD branch"
MAIN_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}' || true)
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

# Check if remote branch exists
update_status "  Verifying remote branch exists..."
log_verbose "Checking for remote branch: origin/$BRANCH_NAME"
if ! git show-ref --quiet refs/remotes/origin/"$BRANCH_NAME"; then
    complete_status "${RED}✗${NC} Remote branch not found"
    echo
    echo -e "${RED}Error:${NC} Branch 'origin/$BRANCH_NAME' does not exist"
    list_available_branches
    exit 1
fi
complete_status "${GREEN}✓${NC} Remote branch exists"
log_verbose "Remote branch verified: origin/$BRANCH_NAME"

# --- Integration Workflow ---

# Switch to main branch
update_status "  Switching to $MAIN_BRANCH branch..."
if [ "$WHAT_IF" = true ]; then
    complete_status "${YELLOW}⊙${NC} Would switch to $MAIN_BRANCH"
else
    if git checkout "$MAIN_BRANCH" &> /dev/null; then
        complete_status "${GREEN}✓${NC} Switched to $MAIN_BRANCH"
    else
        complete_status "${RED}✗${NC} Failed to switch to $MAIN_BRANCH"
        exit 1
    fi
fi

# Pull latest main
update_status "  Pulling latest $MAIN_BRANCH..."
if [ "$WHAT_IF" = true ]; then
    complete_status "${YELLOW}⊙${NC} Would pull latest $MAIN_BRANCH"
else
    if git pull origin "$MAIN_BRANCH" &> /dev/null; then
        complete_status "${GREEN}✓${NC} Pulled latest $MAIN_BRANCH"
    else
        complete_status "${RED}✗${NC} Failed to pull $MAIN_BRANCH"
        exit 1
    fi
fi

# Create pull request from remote branch
update_status "  Creating pull request..."
log_verbose "Attempting to create PR: $BRANCH_NAME → $MAIN_BRANCH"
if [ "$WHAT_IF" = true ]; then
    complete_status "${YELLOW}⊙${NC} Would create PR: origin/$BRANCH_NAME → $MAIN_BRANCH"
    PR_NUMBER="(dry-run)"
    PR_URL="https://github.com/owner/repo/pull/123"
else
    # For remote-only branches, we need to specify origin/ prefix or fetch the branch locally first
    # Try creating PR directly; if it fails with ambiguous revision, fetch the branch
    log_verbose "Running gh pr create --base $MAIN_BRANCH --head $BRANCH_NAME --fill"
    if PR_OUTPUT=$(gh pr create --base "$MAIN_BRANCH" --head "$BRANCH_NAME" --fill 2>&1); then
        PR_NUMBER=$(echo "$PR_OUTPUT" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
        PR_URL=$(echo "$PR_OUTPUT" | grep -oE 'https://[^ ]+')
        complete_status "${GREEN}✓${NC} Created PR #$PR_NUMBER"
    else
        # Check if PR already exists
        if echo "$PR_OUTPUT" | grep -q "already exists"; then
            PR_NUMBER=$(gh pr list --head "$BRANCH_NAME" --json number --jq '.[0].number' 2>/dev/null)
            if [ -n "$PR_NUMBER" ]; then
                PR_URL=$(gh pr view "$PR_NUMBER" --json url --jq '.url' 2>/dev/null)
                complete_status "${BLUE}•${NC} PR #$PR_NUMBER already exists"
            else
                complete_status "${RED}✗${NC} Failed to create PR"
                echo
                echo "$PR_OUTPUT"
                list_available_branches
                exit 1
            fi
        # Check for "could not find any commits" error
        elif echo "$PR_OUTPUT" | grep -q "could not find any commits"; then
            complete_status "${RED}✗${NC} No new commits to merge"
            echo
            echo -e "${RED}Error:${NC} Branch '$BRANCH_NAME' has no commits different from $MAIN_BRANCH"
            echo "This usually means:"
            echo "  • The branch was already merged"
            echo "  • The branch has no new changes"
            echo
            echo "Try a different branch:"
            list_available_branches
            exit 1
        # Check if it failed due to ambiguous revision (remote-only branch)
        elif echo "$PR_OUTPUT" | grep -q "ambiguous argument\|unknown revision"; then
            # Fetch the remote branch locally to allow gh pr create to work
            update_status "  Fetching remote branch locally..."
            if git fetch origin "$BRANCH_NAME:$BRANCH_NAME" &> /dev/null; then
                complete_status "${GREEN}✓${NC} Fetched remote branch locally"
                # Try creating PR again
                update_status "  Creating pull request..."
                if PR_OUTPUT=$(gh pr create --base "$MAIN_BRANCH" --head "$BRANCH_NAME" --fill 2>&1); then
                    PR_NUMBER=$(echo "$PR_OUTPUT" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
                    PR_URL=$(echo "$PR_OUTPUT" | grep -oE 'https://[^ ]+')
                    complete_status "${GREEN}✓${NC} Created PR #$PR_NUMBER"
                # Check for "could not find any commits" error on retry
                elif echo "$PR_OUTPUT" | grep -q "could not find any commits"; then
                    complete_status "${RED}✗${NC} No new commits to merge"
                    echo
                    echo -e "${RED}Error:${NC} Branch '$BRANCH_NAME' has no commits different from $MAIN_BRANCH"
                    echo "This usually means:"
                    echo "  • The branch was already merged"
                    echo "  • The branch has no new changes"
                    echo
                    echo "Try a different branch:"
                    list_available_branches
                    exit 1
                else
                    complete_status "${RED}✗${NC} Failed to create PR"
                    echo
                    echo "$PR_OUTPUT"
                    list_available_branches
                    exit 1
                fi
            else
                complete_status "${RED}✗${NC} Failed to fetch remote branch"
                echo
                echo "$PR_OUTPUT"
                list_available_branches
                exit 1
            fi
        else
            complete_status "${RED}✗${NC} Failed to create PR"
            echo
            echo "$PR_OUTPUT"
            echo
            echo "Try a different branch:"
            list_available_branches
            exit 1
        fi
    fi
fi

# If create-only mode, stop here and show PR URL
if [ "$CREATE_ONLY" = true ]; then
    stop_timer
    echo
    echo -e "${BOLD}Pull Request Created${NC}"
    echo -e "${BLUE}$PR_URL${NC}"
    echo
    echo "PR #$PR_NUMBER is ready for review"
    echo "Merge manually when ready, or run without --create-only to auto-merge"
    exit 0
fi

# Check if PR is mergeable
if [ "$WHAT_IF" = false ]; then
    update_status "  Checking PR mergability..."
    MERGEABLE=$(gh pr view "$PR_NUMBER" --json mergeable --jq '.mergeable' 2>/dev/null)
    if [ "$MERGEABLE" != "MERGEABLE" ]; then
        complete_status "${RED}✗${NC} PR cannot be merged"
        echo
        echo -e "${RED}Error:${NC} PR #$PR_NUMBER has conflicts or failing checks"
        echo "PR URL: $PR_URL"
        echo "Please resolve conflicts manually"
        exit 1
    fi
    complete_status "${GREEN}✓${NC} PR is mergeable"
fi

# Show PR URL and countdown
if [ "$WHAT_IF" = false ]; then
    # Stop timer during countdown
    stop_timer
    echo
    echo -e "${BOLD}Pull Request Ready${NC}"
    echo -e "${BLUE}$PR_URL${NC}"
    echo
    echo "Auto-merging in 90 seconds... (Press Ctrl+C or 'n' to cancel)"
    echo

    # 90 second countdown with ability to cancel
    for i in {90..1}; do
        echo -ne "${ERASE_LINE}\rMerging in ${i}s... [Cancel: Ctrl+C or type 'n']"

        # Check for user input (non-blocking)
        if read -t 1 -n 1 -r response; then
            if [[ "$response" =~ ^[Nn]$ ]]; then
                echo
                echo
                echo -e "${YELLOW}⊘${NC} Merge cancelled by user"
                echo "PR #$PR_NUMBER remains open: $PR_URL"
                exit 0
            fi
        fi
    done
    echo
    echo

    # Restart timer for merge operations
    start_timer
fi

# Merge pull request
update_status "  Merging PR #$PR_NUMBER..."
log_verbose "Attempting to merge PR #$PR_NUMBER"
if [ "$WHAT_IF" = true ]; then
    complete_status "${YELLOW}⊙${NC} Would merge PR into $MAIN_BRANCH"
else
    log_verbose "Running gh pr merge $PR_NUMBER --merge --delete-branch=false"
    if gh pr merge "$PR_NUMBER" --merge --delete-branch=false &> /dev/null; then
        complete_status "${GREEN}✓${NC} Merged PR #$PR_NUMBER"
        log_verbose "PR merged successfully"
    else
        complete_status "${RED}✗${NC} Failed to merge PR"
        echo
        echo -e "${RED}Error:${NC} Failed to merge PR #$PR_NUMBER"
        echo "You may need to resolve conflicts or check PR status"
        echo "PR URL: $PR_URL"
        exit 1
    fi
fi

# Pull the merged changes
update_status "  Pulling merged changes..."
if [ "$WHAT_IF" = true ]; then
    complete_status "${YELLOW}⊙${NC} Would pull merged changes from $MAIN_BRANCH"
else
    if git pull origin "$MAIN_BRANCH" &> /dev/null; then
        complete_status "${GREEN}✓${NC} Pulled merged changes"
    else
        complete_status "${RED}✗${NC} Failed to pull merged changes"
        exit 1
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
if [ "$WHAT_IF" = true ]; then
    echo -e "${YELLOW}DRY-RUN:${NC} No changes were made"
    echo
    echo "Would have performed:"
    echo "  • Fetched latest from origin"
    echo "  • Verified remote branch origin/$BRANCH_NAME exists"
    echo "  • Pulled latest $MAIN_BRANCH"
    echo "  • Created PR: origin/$BRANCH_NAME → $MAIN_BRANCH"
    echo "  • Checked PR mergability"
    echo "  • Shown PR URL with 90-second countdown"
    echo "  • Merged PR into $MAIN_BRANCH"
    echo "  • Pulled merged changes"
    echo "  • Left remote branch intact"
else
    echo -e "${GREEN}✓${NC} Branch 'origin/$BRANCH_NAME' successfully integrated into $MAIN_BRANCH"
    echo -e "${GREEN}✓${NC} PR #$PR_NUMBER merged and changes pulled"
    echo
    echo "Remote branch 'origin/$BRANCH_NAME' remains intact."
    echo "Use purge-stale-claude-code-web-branches.sh to clean up when ready."
fi
echo

exit 0
