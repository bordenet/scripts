#!/bin/bash
#
# FILENAME: scrub-git-history.sh
#
# DESCRIPTION:
# This script uses 'git-filter-repo' to rewrite the Git repository history,
# permanently removing specified files or directories from all commits. It uses
# the '--invert-paths' and '--paths-from-file' options, which means it will
# *keep* all files *except* those listed as paths to be scrubbed.
#
# It is primarily designed to remove sensitive data or large artifacts that were
# accidentally committed to the repository history.
#
# IMPORTANT:
# - This operation **rewrites history**, which is destructive. DO NOT run this on
#   a shared repository without coordinating with your team. All collaborators
#   will need to rebase or re-clone after the rewrite.
# - Requires 'git-filter-repo' (install with: pip install git-filter-repo).
# - Always creates a backup branch and tag before proceeding with the rewrite.
#
# USAGE:
# $0 [--file <path-to-file.txt>] [--preview] [path1 path2 ...]
#
# OPTIONS:
# --file <file> : Path to a .txt file with one path/glob per line to be scrubbed.
# --preview     : Show a list of commits that touch the specified paths without
#                 actually rewriting the history.
# [path1 ...]   : Positional arguments for paths/globs to be scrubbed.
#
# EXIT CODES:
# 1: Usage error (missing arguments, invalid option).
# 2: 'git-filter-repo' not found.
# 3: Not inside a Git repository.
# 4: Input file not found.
# 5: Failed to create backup branch or branch already exists.
# 6: Aborted by user confirmation.
#
################################################################################

set -euo pipefail

# CONFIG
BACKUP_BRANCH="backup-before-scrub"
TAG_PREFIX="pre-scrub"
TMPFILE=$(mktemp)
# Trap to ensure the temporary file is cleaned up on exit, including errors
trap 'rm -f "$TMPFILE"' EXIT

# --- FUNCTIONS ----------------------------------------------------------------

# USAGE
usage() {
  echo "Usage: $0 [--file <path-to-file.txt>] [--preview] [path1 path2 ...]" >&2
  echo "" >&2
  echo "  --file <file>   : Path to a .txt file with one path/glob per line" >&2
  echo "  --preview       : Show affected commits without rewriting history" >&2
  echo "" >&2
  echo "Use 'man git-filter-repo' for path/glob format details." >&2
  exit 1
}

# --- CHECKS -------------------------------------------------------------------

# Check for git-filter-repo
if ! command -v git-filter-repo &> /dev/null; then
  echo "Error: git-filter-repo not installed. Try: pip install git-filter-repo" >&2
  exit 2
fi

# Check if inside a Git repository
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  echo "Error: Not inside a Git repository." >&2
  exit 3
fi

# Check for existing backup branch to prevent accidental overwrite
if git show-ref --verify --quiet "refs/heads/$BACKUP_BRANCH"; then
  echo "Error: Backup branch '$BACKUP_BRANCH' already exists. Please delete it or rename it before running." >&2
  exit 5
fi

# --- ARG PARSING --------------------------------------------------------------

PREVIEW=false
PATHS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --file)
      [[ "$#" -lt 2 ]] && { echo "Error: Missing argument for --file." >&2; usage; }
      FILE="$2"
      shift 2
      
      if [[ ! -f "$FILE" ]]; then
        echo "Error: File '$FILE' not found." >&2
        exit 4
      fi
      
      # Read file, trim whitespace, and skip empty lines
      while IFS= read -r line || [[ -n "$line" ]]; do
        # Use xargs to trim leading/trailing whitespace, then check if it's non-empty
        local_line=$(echo "$line" | xargs)
        [[ -n "$local_line" ]] && PATHS+=("$local_line")
      done < "$FILE"
      ;;
    --preview)
      PREVIEW=true
      shift
      ;;
    --) # End of options
      shift
      PATHS+=("$@")
      break
      ;;
    -*)
      echo "Error: Unknown option '$1'." >&2
      usage
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

if [[ "${#PATHS[@]}" -eq 0 ]]; then
  echo "Error: No paths provided. Use positional arguments or the --file option." >&2
  usage
fi

# --- CORE LOGIC ---------------------------------------------------------------

# WRITE PATHS TO TEMP FILE
for path in "${PATHS[@]}"; do
  echo "$path" >> "$TMPFILE"
done

echo "Paths to be scrubbed (i.e., files/directories to be REMOVED):"
for path in "${PATHS[@]}"; do
  echo "  - $path"
done
echo "---"

# PREVIEW MODE
if $PREVIEW; then
  echo "🔍 Previewing commits that touch the listed paths..."
  # List all commit info, then the files they touch, then grep for the target paths
  git log --pretty=format:'%h %an %s' --name-only | grep -Ff "$TMPFILE" | sort | uniq
  echo "---"
  echo "✅ Preview complete. No changes made to the repository history."
  exit 0
fi

# BACKUP
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "Attempting to create backup branch '$BACKUP_BRANCH' and tag..."

# Create backup branch
if ! git branch "$BACKUP_BRANCH"; then
    echo "Fatal Error: Failed to create backup branch '$BACKUP_BRANCH'." >&2
    exit 5
fi

# Create backup tag
BACKUP_TAG="${TAG_PREFIX}-$(date +%Y%m%d-%H%M%S)"
git tag -a "$BACKUP_TAG" -m "Backup before scrub at $CURRENT_COMMIT"

echo "✅ Backup created:"
echo "  - Branch: '$BACKUP_BRANCH' (on commit $CURRENT_COMMIT)"
echo "  - Tag: '$BACKUP_TAG'"
echo "---"

# CONFIRMATION
echo "⚠️ WARNING: This will permanently rewrite your repository history!"
read -r -p "Proceed with history rewrite using --invert-paths? (Type 'yes' to proceed): " confirm

if [[ "$confirm" != "yes" ]]; then
  echo "Aborted by user. You may delete the new backup branch/tag if you wish."
  exit 6
fi

# SCRUB
echo "Commencing history rewrite (this may take a while)..."
# The --invert-paths option tells git-filter-repo to KEEP all paths *EXCEPT*
# those listed in the temporary file.
git filter-repo --force --invert-paths --paths-from-file "$TMPFILE"

echo "---"
echo "✅ History rewritten successfully."
echo "Backup available on branch '$BACKUP_BRANCH' and tag '$BACKUP_TAG'."
echo "You can restore with: git checkout $BACKUP_BRANCH"
echo ""
echo "❗ NOTE: All collaborators must rebase or re-clone the repository."
