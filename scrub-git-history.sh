#!/usr/bin/env bash
#
# FILENAME: scrub-git-history.sh
#
# PLATFORM: Cross-platform
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
VERBOSE=false  # Initialize early for use in checks
# Trap to ensure the temporary file is cleaned up on exit, including errors
trap 'rm -f "$TMPFILE"' EXIT

# --- FUNCTIONS ----------------------------------------------------------------

# Logs verbose messages when --verbose flag is set.
log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo "[VERBOSE] $1" >&2
  fi
}

# USAGE
usage() {
  echo "Usage: $0 [--file <path-to-file.txt>] [--preview] [--verbose] [path1 path2 ...]" >&2
  echo "" >&2
  echo "  --file <file>   : Path to a .txt file with one path/glob per line" >&2
  echo "  --preview       : Show affected commits without rewriting history" >&2
  echo "  --verbose       : Enable verbose logging to show detailed operations" >&2
  echo "" >&2
  echo "Use 'man git-filter-repo' for path/glob format details." >&2
  exit 1
}

# --- CHECKS -------------------------------------------------------------------

# Check for git-filter-repo
log_verbose "Checking for git-filter-repo installation"
if ! command -v git-filter-repo &> /dev/null; then
  echo "Error: git-filter-repo not installed. Try: pip install git-filter-repo" >&2
  exit 2
fi
log_verbose "git-filter-repo found"

# Check if inside a Git repository
log_verbose "Verifying inside a Git repository"
if ! git rev-parse --is-inside-work-tree &> /dev/null; then
  echo "Error: Not inside a Git repository." >&2
  exit 3
fi
log_verbose "Git repository verified"

# Check for existing backup branch to prevent accidental overwrite
log_verbose "Checking for existing backup branch: $BACKUP_BRANCH"
if git show-ref --verify --quiet "refs/heads/$BACKUP_BRANCH"; then
  echo "Error: Backup branch '$BACKUP_BRANCH' already exists. Please delete it or rename it before running." >&2
  exit 5
fi
log_verbose "No existing backup branch found"

# --- ARG PARSING --------------------------------------------------------------

PREVIEW=false
PATHS=()

while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
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
    -v|--verbose)
      VERBOSE=true
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
log_verbose "Current commit: $CURRENT_COMMIT"
echo "Attempting to create backup branch '$BACKUP_BRANCH' and tag..."

# Create backup branch
log_verbose "Creating backup branch: $BACKUP_BRANCH"
if ! git branch "$BACKUP_BRANCH"; then
    echo "Fatal Error: Failed to create backup branch '$BACKUP_BRANCH'." >&2
    exit 5
fi

# Create backup tag
BACKUP_TAG="${TAG_PREFIX}-$(date +%Y%m%d-%H%M%S)"
log_verbose "Creating backup tag: $BACKUP_TAG"
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
log_verbose "Running git-filter-repo with --invert-paths using temp file: $TMPFILE"
# The --invert-paths option tells git-filter-repo to KEEP all paths *EXCEPT*
# those listed in the temporary file.
git filter-repo --force --invert-paths --paths-from-file "$TMPFILE"
log_verbose "History rewrite completed"

echo "---"
echo "✅ History rewritten successfully."
echo "Backup available on branch '$BACKUP_BRANCH' and tag '$BACKUP_TAG'."
echo "You can restore with: git checkout $BACKUP_BRANCH"
echo ""
echo "❗ NOTE: All collaborators must rebase or re-clone the repository."
