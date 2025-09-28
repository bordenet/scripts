#!/usr/bin/env bash
set -euo pipefail

# --- Usage ---
if [ $# -ne 1 ]; then
  echo "Usage: $0 <N>"
  echo "Squashes commits 2..N into a single commit, leaving commit 1 as-is."
  exit 1
fi

SQUASH_UNTIL=$1   # number of commits to squash (starting with #2)
REPO_URL="https://github.com/bordenet/RecipeArchive.git"
WORKDIR="recipearchive-squash"
BRANCH="main"
TMPFILE="$(mktemp)"

abort() {
  echo "❌ Error: $*" >&2
  exit 1
}

# --- Step 1: Fresh clone ---
if [ -d "$WORKDIR" ]; then
  abort "Workdir $WORKDIR already exists. Please remove or rename it."
fi

echo "📥 Cloning repo..."
git clone "$REPO_URL" "$WORKDIR" || abort "git clone failed"
cd "$WORKDIR"

git checkout "$BRANCH" || abort "Failed to checkout branch $BRANCH"

# --- Step 2: Verify commit count ---
TOTAL_COMMITS=$(git rev-list --count HEAD)
echo "✅ Repo has $TOTAL_COMMITS commits."

if [ "$TOTAL_COMMITS" -lt "$SQUASH_UNTIL" ]; then
  abort "Not enough commits ($TOTAL_COMMITS) to squash up to $SQUASH_UNTIL."
fi

# --- Step 3: Prepare interactive rebase ---
echo "📝 Preparing rebase plan..."
git rebase -i --root --quiet || true

TODO_FILE="$(git rev-parse --git-path rebase-merge/git-rebase-todo 2>/dev/null || true)"
if [ ! -f "$TODO_FILE" ]; then
  abort "Could not find git rebase todo file."
fi

# --- Step 4: Rewrite rebase plan ---
i=0
while IFS= read -r line; do
  i=$((i+1))
  if [ $i -eq 1 ]; then
    # Keep first commit
    echo "$line" >> "$TMPFILE"
  elif [ $i -le "$SQUASH_UNTIL" ]; then
    # Squash commits 2..N
    echo "${line/pick/squash}" >> "$TMPFILE"
  else
    # Leave remaining commits unchanged
    echo "$line" >> "$TMPFILE"
  fi
done < "$TODO_FILE"

mv "$TMPFILE" "$TODO_FILE"

# --- Step 5: Run the rebase ---
echo "🚀 Starting rebase (squashing commits 2-$SQUASH_UNTIL)..."
if ! git rebase --continue; then
  echo "⚠️ Rebase paused due to conflicts. Resolve manually with:"
  echo "   git status"
  echo "   git add <fixed-files>"
  echo "   git rebase --continue"
  exit 1
fi

# --- Step 6: Verify ---
NEW_TOTAL=$(git rev-list --count HEAD)
echo "🎉 Rebase complete!"
echo "Old commit count: $TOTAL_COMMITS"
echo "New commit count: $NEW_TOTAL"
echo "Check history with: git log --oneline --graph --decorate --all"

# --- Step 7: Push instructions ---
echo "👉 To push this cleaned history, run:"
echo "   git push origin $BRANCH --force"
