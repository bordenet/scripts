# Design: Safe Merge for Feature Branches

**Date**: 2026-02-24  
**Author**: Matt J Bordenet  
**Status**: Approved  
**Reviewer**: Staff Engineer Review (incorporated)

## Problem Statement

When working on feature branches across multiple repos, `fetch-github-projects.sh` currently:
- Only fast-forwards the default branch
- Reports "diverged" and fails when on feature branches
- Doesn't help integrate latest changes from main into feature branches

Users need a safe way to batch-merge main into feature branches with:
- Automatic conflict detection and rollback
- Clear visibility into what will be merged
- Protection against partial/inconsistent states

## Design Overview

### Behavior Matrix

| Mode | On default branch | On feature branch | On ambiguous branch (`release/*`, etc.) |
|------|-------------------|-------------------|----------------------------------------|
| Interactive | Fast-forward pull | Prompt with stats, merge | Skip with warning |
| `--all` | Fast-forward pull | Skip (no merge) | Skip |
| `--all --merge` | Fast-forward pull | Batch confirm, merge all | Skip with warning |
| `--what-if --merge` | Show would-pull | Show would-merge stats | Show "would skip" |

### Branch Classification

```
DEFAULT_BRANCH = git remote show origin | awk '/HEAD branch/ {print $NF}'

if current_branch == DEFAULT_BRANCH:
    → Default branch behavior (fast-forward pull)
elif current_branch matches "release/*|hotfix/*|develop":
    → Ambiguous branch, skip with warning
else:
    → Feature branch, eligible for merge
```

### Merge Workflow (per repo)

```
1. Classify branch (default / feature / ambiguous)
2. If feature branch:
   a. Fetch origin/$DEFAULT_BRANCH with SSH batch mode
   b. Check for shallow clone → warn and skip
   c. Check for .git/index.lock → warn and skip
   d. Calculate: commits behind, files changed, lines changed
   e. Prompt (or batch if --all --merge):
      "feature-xyz: 5 commits behind (12 files, +340/-89). Merge? [y/n]"
   f. If yes:
      - Record CHECKPOINT_HEAD=$(git rev-parse HEAD)
      - Stash uncommitted changes with -u (include untracked)
      - git merge origin/$DEFAULT_BRANCH --no-edit
      - If conflict: git merge --abort || git reset --hard $CHECKPOINT_HEAD
                     Restore stash, warn "Merge conflicts, rolled back"
      - If success: stash pop
        - If stash pop fails: warn "Merge succeeded, stash conflicts"
```

### New CLI Flags

```
--merge
    Enable feature branch merging.
    Interactive mode: prompts per-repo with stats
    With --all: batch confirmation, then auto-merge all
    
--what-if --merge
    Preview what would be merged without making changes.
    Shows commit count, file count, line changes per repo.
```

### Summary Output Format

```
Summary (12s)
✓ Updated (3):
  • one-pager (main → updated)
  • jd-assistant (feature-auth → merged 5 commits from main)
  • pr-faq-assistant (main → up to date)

⚠ Merge conflicts (1):
  • strategic-proposal (feature-refactor → conflict, rolled back)

⚠ Stash conflicts (1):
  • power-statement (feature-ui → merged, stash needs manual pop)

⊘ Skipped (2):
  • arch-decision-record (feature-docs → user declined)
  • acceptance-criteria (release/2.0 → ambiguous branch, skipped)
```

## Safety Requirements (from Staff Review)

### Must-Have

1. **SSH batch mode on all fetches**
   ```bash
   GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="ssh -oBatchMode=yes" git fetch ...
   ```

2. **Stash includes untracked files**
   ```bash
   git stash push -u -m "fetch-github-projects $(date +%Y%m%d-%H%M%S) $BRANCH"
   ```

3. **Shallow clone detection**
   ```bash
   if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
       warn "Shallow clone, skipping merge"
   fi
   ```

4. **Checkpoint-based rollback**
   ```bash
   CHECKPOINT_HEAD=$(git rev-parse HEAD)
   # On any failure:
   git merge --abort 2>/dev/null || git reset --hard "$CHECKPOINT_HEAD"
   ```

5. **Lock file detection**
   ```bash
   if [ -f ".git/index.lock" ]; then
       warn "Repository locked, skipping"
   fi
   ```

6. **Batch confirmation for --all --merge**
   ```
   5 repos on feature branches will merge main:
     jd-assistant, strategic-proposal, power-statement, ...
   Proceed? [y/n/list]
   ```

### Edge Cases Handled

| Scenario | Handling |
|----------|----------|
| Shallow clone | Detect, warn, skip |
| Force-pushed main | Merge-base recalculated after fetch |
| Untracked file conflicts | Stashed with `-u` flag |
| Network timeout | SSH batch mode prevents hang |
| Concurrent operations | Lock file detection |
| Disk full on stash | Stash failure aborts merge attempt |
| Power failure mid-merge | Checkpoint HEAD enables recovery |

## Out of Scope (Deferred)

- `--rebase` alternative to `--merge`
- Per-repo config for custom upstream branch
- Submodule recursive update after merge
- Git LFS handling
- JSON output format

## Implementation Checklist

See implementation plan: `2026-02-24-safe-merge-implementation-plan.md`

