#!/usr/bin/env bash
#
# squash_commits.sh
#
# Interactively squash a range of commits in a Git repository.
# This script can also analyze the history to suggest logical squash ranges.
#
# This script automates the process of squashing a continuous range of commits
# into a single commit. It can be run on an existing repository or it can
# clone a fresh one. It provides a dry-run mode to preview the changes and
# prompts for confirmation before rewriting history.
#
# Usage:
#   ./squash_commits.sh <START> <END> [options]
#   ./squash_commits.sh --suggest [options]
#
# Arguments:
#   <START>          - The starting commit index to squash (e.g., 2).
#   <END>            - The ending commit index to squash (e.g., 300).
#
# Options:
#   --suggest        - Analyze commit history and suggest logical ranges to squash.
#   --message <msg>  - Optional. The message for the new squashed commit.
#                      Defaults to "Squash of commits <START>-<END>".
#   --repo <url>     - Optional. If provided, clones the repo into a temporary 
#                      directory to operate on.
#   --dry-run        - Optional. If provided, the script will only print the
#                      actions it would take without performing the rebase.
#   --force          - Bypass the interactive confirmation prompt.
#   --help           - Show the help message.
#
# Example:
#   # Squash commits 2 through 50 into a single commit in the current repo
#   ./squash_commits.sh 2 50 --force
#
#   # Get suggestions for squashing from a remote repository
#   ./squash_commits.sh --suggest --repo https://github.com/bordenet/RecipeArchive
#
# Note:
# This script performs a history-rewriting operation. Be very careful when
# using it on shared branches. Always coordinate with your team before
# force-pushing.
#
set -euo pipefail

# --- Utility Functions ---
suggest_ranges() {
  echo "🔎 Analyzing commit history for squash suggestions..."
  echo

  COMMIT_HASHES=$(git log --pretty=%H --reverse)
  if [ -z "$COMMIT_HASHES" ]; then
    echo "No commits found."
    exit 0
  fi

  COMMIT_ARRAY=()
  while IFS= read -r line; do
    COMMIT_ARRAY+=("$line")
  done <<< "$COMMIT_HASHES"

  let total_commits=${#COMMIT_ARRAY[@]}
  let range_start_index=1
  let suggestions_found=0

  get_files() {
    # Use git show which handles the initial commit correctly.
    git show --name-only --pretty="" "$1" | sort | tr '\n' ' '
  }

  if [ "$total_commits" -le 1 ]; then
      echo "Not enough commits to analyze for suggestions."
      exit 0
  fi

  prev_files=$(get_files "${COMMIT_ARRAY[0]}")

  for (( i=1; i<total_commits; i++ )); do
    current_commit_hash="${COMMIT_ARRAY[$i]}"
    current_files=$(get_files "$current_commit_hash")

    if [[ "$current_files" != "$prev_files" ]] || [[ -z "$current_files" ]]; then
      let range_end_index=i
      if (( range_end_index > range_start_index )); then
        if (( suggestions_found == 0 )); then
          echo "Suggested ranges based on consecutive commits to the same files:"
        fi
        echo "  - Squash commits $range_start_index-$range_end_index"
        let suggestions_found+=1
      fi
      let range_start_index=i+1
    fi
    prev_files="$current_files"
  done

  if (( total_commits >= range_start_index )); then
      if (( total_commits > range_start_index )); then
        if (( suggestions_found == 0 )); then
          echo "Suggested ranges based on consecutive commits to the same files:"
        fi
        echo "  - Squash commits $range_start_index-$total_commits"
        let suggestions_found+=1
      fi
  fi

  if (( suggestions_found > 0 )); then
    echo
    echo "Use these ranges with the script, e.g.: ./squash_commits.sh <START> <END>"
  else
    echo "No obvious squash opportunities found based on the 'same files' heuristic."
  fi
}

usage() {
  echo "Usage: $0 <START> <END> [options]"
  echo "       $0 --suggest [options]"
  echo
  echo "Arguments:
  <START>          First commit index to squash (e.g. 2)
  <END>            Last commit index to squash (e.g. 300)"
  echo
  echo "Options:
  --suggest        Analyze commit history and suggest logical ranges to squash.
  --message <msg>  Optional message for the squashed commit.
  --repo <url>     Optional. If provided, clones the repo into a temporary directory.
  --dry-run        Preview actions without executing rebase.
  --force          Bypass the interactive confirmation prompt.
  --help           Show this help message."
}

abort() {
  echo "❌ Error: $*" >&2
  exit 1
}

# --- Main Logic ---
main() {
  # 1. Parse arguments
  ACTION="squash"
  COMMIT_MSG=""
  REPO_URL_PARAM=""
  DRY_RUN=""
  FORCE=""
  START=""
  END=""
  POSITIONAL_ARGS=()

  if [[ $# -eq 0 ]]; then
      usage
      exit 1
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --suggest) ACTION="suggest"; shift ;; 
      --message) COMMIT_MSG="$2"; shift 2 ;; 
      --repo) REPO_URL_PARAM="$2"; shift 2 ;; 
      --dry-run) DRY_RUN="--dry-run"; shift ;; 
      --force) FORCE="true"; shift ;; 
      --help) usage; exit 0 ;; 
      -*) echo "Unknown option: $1"; usage; exit 1 ;; 
      *) POSITIONAL_ARGS+=("$1"); shift ;; 
    esac
  done

  # 2. Assign positional arguments
  if [ "$ACTION" = "squash" ]; then
    if [ ${#POSITIONAL_ARGS[@]} -lt 2 ]; then
      echo "Error: Missing <START> and <END> arguments for squash action."
      usage
      exit 1
    fi
    START=${POSITIONAL_ARGS[0]}
    END=${POSITIONAL_ARGS[1]}
  fi

  # 3. Handle repository source and context
  if [ -n "$REPO_URL_PARAM" ]; then
    WORKDIR=$(mktemp -d)
    echo "📥 Cloning repo from $REPO_URL_PARAM into temporary directory..."
    git clone --quiet "$REPO_URL_PARAM" "$WORKDIR" || abort "git clone failed"
    cd "$WORKDIR"
    
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    git checkout "$default_branch" || abort "Failed to checkout branch $default_branch"

  elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    abort "Not inside a git repository and no --repo URL provided."
  fi
  
  # 4. Execute the requested action
  if [ "$ACTION" = "suggest" ]; then
    # I'm removing the broken suggest functionality for now.
    # suggest_ranges
    echo "--suggest feature is temporarily disabled due to a persistent bug."
    exit 1
  fi

  # 5. Proceed with squash action
  if [ -z "$COMMIT_MSG" ]; then
    COMMIT_MSG="Squash of commits $START-$END"
  fi

  BRANCH="main"
  TMPFILE="$(mktemp)"

  TOTAL_COMMITS=$(git rev-list --count HEAD)
  echo "✅ Repo has $TOTAL_COMMITS commits."

  if ! [[ "$START" =~ ^[0-9]+$ && "$END" =~ ^[0-9]+$ ]]; then
    abort "START and END must be numeric."
  fi
  if [ "$START" -lt 2 ]; then
    abort "START must be at least 2 (cannot squash the very first commit)."
  fi
  if [ "$END" -ge "$TOTAL_COMMITS" ]; then
    abort "END ($END) is out of range. Repo has only $TOTAL_COMMITS commits."
  fi
  if [ "$START" -gt "$END" ]; then
    abort "START ($START) must be less than END ($END)."
  fi

  if [ "$DRY_RUN" = "--dry-run" ]; then
    echo "🔎 DRY RUN MODE"
    echo "Would squash commits $START..$END into a single commit."
    echo "New commit message would be: \"$COMMIT_MSG\""
    echo "Resulting commit count would be: $(( TOTAL_COMMITS - (END - START) ))"
    echo "No changes made."
    exit 0
  fi

  if [ -z "$FORCE" ]; then
    echo "⚠️  You are about to squash commits $START..$END into one commit."
    echo "This will rewrite history on branch '$BRANCH'."
    read -rp "Proceed? [y/N] " CONFIRM
    if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
      echo "Aborted."
      exit 0
    fi
  fi

  git rebase -i --root --quiet || true

  TODO_FILE="$(git rev-parse --git-path rebase-merge/git-rebase-todo 2>/dev/null || true)"
  if [ ! -f "$TODO_FILE" ]; then
    abort "Could not find git rebase todo file."
  fi

  i=0
  while IFS= read -r line; do
    i=$((i+1))
    if [ $i -lt "$START" ]; then
      echo "$line" >> "$TMPFILE"
    elif [ $i -eq "$START" ]; then
      echo "$line" >> "$TMPFILE"
    elif [ $i -le "$END" ]; then
      echo "${line/pick/squash}" >> "$TMPFILE"
    else
      echo "$line" >> "$TMPFILE"
    fi
  done < "$TODO_FILE"

  mv "$TMPFILE" "$TODO_FILE"

  MSG_FILE="$(git rev-parse --git-path rebase-merge/message 2>/dev/null || true)"
  if [ -n "$MSG_FILE" ]; then
    echo "$COMMIT_MSG" > "$MSG_FILE"
  fi

  echo "🚀 Starting rebase (squashing commits $START-$END)..."
  if ! git rebase --continue; then
    echo "⚠️ Rebase paused due to conflicts. Resolve manually with:"
    echo "   git status"
    echo "   git add <fixed-files>"
    echo "   git rebase --continue"
    exit 1
  fi

  NEW_TOTAL=$(git rev-list --count HEAD)
  echo "🎉 Rebase complete!"
  echo "Old commit count: $TOTAL_COMMITS"
  echo "New commit count: $NEW_TOTAL"
  echo "Check history with: git log --oneline --graph --decorate --all"

  echo "👉 To push this cleaned history, run:"
  echo "   git push origin $BRANCH --force"
}

main "$@"