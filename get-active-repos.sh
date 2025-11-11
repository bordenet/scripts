#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: get_active_repos.sh
#
# Description: This script identifies and lists active GitHub repositories
#              within a specified organization. A repository is considered
#              active if it has had a push within the last year. For each
#              active repository, it reports its name, the last push
#              timestamp, and the total lines of code.
#
# Usage: ./get_active_repos.sh
#
# Configuration:
#   Before running, update the GITHUB_ORG, GITHUB_API_URL, and GITHUB_TOKEN
#   variables within this script. The GITHUB_TOKEN requires sufficient
#   permissions to access the repositories in the specified GitHub
#   organization.
#
# Dependencies: curl, jq, git, date
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
# !!! IMPORTANT !!!
# UPDATE THESE VARIABLES BEFORE RUNNING THE SCRIPT
GITHUB_ORG="ORG-NAME-HERE"
GITHUB_API_URL="https://GHE-URL-HERE/api/v3"
GITHUB_TOKEN="TOKEN_HERE"

# --- Script Setup ---
start_time=$(date +%s)
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Calculate the date one year ago.
ONE_YEAR_AGO=$(date -u -v-1y +'%Y-%m-%dT%H:%M:%SZ')

echo "Finding active repositories in '$GITHUB_ORG' since $ONE_YEAR_AGO..."

# --- Functions ---

# Function to fetch all repositories for the organization, handling pagination.
fetch_all_repos() {
    local page=1
    local all_repos=()
    local repos_url="$GITHUB_API_URL/orgs/$GITHUB_ORG/repos"

    echo "Fetching all repositories for organization: $GITHUB_ORG"
    while :; do
        response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$repos_url?per_page=100&page=$page")
        repo_names=$(echo "$response" | jq -r '.[].name')

        if [ -z "$repo_names" ]; then
            break
        fi
        all_repos+=($repo_names)
        ((page++))
    done
    echo "${all_repos[@]}"
}

# Function to count lines of code in a repository.
count_loc() {
    local repo_name=$1
    local repo_url="https://x-access-token:$GITHUB_TOKEN@GHE-URL-HERE/$GITHUB_ORG/$repo_name.git"
    local clone_dir="$TEMP_DIR/$repo_name"

    echo "Cloning $repo_name to count lines of code..."
    git clone --quiet "$repo_url" "$clone_dir"
    
    # Using git ls-files to respect .gitignore, then counting lines.
    lines_of_code=$(cd "$clone_dir" && git ls-files | xargs wc -l | tail -n 1 | awk '{print $1}')
    
    echo "$lines_of_code"
}

# --- Main Script ---

# Get all repositories.
all_repos=$(fetch_all_repos)

if [ -z "$all_repos" ]; then
    echo "Error: No repositories found for organization '$GITHUB_ORG'. Check configuration and token permissions."
    exit 1
fi

echo "Found $(echo "$all_repos" | wc -w | xargs) repositories. Checking for activity..."
echo -e "\nRepo\tLast-Pushed\tLines-of-Code"

# Check each repository for activity.
for repo in $all_repos; do
    echo "Checking activity for: $repo"
    response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_API_URL/repos/$GITHUB_ORG/$repo")
    last_pushed=$(echo "$response" | jq -r '.pushed_at')

    if [[ "$last_pushed" > "$ONE_YEAR_AGO" ]]; then
        echo "  -> Active. Last push: $last_pushed"
        lines_of_code=$(count_loc "$repo")
        echo -e "$repo\t$last_pushed\t$lines_of_code"
    else
        echo "  -> Inactive. Last push: $last_pushed"
    fi
done

echo -e "\nDone!"

# --- Completion ---
end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo "Total execution time: ${execution_time} seconds"