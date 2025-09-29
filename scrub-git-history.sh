#!/bin/bash

set -euo pipefail

# Function to print usage
usage() {
  echo "Usage: $0 [--file <path-to-file.txt>] [path1 path2 ...]"
  echo "You can provide paths directly or via a text file with one path per line."
  echo "Example: $0 tools/foo tools/bar.exe"
  echo "         $0 --file paths-to-remove.txt"
  exit 1
}

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

# Parse arguments
PATHS=()
if [[ "$#" -eq 0 ]]; then
  echo "Error: No paths provided."
  usage
fi

if [[ "$1" == "--file" ]]; then
  if [[ "$#" -ne 2 ]]; then
    echo "Error: --file requires exactly one argument."
    usage
  fi
  FILE="$2"
  if [[ ! -f "$FILE" ]]; then
    echo "Error: File '$FILE' not found."
    exit 4
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -n "$line" ]] && PATHS+=("$line")
  done < "$FILE"
else
  PATHS=("$@")
fi

if [[ "${#PATHS[@]}" -eq 0 ]]; then
  echo "Error: No valid paths found to remove."
  exit 5
fi

# Confirm user wants to proceed
echo "WARNING: This will rewrite Git history and remove the following paths:"
for path in "${PATHS[@]}"; do
  echo "  - $path"
done
echo "Make sure you have a backup and understand the consequences."
read -p "Proceed? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
  echo "Aborted."
  exit 6
fi

# Create a temporary file with paths to remove
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

for path in "${PATHS[@]}"; do
  echo "$path" >> "$TMPFILE"
done

# Run git-filter-repo
git filter-repo --force --paths-from-file "$TMPFILE"

echo "✅ Git history scrubbed. Don't forget to force-push if this is a shared repo."
