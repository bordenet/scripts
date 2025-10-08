#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: fetch-github-projects.sh
#
# Description: This script automates the process of updating all local Git
#              repositories located within a specified directory. It iterates
#              through each subdirectory, assumes it's a Git repository, and
#              performs a 'git pull' to fetch and merge changes from the
#              remote origin.
#
# Usage: ./fetch-github-projects.sh [directory]
#
#   - directory: The directory containing the Git repositories to update.
#                Defaults to '~/GitHub'.
#
# Dependencies: git
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
TARGET_DIR="${1:-$HOME/GitHub}"

# --- Main Script ---
start_time=$(date +%s)

echo "Starting to update all Git repositories in: $TARGET_DIR"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory not found: $TARGET_DIR"
    exit 1
fi

# Change to the target directory.
cd "$TARGET_DIR"

# Loop through each subdirectory.
for dir in */; do
    if [ -d "$dir/.git" ]; then
        echo "---"
        echo "Updating repository: $dir"
        pushd "$dir" > /dev/null
        git pull
        popd > /dev/null
    else
        echo "---"
        echo "Skipping non-Git directory: $dir"
    fi
done

echo "---"
echo "All repositories have been updated."

# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo "Total execution time: ${execution_time} seconds"