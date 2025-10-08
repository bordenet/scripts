#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: enumerate_gh_repos.sh
#
# Description: This script enumerates repositories within a specified GitHub
#              Enterprise instance and organization. For each repository, it
#              clones the repository, counts the lines of code, and retrieves
#              the last push timestamp. The results are logged to a file.
#
# Usage: ./enumerate_gh_repos.sh <GitHub_API_Token>
#
# Arguments:
#   <GitHub_API_Token>: A personal access token with sufficient permissions to
#                       access the repositories in the specified GitHub
#                       Enterprise instance.
#
# Configuration:
#   Before running, update the GITHUB_URL and GITHUB_ORG variables within
#   this script.
#
# Dependencies: curl, jq, git, mktemp
#
# Author: Matt Bordenet (Original), Gemini (Enhancements)
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# !!! IMPORTANT !!!
# UPDATE THESE VARIABLES BEFORE RUNNING THE SCRIPT
GITHUB_URL="GHE-URL-HERE"
GITHUB_ORG="ORG-NAME-HERE"
LOG_FILE="github_enum.log"

# --- Functions ---

# Function to print usage information and exit.
usage() {
    echo "Usage: $0 <GitHub API Token>"
    echo "Please provide a GitHub API token as an argument."
    exit 1
}

# Function to clean up the temporary directory on script exit.
cleanup() {
    echo "Cleaning up temporary directory: $TEMP_DIR"
    rm -rf "$TEMP_DIR"
}

# Function to log messages to both the console and the log file.
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S')\t$1" | tee -a "$LOG_FILE"
}

# Function to handle errors and exit the script.
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Function to retrieve the list of repository clone URLs for the organization.
get_repos() {
    log "Fetching repository list for organization: $GITHUB_ORG"
    curl -s -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_URL/api/v3/orgs/$GITHUB_ORG/repos" | jq -r '.[].clone_url'
}

# Function to get the timestamp of the last push for a given repository.
get_latest_push() {
    local repo_url=$1
    local repo_name=$(basename "$repo_url" .git)
    log "Getting last push time for: $repo_name"
    curl -s -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_URL/api/v3/repos/$GITHUB_ORG/$repo_name" | jq -r '.pushed_at'
}

# Function to clone a repository and count its lines of code.
count_loc() {
    local repo_url=$1
    local repo_name=$(basename "$repo_url" .git)
    local clone_dir="$TEMP_DIR/$repo_name"
    log "Cloning $repo_name to $clone_dir"
    git clone "$repo_url" "$clone_dir" --quiet || error_exit "Failed to clone $repo_url"
    log "Counting lines of code for: $repo_name"
    # This command finds all files, excludes dotfiles/dot-directories, and counts their lines.
    find "$clone_dir" -type f ! -path "*/\.*" -exec wc -l {} + | awk '{total += $1} END {print total}'
}

# --- Main Script ---

# Start timer
start_time=$(date +%s)

# Check for API token argument.
if [ "$#" -ne 1 ]; then
    usage
fi
GITHUB_TOKEN=$1

# Create a temporary directory for cloning repositories.
TEMP_DIR=$(mktemp -d)
# Ensure the cleanup function is called on script exit.
trap cleanup EXIT

log "--- Starting GitHub Repository Enumeration ---"

# Get the list of repositories.
repos=$(get_repos) || error_exit "Failed to get repositories. Check URL, org, and token."

if [ -z "$repos" ]; then
    error_exit "No repositories found. Check organization name and permissions."
fi

# Log the header for the output data.
log "repo\tlines-of-code\tlast-push"

# Loop through each repository, gather data, and log it.
for repo in $repos; do
    loc=$(count_loc "$repo")
    latest_push=$(get_latest_push "$repo")
    log "$repo\t$loc\t$latest_push"
done

log "--- GitHub enumeration script completed ---"

# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
log "Total execution time: ${execution_time} seconds"
echo "Process complete. Results are in ${LOG_FILE}"