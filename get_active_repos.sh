#!/bin/bash

GITHUB_ORG="ORG-NAME-HERE"
GITHUB_ORG_URL="https://GHE-URL-HERE/$GITHUB_ORG/"
GITHUB_API_URL="https://GHE-URL-HERE/api/v3"
GITHUB_TOKEN="TOKEN_HERE"

# Get the current date and the date one year ago
CURRENT_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
ONE_YEAR_AGO=$(date -u -v-1y +"%Y-%m-%dT%H:%M:%SZ")

# Function to count lines of code in a repository
count_lines_of_code() {
    repo=$1
    git clone --quiet $GITHUB_ORG_URL$repo temp_active_repo 2>/dev/null
    cd temp_active_repo 2>/dev/null
    lines_of_code=$(git ls-files 2>/dev/null | xargs wc -l 2>/dev/null | tail -n 1 | awk '{print $1}' 2>/dev/null)
    cd .. 2>/dev/null
    rm -rf temp_active_repo 2>/dev/null
    echo $lines_of_code
}

# Function to check if a repository has changed in the past year
check_repo_activity() {
  local repo=$1

#  echo "Checking activity for repository: $repo"
  local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
    "$GITHUB_API_URL""/repos/""$GITHUB_ORG""/""$repo" || { echo "Failed to fetch data for $repo"; return; })
#  echo "Response for $repo: $response"

  local last_pushed=$(echo "$response" | jq -r '.pushed_at')
#  echo "Last pushed date for $repo: $last_pushed"

  if [[ "$last_pushed" > "$ONE_YEAR_AGO" ]]; then

    # Fetch lines of code for the repository
    local lines_of_code=$(count_lines_of_code $repo)
    echo -e "$repo\t$last_pushed\t$lines_of_code"
  fi
}

# Function to fetch all repositories with pagination
fetch_repos() {
    page=1
    repos=()

    orgs_url="$GITHUB_API_URL""/orgs/"$GITHUB_ORG"/repos"

    while :; do
        response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$orgs_url""?per_page=100&page=$page")
        repo_names=$(echo "$response" | jq -r '.[].name')
        if [ -z "$repo_names" ]; then
            break
        fi
        repos+=($repo_names)
        ((page++))
    done
    echo "${repos[@]}"
}

echo "Active repositories -- changes within the past year:"

# Get all repositories
#repos=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "$GITHUB_API_URL/orgs/$GITHUB_ORG/repos" | jq -r '.[].clone_url' 2>/dev/null)
repos=$(fetch_repos)

# Check each repository for activity
echo -e "Repo\tLast-Pushed\tLoC"
for repo in $repos; do
  check_repo_activity $repo
done

echo "Done!"
