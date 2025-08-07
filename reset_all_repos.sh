#!/bin/bash

#==============================================================================
# reset_all_repos.sh
#==============================================================================
# 
# Description: Automated Git repository reset utility for multiple repositories
# 
# This script scans for Git repositories in a specified directory and resets
# each repository to match its remote main/master branch. It's designed to keep
# local repository clones synchronized with upstream changes without preserving
# local modifications.
#
# Usage: ./reset_all_repos.sh [-f|--force] [directory_path]
#
# Parameters:
#   -f, --force       Skip confirmation prompt and execute immediately
#   directory_path    Target directory to search for repositories (default: current)
#
# Prerequisites:
#   - Git installed and configured
#   - Valid Git repositories in target directory
#   - Network connectivity to remote repositories
#
# Features:
#   - Interactive confirmation prompt (unless --force is used)
#   - Progress tracking with visual gas gauge display
#   - Comprehensive logging to git_reset.log
#   - Estimated completion time calculation
#   - Color-coded terminal output
#   - Automatic detection of default branch (main/master)
#
# Author: Matt Bordenet
# Created: [Date]
# Modified: [Date]
#
# Warning: This script performs hard resets and will discard all local changes!
#          Use with caution and ensure important work is committed elsewhere.
#
#==============================================================================

start=$(date +%s)

# Parse command line arguments
FORCE=false
SEARCH_DIR="."

while [[ $# -gt 0 ]]; do
  case $1 in
    -f|--force)
      FORCE=true
      shift
      ;;
    *)
      SEARCH_DIR="$1"
      shift
      ;;
  esac
done

# Set log file
log_file="./git_reset.log"

# ANSI color codes 
LIGHT_BLUE='\033[1;34m'
BRIGHT_RED='\033[1;31m'
DARK_RED='\033[0;31m'
DARK_GRAY='\033[0;90m'
YELLOW='\033[33m'
WHITE_BACKGROUND='\033[47m'
BOLD='\033[1m'
RESET='\033[0m'
CURSOR_UP='\033[1A'      # Move cursor up one line
CURSOR_HOME='\033[0G'    # Move cursor to beginning of line
ERASE_LINE='\033[2K'     # Erase current line

# Function to format time in minutes and seconds
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    printf "%02d:%02d" $minutes $remaining_seconds
}

# Function to log messages
log_message() {
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" >> "$log_file"
}

# Function to reset a git repository
reset_git_repo() {
  local repo_path=$1
  log_message "Processing repository: $repo_path"

  if [ -d "$repo_path" ]; then
    if pushd "$repo_path" > /dev/null; then
      log_message "Entered directory: $repo_path"

      git pull origin main

      branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's|^refs/remotes/origin/||')

      # Fetch and reset to the correct branch
      git fetch origin >/dev/null
      git reset --hard origin/$branch >/dev/null

      popd > /dev/null
      return 0
    else
      log_message "Failed to enter directory: $repo_path"
      return 1
    fi
  else
    log_message "Directory does not exist: $repo_path"
    return 1
  fi
}

# Create the log file or clear it if it exists
> "$log_file" &>/dev/null

log_message "Starting git reset script..."

# Prompt for confirmation if not in force mode
if [ "$FORCE" = false ]; then
  echo -e "${BOLD}${DARK_RED}${WHITE_BACKGROUND}This script will revert all local changes. Are you sure you want to do this?${RESET} ${YELLOW}[Y/n]${RESET} "
  read -r response
  case "$response" in
    [nN]* )
      echo "No files changed"
      exit 0
      ;;
    * )
      # Continue with script
      ;;
  esac
fi

# Count the number of git repositories
repo_count=$(find "$SEARCH_DIR" -type d -name ".git" | wc -l)

# Display the total count before starting
printf "\033[2J"  # Clear the screen
printf "\033[H"   # Move cursor to the top left corner
printf "${DARK_RED}${WHITE_BACKGROUND}Total repositories to reset: %d${RESET}\n" "$repo_count"

repo_index=0
time_per_repo=0
estimated_time=""

# Function to display the gas gauge
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

# Use process substitution instead of pipe to avoid subshell variable scope issues
while read -r git_dir; do
  repo_dir=$(dirname "$git_dir")
  repo_index=$((repo_index + 1))
  iteration_start=$(date +%s)
  
  # Calculate and display estimated time after processing 10 repos
  if [ $repo_index -ge 10 ]; then
    current_time=$(date +%s)
    elapsed_time=$((current_time - start))
    time_per_repo=$((elapsed_time / repo_index))
    remaining_repos=$((repo_count - repo_index))
    estimated_seconds=$((time_per_repo * remaining_repos))
    estimated_time=" - Est. remaining: $(format_time $estimated_seconds)"
  fi
  
  printf "\033[H"   # Move cursor to the top left corner
  printf "${ERASE_LINE}Resetting repo ${LIGHT_BLUE}%d/%d${RESET}: ${DARK_GRAY}%s${RESET}${YELLOW}\t%s${RESET}\n" "$repo_index" "$repo_count" "$estimated_time" "$repo_dir"
  display_gas_gauge "$repo_index" "$repo_count"
  printf "\n"
  reset_git_repo "$repo_dir"

  # Introduce a random sleep between 0 and 2 seconds
  sleep_time=$((0 + RANDOM % 2))
  sleep "$sleep_time"       
  
  # Update time per repo calculation after each iteration
  iteration_end=$(date +%s)
  iteration_time=$((iteration_end - iteration_start))
  if [ $repo_index -ge 5 ]; then
    time_per_repo=$(( (time_per_repo * (repo_index - 1) + iteration_time) / repo_index ))
  fi
done < <(find "$SEARCH_DIR" -type d -name ".git")

end=$(date +%s)
runtime=$((end - start))

#printf "\033[1B"  # Move cursor down one line
printf "${CURSOR_HOME}${ERASE_LINE}{0} Done!"
printf "${ERASE_LINE}Git reset script completed in %d seconds.\n" "$runtime"
