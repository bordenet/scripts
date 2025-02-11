#!/bin/bash

# Script to enumerate an Enterprise GitHub instance and gather lines of code for each repo
# Author: Matt Bordenet
# Date: 21 Aug 2024
# Version: 1.0

# Function to print usage
usage() {
    echo "Usage: $0 <GitHub API Token>"
    exit 1
}

# Check if the correct number of arguments is provided
if [ "$#" -ne 1 ]; then
    usage
fi

# Variables
GITHUB_TOKEN=$1
GITHUB_URL="GHE-URL-HERE"
GITHUB_ORG="ORG-NAME-HERE"
TEMP_DIR=$(mktemp -d)
LOG_FILE="github_enum.log"

# Function to clean up temporary files
cleanup() {
    rm -rf "$TEMP_DIR"
}

# Trap to ensure cleanup is done on script exit
trap cleanup EXIT

# Function to log messages
log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S')\t$1" | tee -a "$LOG_FILE"
}

# Function to handle errors
error_exit() {
    log "Error: $1"
    exit 1
}

# Function to get repositories
get_repos() {
    curl -s -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_URL/api/v3/orgs/$GITHUB_ORG/repos" | jq -r '.[].clone_url'
}

# Function to get the latest push timestamp
get_latest_push() {
    local repo_url=$1
    local repo_name=$(basename "$repo_url" .git)
    curl -s -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_URL/api/v3/repos/$GITHUB_ORG/$repo_name" | jq -r '.pushed_at'  2>/dev/null
}

# Function to count lines of code
count_loc() {
    local repo_url=$1
    local repo_name=$(basename "$repo_url" .git)
    git clone "$repo_url" "$TEMP_DIR/$repo_name" 2>/dev/null || error_exit "Failed to clone $repo_url"
    find "$TEMP_DIR/$repo_name" -type f ! -path "*/\.*" -exec wc -l {} + | awk '{total += $1} END {print total}'  2>/dev/null
}

# Main script
log "Starting GitHub enumeration script"

repos=$(get_repos) || error_exit "Failed to get repositories"

log "repo\tlines-of-code\tlast-push"
for repo in $repos; do
#    log "$repo"
    loc=$(count_loc "$repo") || error_exit "Failed to count lines of code for $repo"
    latest_push=$(get_latest_push "$repo") || error_exit "Failed to get latest push timestamp for $repo"
    log "$repo\t$loc\t$latest_push"
done

log "GitHub enumeration script completed"
