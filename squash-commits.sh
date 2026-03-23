#!/usr/bin/env bash
#
# squash-commits.sh
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
#   ./squash-commits.sh <START> <END> [options]
#   ./squash-commits.sh --suggest [options]
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
#   --what-if        - DEFAULT BEHAVIOR. Show what would happen without executing.
#   --force          - Execute the rebase without prompting. REQUIRED to actually perform changes.
#   --verbose        - Enable verbose logging, printing each command as it executes.
#   --help           - Show the help message.
#
# Example:
#   # Preview what would happen (default --what-if behavior)
#   ./squash-commits.sh 2 50
#
#   # Actually perform the squash (requires --force)
#   ./squash-commits.sh 2 50 --force
#
#   # Get suggestions for squashing from a remote repository
#   ./squash-commits.sh --suggest --repo https://github.com/bordenet/RecipeArchive
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
EDITOR_SCRIPT=""

cleanup() {
  # Clean up temp files
  rm -f "${TMPFILE:-}" "${EDITOR_SCRIPT:-}" 2>/dev/null || true
  # Only remove WORKDIR on failure — on success, the user needs to push from it
  if [ "${SQUASH_FAILED:-true}" = "true" ] && [ -n "${WORKDIR:-}" ] && [ -d "$WORKDIR" ]; then
    echo "🧹 Cleaning up temporary directory: $WORKDIR"
    rm -rf "$WORKDIR"
  fi
}

# Logs verbose messages when --verbose flag is set.
log_verbose() {
  if [ -n "${VERBOSE:-}" ]; then
    echo "[VERBOSE] $1" >&2
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
  --what-if        DEFAULT. Preview actions without executing (can be explicit).
  --force          REQUIRED to actually execute the rebase.
  --verbose        Enable verbose logging.
  -h, --help       Show this help message."
  echo
  echo "IMPORTANT: This script defaults to --what-if mode. Use --force to actually execute."
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
  WHAT_IF="true"  # DEFAULT to what-if mode
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
      --what-if) WHAT_IF="true"; shift ;;  # Explicit what-if (already default)
      --force)
        WHAT_IF=""
        # shellcheck disable=SC2034  # FORCE used to document intent, WHAT_IF controls behavior
        FORCE="true"
        shift
        ;;  # Disable what-if when --force is used
      --verbose) VERBOSE="true"; shift ;;
      -h|--help) usage; exit 0 ;;
      -*) echo "Unknown option: $1"; usage; exit 1 ;;
      *) POSITIONAL_ARGS+=("$1"); shift ;;
    esac
  done

  if [ -n "$VERBOSE" ]; then
    set -x
    log_verbose "Verbose mode enabled"
  fi

  # Set a non-interactive editor for all git commands
  export GIT_EDITOR=true
  log_verbose "Set GIT_EDITOR=true for non-interactive mode"

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
    log_verbose "Created temporary directory: $WORKDIR"
    echo "📥 Cloning repo from $REPO_URL_PARAM into temporary directory..."
    gh repo clone "$REPO_URL_PARAM" "$WORKDIR" || abort "git clone failed"
    cd "$WORKDIR"
    log_verbose "Changed directory to: $WORKDIR"

    default_branch=$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')
    log_verbose "Detected default branch: $default_branch"
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

  BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null || echo "main")
  TMPFILE="$(mktemp)"
  log_verbose "Created temporary file: $TMPFILE"

  TOTAL_COMMITS=$(git rev-list --count HEAD)
  log_verbose "Total commits in repository: $TOTAL_COMMITS"
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

  if [ "$WHAT_IF" = "true" ]; then
    echo "🔎 WHAT-IF MODE (default behavior)"
    echo ""
    echo "Would squash commits $START..$END into a single commit."
    echo "New commit message would be: \"$COMMIT_MSG\""
    echo "Current commit count: $TOTAL_COMMITS"
    echo "Resulting commit count would be: $(( TOTAL_COMMITS - (END - START) ))"
    echo ""
    echo "📋 Commits that would be squashed:"
    git log --oneline --reverse HEAD~$END..HEAD~$((START-1))
    echo ""
    echo "⚠️  No changes made. Use --force to actually execute the rebase."
    exit 0
  fi

  # At this point, --force was specified
  echo "⚠️  EXECUTING REBASE (--force mode)"
  echo "You are about to squash commits $START..$END into one commit."
  echo "This will rewrite history on branch '$BRANCH'."
  read -rp "Final confirmation - Proceed? [y/N] " CONFIRM
  if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
  fi

  # Create a script that edits the rebase todo file inline
  # GIT_SEQUENCE_EDITOR is called with the todo file path as $1
  # Use global EDITOR_SCRIPT so cleanup() trap can access it
  EDITOR_SCRIPT=$(mktemp)
  cat > "$EDITOR_SCRIPT" <<EDITOREOF
#!/usr/bin/env bash
set -euo pipefail
TODO="\$1"
TMPOUT="\$(mktemp)"
i=0
while IFS= read -r line; do
    i=\$((i+1))
    if [ \$i -gt $START ] && [ \$i -le $END ]; then
        echo "\${line/pick/squash}" >> "\$TMPOUT"
    else
        echo "\$line" >> "\$TMPOUT"
    fi
done < "\$TODO"
mv "\$TMPOUT" "\$TODO"
EDITOREOF
  chmod +x "$EDITOR_SCRIPT"
  log_verbose "Created rebase editor script: $EDITOR_SCRIPT"

  echo "🚀 Starting rebase (squashing commits $START-$END)..."
  log_verbose "Running rebase with GIT_SEQUENCE_EDITOR"
  if ! GIT_SEQUENCE_EDITOR="$EDITOR_SCRIPT" GIT_EDITOR="true" git rebase -i --root; then
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

  SQUASH_FAILED=false
  rm -f "${EDITOR_SCRIPT:-}" 2>/dev/null || true

  # Apply custom commit message if provided
  if [ -n "$COMMIT_MSG" ]; then
    log_verbose "Amending squashed commit with message: $COMMIT_MSG"
    git commit --amend --message "$COMMIT_MSG" --no-edit 2>/dev/null || \
      git commit --amend --message "$COMMIT_MSG" 2>/dev/null || true
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
