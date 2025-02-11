#!/bin/bash
# reset_all_repos.sh
# Script to reset multiple git repositories to the main branch on the remote
# Purpose: Scan GitHub repository clones, reset contents, and keep them updated.
# Description: I don't make a lot of code changes, but I want to stay up-to-date
# Docs: N/A
# Author: Matt Bordenet
# Usage: ./reset_all_repos.sh <directory_path>

start=$(date +%s)

# Set log file
log_file="./git_reset.log"

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

      git fetch origin 2>&1 | tee -a "$log_file"

      if git ls-remote --heads origin/main > /dev/null 2>&1; then
        if git reset --hard origin/main 2>&1 | tee -a "$log_file"; then
          log_message "Successfully reset: $repo_path"
          git pull origin main 2>&1 | tee -a "$log_file"
          log_message "Successfully pulled latest changes for: $repo_path"
        else
          log_message "Failed to reset: $repo_path"
          return 1
        fi
      else
        log_message "WARNING: 'main' branch not found on remote for $repo_path. Skipping."
        return 1
      fi

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

# Directory to search for git repositories
search_dir="${1:-.}"

# Create the log file or clear it if it exists
> "$log_file"

log_message "Starting git reset script..."

# Count the number of git repositories
repo_count=$(find "$search_dir" -type d -name ".git" | wc -l)

# Display the total count before starting
printf "\033[2J"  # Clear the screen
printf "\033[H"   # Move cursor to the top left corner
printf "Total repositories: %d\n" "$repo_count"

repo_index=0

# The new and improved loop!
find "$search_dir" -type d -name ".git" | while read -r git_dir; do
  repo_dir=$(dirname "$git_dir")
  repo_index=$((repo_index + 1))
  printf "\033[H"   # Move cursor to the top left corner
  printf "Total repositories: %d\n" "$repo_count"
  printf "\033[1B"  # Move cursor down one line
  printf "Resetting %d of %d: %s\n" "$repo_index" "$repo_count" "$repo_dir"
  reset_git_repo "$repo_dir"
done

end=$(date +%s)
runtime=$((end - start))

printf "\033[H"   # Move cursor to the top left corner
printf "Total repositories: %d\n" "$repo_count"
printf "\033[1B"  # Move cursor down one line
printf "Git reset script completed in %d seconds.\n" "$runtime"
