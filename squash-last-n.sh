#!/usr/bin/env bash
#
# squash-last-n.sh
#
# Squashes the last <N> commits into a single new commit using git reset --soft.
# This method is non-interactive and avoids merge conflicts by taking the
# final state of the code from the newest commit in the range.
#
# Usage:
#   ./squash-last-n.sh <N> ["commit message"] [--force]
#
# Arguments:
#   <N>              - The number of recent commits to squash.
#   ["commit message"] - Optional. The message for the new squashed commit.
#                      Defaults to "Squash of last <N> commits".
#
# Options:
#   --what-if        - DEFAULT BEHAVIOR. Show what would happen without executing.
#   --force          - REQUIRED to actually execute the squash.
#
# Example:
#   # Preview what would happen (default --what-if behavior)
#   ./squash-last-n.sh 5
#
#   # Actually perform the squash (requires --force)
#   ./squash-last-n.sh 5 "Feat: Implement the new login flow" --force
#

set -euo pipefail

# Logs verbose messages when --verbose flag is set.
log_verbose() {
  if [ "$VERBOSE" = true ]; then
    echo "[VERBOSE] $1" >&2
  fi
}

# Parse arguments
WHAT_IF="true"  # DEFAULT to what-if mode
N=""
COMMIT_MSG=""
FORCE=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --what-if)
      WHAT_IF="true"
      shift
      ;;
    --force)
      WHAT_IF=""
      # shellcheck disable=SC2034  # FORCE documents intent, behavior controlled by other vars
      FORCE="true"
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    --help)
      echo "Usage: $0 <N> [\"Commit message\"] [--force]"
      echo ""
      echo "Arguments:"
      echo "  <N>              Number of recent commits to squash."
      echo "  [Commit message] Optional message for the new squashed commit."
      echo ""
      echo "Options:"
      echo "  --what-if        DEFAULT. Preview actions without executing."
      echo "  --force          REQUIRED to actually execute the squash."
      echo "  -v, --verbose    Enable verbose logging to show detailed operations."
      echo "  --help           Show this help message."
      echo ""
      echo "IMPORTANT: This script defaults to --what-if mode. Use --force to actually execute."
      exit 0
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [ -z "$N" ]; then
        N="$1"
      elif [ -z "$COMMIT_MSG" ]; then
        COMMIT_MSG="$1"
      else
        echo "Too many arguments"
        exit 1
      fi
      shift
      ;;
  esac
done

if [ -z "$N" ]; then
  echo "Usage: $0 <N> [\"Commit message\"] [--force]"
  echo "Use --help for more information"
  exit 1
fi

if [ -z "$COMMIT_MSG" ]; then
  COMMIT_MSG="Squash of last $N commits"
fi

# --- Validation ---
log_verbose "Validating N=$N is a positive integer"
if ! [[ "$N" =~ ^[0-9]+$ ]] || [ "$N" -lt 1 ]; then
  echo "❌ Error: N must be a positive integer." >&2
  exit 1
fi

log_verbose "Counting total commits in repository"
TOTAL_COMMITS=$(git rev-list --count HEAD)
log_verbose "Total commits: $TOTAL_COMMITS"
if [ "$N" -ge "$TOTAL_COMMITS" ]; then
    echo "❌ Error: N ($N) must be less than the total number of commits ($TOTAL_COMMITS)." >&2
    echo "Cannot squash all commits." >&2
    exit 1
fi

# --- What-if Mode (Default) ---
if [ "$WHAT_IF" = "true" ]; then
  echo "🔎 WHAT-IF MODE (default behavior)"
  echo ""
  echo "Would squash the last $N commits into one."
  echo "New commit message would be: \"$COMMIT_MSG\""
  echo "Current commit count: $TOTAL_COMMITS"
  echo "Resulting commit count would be: $(( TOTAL_COMMITS - N + 1 ))"
  echo ""
  echo "📋 Commits that would be squashed:"
  git log --oneline -n "$N"
  echo ""
  echo "⚠️  No changes made. Use --force to actually execute the squash."
  exit 0
fi

# --- Execution Mode (Requires --force) ---
echo "⚠️  EXECUTING SQUASH (--force mode)"
echo "You are about to squash the last $N commits into one."
echo "This will rewrite the history of the current branch."
read -rp "Final confirmation - Proceed? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo "🚀 Resetting HEAD~$N..."
log_verbose "Running git reset --soft HEAD~$N"
git reset --soft "HEAD~$N"
log_verbose "Reset complete, staging area preserved"

echo "📝 Committing squashed changes..."
log_verbose "Creating new commit with message: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"
log_verbose "Commit created successfully"

echo "🎉 Squash complete!"
echo "Check the new history with: git log --oneline -n 5"
