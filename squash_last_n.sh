#!/usr/bin/env bash
#
# squash_last_n.sh
#
# Squashes the last <N> commits into a single new commit using git reset --soft.
# This method is non-interactive and avoids merge conflicts by taking the
# final state of the code from the newest commit in the range.
#
# Usage:
#   ./squash_last_n.sh <N> ["commit message"]
#
# Arguments:
#   <N>              - The number of recent commits to squash.
#   ["commit message"] - Optional. The message for the new squashed commit.
#                      Defaults to "Squash of last <N> commits".
#
# Example:
#   # Squash the last 5 commits into one
#   ./squash_last_n.sh 5 "Feat: Implement the new login flow"
#

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <N> [\"Commit message\"]"
  echo "  <N>              Number of recent commits to squash."
  echo "  [Commit message] Optional message for the new squashed commit."
  exit 1
fi

N=$1
COMMIT_MSG=${2:-"Squash of last $N commits"}

# --- Validation ---
if ! [[ "$N" =~ ^[0-9]+$ ]] || [ "$N" -lt 1 ]; then
  echo "❌ Error: N must be a positive integer." >&2
  exit 1
fi

TOTAL_COMMITS=$(git rev-list --count HEAD)
if [ "$N" -ge "$TOTAL_COMMITS" ]; then
    echo "❌ Error: N ($N) must be less than the total number of commits ($TOTAL_COMMITS)." >&2
    echo "Cannot squash all commits." >&2
    exit 1
fi

# --- Confirmation ---
echo "⚠️  You are about to squash the last $N commits into one."
echo "This will rewrite the history of the current branch."
read -rp "Proceed? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

# --- Execution ---
echo "🚀 Resetting HEAD~$N..."
git reset --soft "HEAD~$N"

echo "📝 Committing squashed changes..."
git commit -m "$COMMIT_MSG"

echo "🎉 Squash complete!"
echo "Check the new history with: git log --oneline -n 5"
