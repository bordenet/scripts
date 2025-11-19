#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: reset-all-repos.sh
#
# Description: This script automates the process of resetting multiple Git
#              repositories to match their remote main/master branch. It scans
#              a specified directory for Git repositories and performs a hard
#              reset, discarding all local changes. Features include
#              interactive confirmation, a progress bar, and time estimation.
#
# Usage: ./reset-all-repos.sh [options] [directory_path]
#
# Arguments:
#   directory_path:   Target directory to search for repositories.
#                     Defaults to the current directory.
#
# Options:
#   --what-if:        DEFAULT BEHAVIOR. Show what would happen without executing.
#   --force:          REQUIRED to actually execute the reset.
#   --help:           Show this help message.
#
# WARNING: This script performs a hard reset and will discard ALL local
#          changes in the repositories it processes. Use with EXTREME caution.
#
# Author: Matt J Bordenet
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    reset-all-repos.sh - Reset multiple Git repositories to remote state

SYNOPSIS
    reset-all-repos.sh [OPTIONS] [DIRECTORY]

DESCRIPTION
    Automates the process of resetting multiple Git repositories to match their
    remote main/master branch. Scans a specified directory for Git repositories
    and performs a hard reset, discarding all local changes. Features include
    interactive confirmation, a progress bar, and time estimation.

    WARNING: This script performs a hard reset and will discard ALL local
             changes in the repositories it processes. Use with EXTREME caution.

OPTIONS
    --what-if
        DEFAULT BEHAVIOR. Show what would happen without executing.

    -f, --force
        REQUIRED to actually execute the reset. Includes final confirmation prompt.

    -h, --help
        Display this help message and exit.

ARGUMENTS
    DIRECTORY
        Target directory to search for repositories. Default: current directory

PLATFORM
    Cross-platform (macOS, Linux, WSL)

DEPENDENCIES
    • git - For repository operations
    • find - For locating repositories
    • date - For timing calculations

EXAMPLES
    # Preview what would be reset (default behavior)
    ./reset-all-repos.sh

    # Preview with specific directory
    ./reset-all-repos.sh ~/GitHub

    # Actually execute the reset (requires confirmation)
    ./reset-all-repos.sh --force

    # Reset specific directory
    ./reset-all-repos.sh --force ~/GitHub

BEHAVIOR
    Default Mode (--what-if):
        • Shows all repositories that would be affected
        • Displays uncommitted changes count
        • No modifications made

    Force Mode (--force):
        • Requires final confirmation
        • Performs git fetch origin
        • Executes git reset --hard origin/[main|master]
        • Runs git clean -fdx (removes untracked files)

OUTPUT
    Creates a log file: ./git_reset.log

NOTES
    This script defaults to --what-if mode to prevent accidental data loss.
    You must explicitly use --force to execute the reset operations.

AUTHOR
    Matt J Bordenet

SEE ALSO
    git-reset(1), git-clean(1), git-fetch(1)

EOF
    exit 0
}

# --- Script Setup ---
start_time=$(date +%s)

# Parse command line arguments
WHAT_IF="true"  # DEFAULT to what-if mode
FORCE=false
SEARCH_DIR="."

while [[ $# -gt 0 ]]; do
  case $1 in
    --what-if)
      WHAT_IF="true"
      shift
      ;;
    -f|--force)
      WHAT_IF=""
      FORCE=true
      shift
      ;;
    -h|--help)
      show_help
      ;;
    -*)
      echo "Unknown option: $1"
      echo "Use --help for usage information"
      exit 1
      ;;
    *)
      SEARCH_DIR="$1"
      shift
      ;;
  esac
done

# Set log file
LOG_FILE="./git_reset.log"

# ANSI color codes
LIGHT_BLUE='\033[1;34m'
BRIGHT_RED='\033[1;31m'
DARK_RED='\033[0;31m'
DARK_GRAY='\033[0;90m'
YELLOW='\033[33m'
WHITE_BACKGROUND='\033[47m'
BOLD='\033[1m'
RESET='\033[0m'
CURSOR_UP='\033[1A'
CURSOR_HOME='\033[0G'
ERASE_LINE='\033[2K'

# --- Functions ---

# Formats time in minutes and seconds.
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    printf "%02d:%02d" $minutes $remaining_seconds
}

# Logs a message to the log file.
log_message() {
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" >> "$LOG_FILE"
}

# Resets a single git repository.
reset_git_repo() {
  local repo_path=$1
  log_message "Processing repository: $repo_path"

  if [ -d "$repo_path/.git" ]; then
    if pushd "$repo_path" > /dev/null; then
      log_message "Entered directory: $repo_path"

      # Determine the default branch (main or master)
      branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's|^refs/remotes/origin/||' 2>/dev/null || echo "main")

      # Fetch and reset to the correct branch
      git fetch origin >/dev/null
      git reset --hard "origin/$branch" >/dev/null
      git clean -fdx >/dev/null

      popd > /dev/null
      return 0
    else
      log_message "Failed to enter directory: $repo_path"
      return 1
    fi
  else
    log_message "Not a git repository: $repo_path"
    return 1
  fi
}

# Displays a progress bar.
display_gas_gauge() {
  local current=$1
  local total=$2
  local width=50
  local filled=$((current * width / total))
  local empty=$((width - filled))
  local gauge=$(printf "%${filled}s" | tr ' ' '#')
  local spaces=$(printf "%${empty}s" | tr ' ' ' ')
  printf "[%s%s] %d%%" "$gauge" "$spaces" $((current * 100 / total))
}

# --- Main Execution ---

# Create or clear the log file.
> "$LOG_FILE"

log_message "Starting git reset script in directory: $SEARCH_DIR"

# Find and count git repositories.
repo_list=$(find "$SEARCH_DIR" -type d -name ".git")
repo_count=$(echo "$repo_list" | wc -l)

# What-if mode (default)
if [ "$WHAT_IF" = "true" ]; then
  echo "🔎 WHAT-IF MODE (default behavior)"
  echo ""
  echo "Would reset $repo_count git repositories in: $SEARCH_DIR"
  echo ""
  echo "📋 Repositories that would be affected:"
  while read -r git_dir; do
    repo_dir=$(dirname "$git_dir")
    echo "  - $repo_dir"

    # Show status if possible
    if pushd "$repo_dir" > /dev/null 2>&1; then
      branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|^refs/remotes/origin/||' || echo "main")
      uncommitted=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
      if [ "$uncommitted" -gt 0 ]; then
        echo "    ⚠️  Has $uncommitted uncommitted change(s)"
      fi
      popd > /dev/null
    fi
  done <<< "$repo_list"
  echo ""
  echo "⚠️  No changes made. Use --force to actually execute the reset."
  echo "⚠️  WARNING: --force will DISCARD ALL LOCAL CHANGES!"
  exit 0
fi

# Force mode - prompt for final confirmation
if [ "$FORCE" = true ]; then
  echo -e "${BOLD}${DARK_RED}${WHITE_BACKGROUND}⚠️  EXECUTING HARD RESET (--force mode) ⚠️${RESET}"
  echo -e "${BOLD}${BRIGHT_RED}This will discard all local changes in $repo_count git repositories.${RESET}"
  echo -e "${YELLOW}Final confirmation - Are you absolutely sure? [y/N]${RESET} "
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "Operation cancelled."
      exit 0
  fi
fi

# Display the total count before starting.
printf "\033[2J"  # Clear the screen
printf "\033[H"   # Move cursor to the top left corner
printf "${DARK_RED}${WHITE_BACKGROUND}Total repositories to reset: %d${RESET}\n" "$repo_count"

repo_index=0
time_per_repo=0
estimated_time=""

# Process each repository.
while read -r git_dir; do
  repo_dir=$(dirname "$git_dir")
  repo_index=$((repo_index + 1))
  iteration_start=$(date +%s)
  
  # Calculate and display estimated time.
  if [ $repo_index -gt 5 ]; then
    current_time=$(date +%s)
    elapsed_time=$((current_time - start_time))
    time_per_repo=$((elapsed_time / repo_index))
    remaining_repos=$((repo_count - repo_index))
    estimated_seconds=$((time_per_repo * remaining_repos))
    estimated_time=" - Est. remaining: $(format_time $estimated_seconds)"
  fi
  
  # Update progress display.
  printf "\033[H"
  printf "${ERASE_LINE}Resetting repo ${LIGHT_BLUE}%d/%d${RESET}: ${DARK_GRAY}%s${RESET}${YELLOW}\t%s${RESET}\n" "$repo_index" "$repo_count" "$estimated_time" "$repo_dir"
  display_gas_gauge "$repo_index" "$repo_count"
  printf "\n"
  
  reset_git_repo "$repo_dir"
done <<< "$repo_list"

# --- Completion ---
end_time=$(date +%s)
runtime=$((end_time - start_time))

printf "${CURSOR_HOME}${ERASE_LINE}Done!\n"
printf "${ERASE_LINE}Git reset script completed in %d seconds.\n" "$runtime"
log_message "Script completed in $runtime seconds."