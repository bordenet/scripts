#!/bin/bash

set -euo pipefail

# Function to print usage
usage() {
  echo "Usage: $0 <path1> <path2> ... <pathN>"
  echo "Example: $0 tools/foo tools/bar.exe"
  exit 1
}

# Check for arguments
if [ "$#" -lt 1 ]; then
  echo "Error: No paths provided."
  usage
fi

# Check for git-filter-repo
if ! command -v git-filter-repo &> /dev/null; then
  echo "Error: git-filter-repo is not installed."
  echo "Install it via: pip install git-filter-repo"
  exit 2
fi

# Check if inside a git repo
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  echo "Error: This script must be run inside a Git repository."
  exit 3
fi

# Confirm user wants to proceed
echo "WARNING: This will rewrite Git history and remove the following paths:"
for path in "$@"; do
  echo "  - $path"
done
echo "Make sure you have a backup and understand the consequences."
read -p "Proceed? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 4
fi

# Create a temporary file with paths to remove
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

for path in "$@"; do
  echo "$path" >> "$TMPFILE"
done

# Run git-filter-repo
git filter-repo --force --paths-from-file "$TMPFILE"

echo "✅ Git history scrubbed. Don't forget to force-push if this is a shared repo."

