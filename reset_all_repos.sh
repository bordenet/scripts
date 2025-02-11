#!/bin/bash
# reset_all_repos.sh
# Script to reset multiple git repositories to the main branch on the remote
# Purpose: Scan GitHub repository clones, reset contents, and keep them updated.
# Description: I don't make a lot of code changes, but I want to stay up-to-date
# Docs: N/A
# Author: Matt Bordenet
# Usage: ./reset_all_repos.sh [-f|--force] <directory_path>

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

      git clean -f 2>/dev/null | grep -v "Removing git_reset.log"
      #git rebase 2>/dev/null | grep -v 'Current branch main is up to date.' | grep -v 'Current branch master is up to date'
      git pull | grep -v 'Already up to date.'

      if git status --porcelain | grep -q "^ M"; then
          log_message "WARNING: Uncommitted changes after reset in $repo_path.  These were overwritten."
      fi

      if git status --porcelain | grep -q "^??"; then
          log_message "WARNING: Untracked files after reset in $repo_path. These were not removed."
      fi

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
  read -p "This script will revert all local changes. Are you sure you want to do this? [Y/n] " response
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

find "$SEARCH_DIR" -type d -name ".git" | while read -r git_dir; do
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
  reset_git_repo "$repo_dir"
  
  # Update time per repo calculation after each iteration
  iteration_end=$(date +%s)
  iteration_time=$((iteration_end - iteration_start))
  if [ $repo_index -ge 5 ]; then
    time_per_repo=$(( (time_per_repo * (repo_index - 1) + iteration_time) / repo_index ))
  fi
done

end=$(date +%s)
runtime=$((end - start))

#printf "\033[1B"  # Move cursor down one line
printf "${CURSOR_HOME}${ERASE_LINE}{0} Done!"
printf "${ERASE_LINE}Git reset script completed in %d seconds.\n" "$runtime"
