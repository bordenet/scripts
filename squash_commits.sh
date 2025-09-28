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
#   --verbose        - Enable verbose logging, printing each command as it executes.
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

# --- Cleanup Logic ---
# This trap ensures that the cleanup function is called upon script exit.
# This is crucial for removing the temporary repository clone.
trap cleanup EXIT

WORKDIR=""

cleanup() {
  # The WORKDIR variable will be set if we cloned a repo into a temp directory.
  if [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ]; then
    echo "🧹 Cleaning up temporary directory: $WORKDIR"
    rm -rf "$WORKDIR"
  fi
}

# --- Utility Functions ---
suggest_ranges() {
  echo "--suggest feature is temporarily disabled due to a persistent bug."
  exit 1
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
  --verbose        Enable verbose logging.
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
  VERBOSE=""
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
      --verbose) VERBOSE="true"; shift ;; 
      --help) usage; exit 0 ;; 
      -*) echo "Unknown option: $1"; usage; exit 1 ;; 
      *) POSITIONAL_ARGS+=("$1"); shift ;; 
    esac
  done

  if [ -n "$VERBOSE" ]; then
    set -x
  fi

  # Set a non-interactive editor for all git commands
  export GIT_EDITOR=true

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
    gh repo clone "$REPO_URL_PARAM" "$WORKDIR" || abort "git clone failed"
    cd "$WORKDIR"
    
    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    git checkout "$default_branch" || abort "Failed to checkout branch $default_branch"

  elif ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    abort "Not inside a git repository and no --repo URL provided."
  fi
  
  # 4. Execute the requested action
  if [ "$ACTION" = "suggest" ]; then
    suggest_ranges
    exit 0
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
    echo "⚠️ Rebase paused due to conflicts."
    echo "The temporary repository is located at: $WORKDIR"
    echo "To resolve, please perform the following steps in that directory:"
    echo "   1. Open the directory and fix the merge conflicts in the files listed by 'git status'."
    echo "   2. git add <fixed-files>"
    echo "   3. git rebase --continue"
    # Disable the cleanup trap so the user can fix the conflict.
    trap - EXIT
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
