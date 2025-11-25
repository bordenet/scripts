#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Claude Code Web Branch Cleanup Tool
# Interactive deletion of stale Claude Code web branches with safety confirmations
# Platform: Cross-platform (macOS, Linux, WSL)
# -----------------------------------------------------------------------------


set -euo pipefail

set -uo pipefail

# Source library functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/purge-stale-branches-lib.sh
source "$SCRIPT_DIR/lib/purge-stale-branches-lib.sh"

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
DELETED_BRANCHES=()
SKIPPED_BRANCHES=()
FAILED_BRANCHES=()
ALL_MODE=false
WHAT_IF=false

# Array to store branch info: "name|timestamp|author|subject|location"
declare -a BRANCHES

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

# Helper functions (calculate_age, format_timestamp, delete_branch) now in lib/purge-stale-branches-lib.sh

# --- Help Function (now in lib/purge-stale-branches-lib.sh) ---

# --- Argument Parsing ---
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --all)
            ALL_MODE=true
            shift
            ;;
        --what-if)
            WHAT_IF=true
            shift
            ;;
        -*)
            echo -e "${RED}Error:${NC} Unknown option: $1"
            echo "Try '$0 --help' for more information"
            exit 1
            ;;
        *)
            echo -e "${RED}Error:${NC} Unexpected argument: $1"
            echo "Try '$0 --help' for more information"
            exit 1
            ;;
    esac
done

# --- Validation ---
start_time=$(date +%s)

# Clear screen and start
clear
if [ "$WHAT_IF" = true ]; then
    echo -e "${BOLD}Claude Code Branch Cleanup${NC} ${YELLOW}[DRY-RUN]${NC}\n"
else
    echo -e "${BOLD}Claude Code Branch Cleanup${NC}\n"
fi
start_timer

# Ensure timer stops on exit
trap stop_timer EXIT

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Not a git repository"
    echo
    echo -e "${RED}Error:${NC} Current directory is not a git repository"
    exit 1
fi

# Fetch latest from origin
echo -ne "  Fetching latest from origin..."
if git fetch origin &> /dev/null; then
    echo -e "\r${ERASE_LINE}${GREEN}✓${NC} Fetched latest from origin"
else
    echo -e "\r${ERASE_LINE}${YELLOW}⊘${NC} Could not fetch from origin (continuing with local data)"
fi

# Get current branch to protect it
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# --- Branch Discovery ---
echo -ne "  Discovering Claude Code branches..."

# Get local claude/* branches
while IFS='|' read -r refname timestamp author subject; do
    # Skip if this is the current branch
    [ "$refname" = "$CURRENT_BRANCH" ] && continue

    # Check if already in array (avoid duplicates)
    exists=false
    for i in "${!BRANCHES[@]}"; do
        if [[ "${BRANCHES[i]}" =~ ^"$refname"\| ]]; then
            # Update to mark as both
            BRANCHES[i]="${refname}|${timestamp}|${author}|${subject}|both"
            exists=true
            break
        fi
    done

    if [ "$exists" = false ]; then
        BRANCHES+=("${refname}|${timestamp}|${author}|${subject}|local")
    fi
done < <(git for-each-ref --format='%(refname:short)|%(committerdate:unix)|%(authorname)|%(subject)' refs/heads/claude/ 2>/dev/null)

# Get remote claude/* branches
while IFS='|' read -r refname timestamp author subject; do
    # Remove 'origin/' prefix for comparison
    short_name="${refname#origin/}"

    # Skip if this is the current branch
    [ "$short_name" = "$CURRENT_BRANCH" ] && continue

    # Check if already in array
    exists=false
    for i in "${!BRANCHES[@]}"; do
        if [[ "${BRANCHES[i]}" =~ ^"$short_name"\| ]]; then
            # Update to mark as both
            BRANCHES[i]="${short_name}|${timestamp}|${author}|${subject}|both"
            exists=true
            break
        fi
    done

    if [ "$exists" = false ]; then
        BRANCHES+=("${short_name}|${timestamp}|${author}|${subject}|remote")
    fi
done < <(git for-each-ref --format='%(refname:short)|%(committerdate:unix)|%(authorname)|%(subject)' refs/remotes/origin/claude/ 2>/dev/null)

echo -e "\r${ERASE_LINE}${GREEN}✓${NC} Found ${#BRANCHES[@]} Claude Code branches"
echo

# Check if any branches found
if [ ${#BRANCHES[@]} -eq 0 ]; then
    stop_timer
    echo "No Claude Code branches found"
    exit 0
fi

# Sort branches by timestamp (oldest first)
mapfile -t BRANCHES < <(printf '%s\n' "${BRANCHES[@]}" | sort -t'|' -k2 -n)

# --- Main Loop ---
if [ "$ALL_MODE" = true ]; then
    # Process all branches sequentially
    total=${#BRANCHES[@]}
    current=0

    for branch_info in "${BRANCHES[@]}"; do
        ((current++))
        IFS='|' read -r name timestamp author subject location <<< "$branch_info"

        age=$(calculate_age "$timestamp")
        formatted_date=$(format_timestamp "$timestamp")

        echo -e "${BOLD}[$current/$total]${NC} $name ${BLUE}($age)${NC}"
        echo "Last commit: $formatted_date"
        echo "Author: $author"
        echo "Message: $subject"
        echo "Location: $location"
        echo

        read -r -p "Delete this branch? [y/N]: " response
        echo

        if [[ "$response" =~ ^[Yy]$ ]]; then
            if [ "$WHAT_IF" = true ]; then
                echo -e "${YELLOW}⊙${NC} Would delete $location branch(es) [DRY-RUN]"
                DELETED_BRANCHES+=("$name ($age)")
            else
                if delete_branch "$name" "$location" "$WHAT_IF"; then
                    echo -e "${GREEN}✓${NC} Deleted $location branch(es)"
                    DELETED_BRANCHES+=("$name ($age)")
                else
                    echo -e "${RED}✗${NC} Failed to delete branch"
                    FAILED_BRANCHES+=("$name: deletion failed")
                fi
            fi
        else
            echo -e "${YELLOW}⊘${NC} Skipped $name"
            SKIPPED_BRANCHES+=("$name ($age)")
        fi
        echo
    done
else
    # Interactive menu mode
    while [ ${#BRANCHES[@]} -gt 0 ]; do
        echo "Select a branch to review for deletion:"

        # Display menu
        for i in "${!BRANCHES[@]}"; do
            IFS='|' read -r name timestamp author subject location <<< "${BRANCHES[$i]}"
            age=$(calculate_age "$timestamp")
            printf "%3d) %-50s ${BLUE}(%s)${NC} [%s]\n" "$((i+1))" "$name" "$age" "$location"
        done

        echo
        read -r -p "Enter number (or 'all'): " choice
        echo

        if [ "$choice" = "all" ]; then
            # Switch to all mode for remaining branches
            for branch_info in "${BRANCHES[@]}"; do
                IFS='|' read -r name timestamp author subject location <<< "$branch_info"

                age=$(calculate_age "$timestamp")
                formatted_date=$(format_timestamp "$timestamp")

                echo "Branch: $name"
                echo "Last commit: $age ($formatted_date)"
                echo "Author: $author"
                echo "Message: $subject"
                echo "Location: $location"
                echo

                read -r -p "Delete this branch? [y/N]: " response
                echo

                if [[ "$response" =~ ^[Yy]$ ]]; then
                    if [ "$WHAT_IF" = true ]; then
                        echo -e "${YELLOW}⊙${NC} Would delete $location branch(es) [DRY-RUN]"
                        DELETED_BRANCHES+=("$name ($age)")
                    else
                        if delete_branch "$name" "$location" "$WHAT_IF"; then
                            echo -e "${GREEN}✓${NC} Deleted $location branch(es)"
                            DELETED_BRANCHES+=("$name ($age)")
                        else
                            echo -e "${RED}✗${NC} Failed to delete branch"
                            FAILED_BRANCHES+=("$name: deletion failed")
                        fi
                    fi
                else
                    echo -e "${YELLOW}⊘${NC} Skipped $name"
                    SKIPPED_BRANCHES+=("$name ($age)")
                fi
                echo
            done
            break
        elif [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#BRANCHES[@]}" ]; then
            # Process single selection
            idx=$((choice - 1))
            IFS='|' read -r name timestamp author subject location <<< "${BRANCHES[$idx]}"

            age=$(calculate_age "$timestamp")
            formatted_date=$(format_timestamp "$timestamp")

            echo "Branch: $name"
            echo "Last commit: $age ($formatted_date)"
            echo "Author: $author"
            echo "Message: $subject"
            echo "Location: $location"
            echo

            read -r -p "Delete this branch? [y/N]: " response
            echo

            if [[ "$response" =~ ^[Yy]$ ]]; then
                if [ "$WHAT_IF" = true ]; then
                    echo -e "${YELLOW}⊙${NC} Would delete $location branch(es) [DRY-RUN]"
                    DELETED_BRANCHES+=("$name ($age)")
                    # Remove from array in dry-run too for consistent UX
                    unset 'BRANCHES[$idx]'
                    BRANCHES=("${BRANCHES[@]}")
                else
                    if delete_branch "$name" "$location" "$WHAT_IF"; then
                        echo -e "${GREEN}✓${NC} Deleted $location branch(es)"
                        DELETED_BRANCHES+=("$name ($age)")
                        # Remove from array
                        unset 'BRANCHES[$idx]'
                        BRANCHES=("${BRANCHES[@]}")
                    else
                        echo -e "${RED}✗${NC} Failed to delete branch"
                        FAILED_BRANCHES+=("$name: deletion failed")
                    fi
                fi
            else
                echo -e "${YELLOW}⊘${NC} Skipped $name"
                SKIPPED_BRANCHES+=("$name ($age)")
            fi
            echo
        else
            echo "Invalid selection"
            echo
        fi
    done
fi

# --- Summary ---
stop_timer
echo -ne "\033[1;1H${ERASE_LINE}"  # Clear timer line
echo

end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo
echo -e "${BOLD}Summary${NC} (${execution_time}s)"
echo

if [ "$WHAT_IF" = true ] && [ ${#DELETED_BRANCHES[@]} -gt 0 ]; then
    echo -e "${YELLOW}DRY-RUN: No changes were made${NC}"
    echo
fi

if [ ${#DELETED_BRANCHES[@]} -gt 0 ]; then
    if [ "$WHAT_IF" = true ]; then
        echo -e "${YELLOW}⊙ Would delete (${#DELETED_BRANCHES[@]}):${NC}"
    else
        echo -e "${GREEN}✓ Deleted (${#DELETED_BRANCHES[@]}):${NC}"
    fi
    for branch in "${DELETED_BRANCHES[@]}"; do
        echo "  • $branch"
    done
    echo
fi

if [ ${#SKIPPED_BRANCHES[@]} -gt 0 ]; then
    echo -e "${YELLOW}⊘ Skipped (${#SKIPPED_BRANCHES[@]}):${NC}"
    for branch in "${SKIPPED_BRANCHES[@]}"; do
        echo "  • $branch"
    done
    echo
fi

if [ ${#FAILED_BRANCHES[@]} -gt 0 ]; then
    echo -e "${RED}✗ Failed (${#FAILED_BRANCHES[@]}):${NC}"
    for branch in "${FAILED_BRANCHES[@]}"; do
        echo "  • $branch"
    done
    echo
    exit 1
fi

echo -e "${GREEN}✓${NC} Branch cleanup completed successfully!"
exit 0
