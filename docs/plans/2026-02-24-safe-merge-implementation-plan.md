# Safe Merge Feature Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `--merge` flag to `fetch-github-projects.sh` that safely merges main into feature branches with automatic rollback on conflict.

**Architecture:** Extend existing `update_repo()` function with branch classification, merge workflow, and checkpoint-based rollback. Add new helper functions in `lib/fetch-github-lib.sh` for merge operations.

**Tech Stack:** Bash 3.2+ compatible, shellcheck compliant, follows scripts/STYLE_GUIDE.md

---

## Task 1: Add SSH Batch Mode to Fetch Operations

**Files:**
- Modify: `scripts/fetch-github-projects.sh:152-161`

**Step 1: Add SSH batch mode variables at top of script**

After line 36 (TIMER_WAS_RUNNING), add:
```bash
# SSH batch mode to prevent hanging on auth prompts
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -oBatchMode=yes"
```

**Step 2: Test SSH batch mode works**

Run: `cd scripts && ./fetch-github-projects.sh --what-if .`
Expected: No hang on SSH prompt, completes normally

**Step 3: Commit**

```bash
git add scripts/fetch-github-projects.sh
git commit -m "fix: add SSH batch mode to prevent auth hangs"
```

---

## Task 2: Add New Global Variables and CLI Flag

**Files:**
- Modify: `scripts/fetch-github-projects.sh:29-36` (globals)
- Modify: `scripts/fetch-github-projects.sh:257-285` (arg parsing)

**Step 1: Add merge-related global variables**

After line 36, add:
```bash
MERGE_MODE=false
MERGE_CONFLICT_REPOS=()
MERGED_REPOS=()
AMBIGUOUS_BRANCH_REPOS=()
```

**Step 2: Add --merge flag parsing**

In the while loop (around line 275), add case:
```bash
        --merge)
            MERGE_MODE=true
            shift
            ;;
```

**Step 3: Test flag is recognized**

Run: `./scripts/fetch-github-projects.sh --help`
Run: `./scripts/fetch-github-projects.sh --merge --what-if .`
Expected: No "unknown option" error

**Step 4: Commit**

```bash
git add scripts/fetch-github-projects.sh
git commit -m "feat: add --merge flag (not yet implemented)"
```

---

## Task 3: Add Helper Functions to Library

**Files:**
- Modify: `scripts/lib/fetch-github-lib.sh` (add at end, before final blank line)

**Step 1: Add branch classification function**

```bash
# Classify branch type: default, feature, or ambiguous
# Returns: 0=default, 1=feature, 2=ambiguous
classify_branch() {
    local current_branch=$1
    local default_branch=$2
    
    # Check if on default branch
    if [ "$current_branch" = "$default_branch" ]; then
        echo "default"
        return 0
    fi
    
    # Check for ambiguous branch patterns
    case "$current_branch" in
        release/*|hotfix/*|develop|development|staging)
            echo "ambiguous"
            return 2
            ;;
    esac
    
    # Otherwise it's a feature branch
    echo "feature"
    return 1
}
```

**Step 2: Add shallow clone detection**

```bash
# Check if repo is a shallow clone
is_shallow_clone() {
    [ "$(git rev-parse --is-shallow-repository 2>/dev/null)" = "true" ]
}
```

**Step 3: Add lock file detection**

```bash
# Check if repo has active lock
has_lock_file() {
    [ -f ".git/index.lock" ]
}
```

**Step 4: Test functions work**

```bash
cd scripts
source lib/fetch-github-lib.sh
classify_branch "main" "main"        # Should echo "default"
classify_branch "feature-xyz" "main" # Should echo "feature"  
classify_branch "release/2.0" "main" # Should echo "ambiguous"
```

**Step 5: Commit**

```bash
git add scripts/lib/fetch-github-lib.sh
git commit -m "feat: add branch classification helpers"
```

---

## Task 4: Add Merge Stats Function

**Files:**
- Modify: `scripts/lib/fetch-github-lib.sh`

**Step 1: Add function to calculate merge stats**

```bash
# Get merge preview stats: commits behind, files changed, lines changed
# Output: "5 commits, 12 files, +340/-89 lines"
get_merge_stats() {
    local default_branch=$1
    local commits_behind files_changed lines_added lines_removed
    
    commits_behind=$(git rev-list --count HEAD.."origin/$default_branch" 2>/dev/null || echo "?")
    
    if [ "$commits_behind" = "0" ] || [ "$commits_behind" = "?" ]; then
        echo "0 commits behind"
        return
    fi
    
    # Get diffstat
    local diffstat
    diffstat=$(git diff --shortstat HEAD..."origin/$default_branch" 2>/dev/null || echo "")
    
    if [ -n "$diffstat" ]; then
        files_changed=$(echo "$diffstat" | grep -oE '[0-9]+ file' | grep -oE '[0-9]+' || echo "0")
        lines_added=$(echo "$diffstat" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
        lines_removed=$(echo "$diffstat" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
        echo "$commits_behind commits, $files_changed files, +${lines_added}/-${lines_removed}"
    else
        echo "$commits_behind commits behind"
    fi
}
```

**Step 2: Test the function**

```bash
cd some-repo-on-feature-branch
source ../scripts/lib/fetch-github-lib.sh
git fetch origin main
get_merge_stats "main"
# Should output something like: "5 commits, 12 files, +340/-89"
```

**Step 3: Commit**

```bash
git add scripts/lib/fetch-github-lib.sh
git commit -m "feat: add get_merge_stats function"
```

---

## Task 5: Add Safe Merge Function

**Files:**
- Modify: `scripts/lib/fetch-github-lib.sh`

**Step 1: Add merge with rollback function**

```bash
# Perform safe merge with automatic rollback on conflict
# Returns: 0=success, 1=conflict (rolled back), 2=stash conflict (merge ok)
safe_merge_main() {
    local default_branch=$1
    local checkpoint_head stash_created=false stash_name
    
    checkpoint_head=$(git rev-parse HEAD)
    stash_name="fetch-github-projects $(date +%Y%m%d-%H%M%S) on $(git branch --show-current)"
    
    # Stash uncommitted changes (including untracked)
    if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
        if ! git stash push -u -m "$stash_name" >/dev/null 2>&1; then
            echo "STASH_FAILED"
            return 1
        fi
        stash_created=true
    fi
    
    # Attempt merge
    if ! git merge "origin/$default_branch" --no-edit >/dev/null 2>&1; then
        # Rollback: abort merge or hard reset
        git merge --abort 2>/dev/null || git reset --hard "$checkpoint_head" 2>/dev/null
        # Restore stash
        [ "$stash_created" = true ] && git stash pop >/dev/null 2>&1
        echo "CONFLICT"
        return 1
    fi
    
    # Merge succeeded - restore stash
    if [ "$stash_created" = true ]; then
        if ! git stash pop >/dev/null 2>&1; then
            echo "STASH_CONFLICT"
            return 2
        fi
    fi
    
    echo "SUCCESS"
    return 0
}
```

**Step 2: Commit**

```bash
git add scripts/lib/fetch-github-lib.sh
git commit -m "feat: add safe_merge_main with rollback"
```

---

## Task 6: Update update_repo() for Feature Branch Handling

**Files:**
- Modify: `scripts/fetch-github-projects.sh:180-250` (update_repo function)

**Step 1: Add branch classification at start of update_repo()**

After the existing `CURRENT_BRANCH` detection (around line 186), add:
```bash
    # Classify branch type
    local branch_type
    branch_type=$(classify_branch "$CURRENT_BRANCH" "$DEFAULT_BRANCH")

    # Handle ambiguous branches
    if [ "$branch_type" = "ambiguous" ]; then
        AMBIGUOUS_BRANCH_REPOS+=("$REPO_PATH ($CURRENT_BRANCH)")
        return 0
    fi
```

**Step 2: Add shallow clone and lock file checks**

After branch classification, add:
```bash
    # Safety checks
    if is_shallow_clone; then
        info "  Shallow clone detected, skipping merge"
        SKIPPED_REPOS+=("$REPO_PATH (shallow clone)")
        return 0
    fi

    if has_lock_file; then
        warn "  Repository locked by another process"
        SKIPPED_REPOS+=("$REPO_PATH (locked)")
        return 0
    fi
```

**Step 3: Add feature branch merge logic**

After the existing diverged branch handling, add new elif block:
```bash
    elif [ "$branch_type" = "feature" ] && [ "$MERGE_MODE" = true ]; then
        # Feature branch with --merge enabled
        local merge_stats
        merge_stats=$(get_merge_stats "$DEFAULT_BRANCH")

        if [[ "$merge_stats" == "0 commits behind" ]]; then
            UPDATED_REPOS+=("$REPO_PATH ($CURRENT_BRANCH, up to date with $DEFAULT_BRANCH)")
            return 0
        fi

        # In interactive mode, prompt user
        if [ "$ALL_MODE" != true ]; then
            info "  $CURRENT_BRANCH is $merge_stats"
            read -r -p "  Merge $DEFAULT_BRANCH into $CURRENT_BRANCH? [y/n] " response
            if [[ ! "$response" =~ ^[Yy] ]]; then
                SKIPPED_REPOS+=("$REPO_PATH ($CURRENT_BRANCH, user declined)")
                return 0
            fi
        fi

        # Perform safe merge
        local merge_result
        merge_result=$(safe_merge_main "$DEFAULT_BRANCH")

        case "$merge_result" in
            SUCCESS)
                MERGED_REPOS+=("$REPO_PATH ($CURRENT_BRANCH → merged $DEFAULT_BRANCH)")
                ;;
            CONFLICT)
                MERGE_CONFLICT_REPOS+=("$REPO_PATH ($CURRENT_BRANCH → conflict, rolled back)")
                ;;
            STASH_CONFLICT)
                MERGED_REPOS+=("$REPO_PATH ($CURRENT_BRANCH → merged, stash needs manual pop)")
                ;;
            STASH_FAILED)
                SKIPPED_REPOS+=("$REPO_PATH ($CURRENT_BRANCH, stash failed)")
                ;;
        esac
```

**Step 4: Test with a feature branch repo**

```bash
cd genesis-tools/jd-assistant
git checkout -b test-feature-branch
cd ../..
./scripts/fetch-github-projects.sh --merge genesis-tools/jd-assistant
# Should prompt and attempt merge
git checkout main && git branch -D test-feature-branch
```

**Step 5: Commit**

```bash
git add scripts/fetch-github-projects.sh
git commit -m "feat: handle feature branch merges in update_repo"
```

---

## Task 7: Add Batch Confirmation for --all --merge

**Files:**
- Modify: `scripts/fetch-github-projects.sh:290-320` (main execution block)

**Step 1: Add batch preview function**

Before the main loop, add:
```bash
# Preview feature branches that will be merged (for --all --merge)
preview_merge_candidates() {
    local candidates=()
    for repo_path in "${REPOS_TO_UPDATE[@]}"; do
        if [ -d "$repo_path/.git" ]; then
            cd "$repo_path" || continue
            local current_branch default_branch branch_type
            current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
            default_branch=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')
            branch_type=$(classify_branch "$current_branch" "$default_branch")

            if [ "$branch_type" = "feature" ]; then
                local stats
                stats=$(get_merge_stats "$default_branch")
                if [[ "$stats" != "0 commits behind" ]]; then
                    candidates+=("$repo_path ($current_branch): $stats")
                fi
            fi
            cd - >/dev/null || true
        fi
    done

    if [ ${#candidates[@]} -eq 0 ]; then
        info "No feature branches need merging"
        return 1
    fi

    echo ""
    info "${#candidates[@]} repos on feature branches will merge main:"
    for c in "${candidates[@]}"; do
        echo "  • $c"
    done
    echo ""
    read -r -p "Proceed with all merges? [y/n/list] " response
    case "$response" in
        [Yy]*) return 0 ;;
        [Ll]*)
            for c in "${candidates[@]}"; do echo "  $c"; done
            read -r -p "Proceed? [y/n] " response2
            [[ "$response2" =~ ^[Yy] ]] && return 0
            ;;
    esac
    return 1
}
```

**Step 2: Call batch preview before main loop**

In the main execution, before iterating repos, add:
```bash
if [ "$ALL_MODE" = true ] && [ "$MERGE_MODE" = true ] && [ "$WHAT_IF" != true ]; then
    if ! preview_merge_candidates; then
        info "Merge cancelled by user"
        exit 0
    fi
fi
```

**Step 3: Test batch confirmation**

```bash
./scripts/fetch-github-projects.sh --all --merge --what-if
# Should show preview without prompting (what-if mode)

./scripts/fetch-github-projects.sh --all --merge genesis-tools
# Should show batch confirmation prompt
```

**Step 4: Commit**

```bash
git add scripts/fetch-github-projects.sh
git commit -m "feat: add batch confirmation for --all --merge"
```

---

## Task 8: Update Summary Output

**Files:**
- Modify: `scripts/fetch-github-projects.sh:320-380` (summary function)

**Step 1: Update print_summary to include merge results**

Add new sections to the summary output:
```bash
    # Merged repos
    if [ ${#MERGED_REPOS[@]} -gt 0 ]; then
        success "Merged (${#MERGED_REPOS[@]}):"
        for repo in "${MERGED_REPOS[@]}"; do
            echo "  • $repo"
        done
    fi

    # Merge conflicts
    if [ ${#MERGE_CONFLICT_REPOS[@]} -gt 0 ]; then
        warn "Merge conflicts (${#MERGE_CONFLICT_REPOS[@]}):"
        for repo in "${MERGE_CONFLICT_REPOS[@]}"; do
            echo "  • $repo"
        done
    fi

    # Ambiguous branches
    if [ ${#AMBIGUOUS_BRANCH_REPOS[@]} -gt 0 ]; then
        info "Ambiguous branches skipped (${#AMBIGUOUS_BRANCH_REPOS[@]}):"
        for repo in "${AMBIGUOUS_BRANCH_REPOS[@]}"; do
            echo "  • $repo"
        done
    fi
```

**Step 2: Test summary output**

Run the script and verify all categories appear correctly.

**Step 3: Commit**

```bash
git add scripts/fetch-github-projects.sh
git commit -m "feat: update summary to show merge results"
```

---

## Task 9: Update Help Text

**Files:**
- Modify: `scripts/fetch-github-projects.sh:50-100` (usage function)

**Step 1: Add --merge to usage output**

```bash
    --merge
        When on a feature branch, merge origin/main into current branch.
        Interactive mode: prompts per-repo with commit/file stats.
        With --all: shows batch preview, then merges all approved.
        Performs safe rollback if merge conflicts occur.
```

**Step 2: Add examples**

```bash
Examples:
    $SCRIPT_NAME .                      # Update current repo
    $SCRIPT_NAME --all ~/projects       # Update all repos in directory
    $SCRIPT_NAME --merge .              # Merge main into feature branch
    $SCRIPT_NAME --all --merge ~/work   # Batch merge main into all feature branches
    $SCRIPT_NAME --what-if --merge .    # Preview merge without executing
```

**Step 3: Test help output**

```bash
./scripts/fetch-github-projects.sh --help
# Verify --merge appears in help
```

**Step 4: Commit**

```bash
git add scripts/fetch-github-projects.sh
git commit -m "docs: add --merge flag to help text"
```

---

## Task 10: Integration Testing

**Files:**
- Create: `scripts/docs/plans/2026-02-24-safe-merge-test-plan.md` (optional reference)

**Step 1: Test default branch behavior unchanged**

```bash
cd genesis-tools/one-pager
git checkout main
cd ../..
./scripts/fetch-github-projects.sh genesis-tools/one-pager
# Should fast-forward as before
```

**Step 2: Test feature branch without --merge**

```bash
cd genesis-tools/jd-assistant
git checkout -b test-feature-123
cd ../..
./scripts/fetch-github-projects.sh genesis-tools/jd-assistant
# Should skip merge (no --merge flag)
```

**Step 3: Test feature branch with --merge (interactive)**

```bash
./scripts/fetch-github-projects.sh --merge genesis-tools/jd-assistant
# Should prompt with stats, then merge on 'y'
```

**Step 4: Test merge conflict rollback**

```bash
cd genesis-tools/jd-assistant
echo "conflict content" > README.md
cd ../..
./scripts/fetch-github-projects.sh --merge genesis-tools/jd-assistant
# Should detect conflict, rollback, report in summary
```

**Step 5: Test --all --merge batch mode**

```bash
./scripts/fetch-github-projects.sh --all --merge genesis-tools
# Should show batch preview, ask once, then process all
```

**Step 6: Test --what-if --merge preview**

```bash
./scripts/fetch-github-projects.sh --what-if --merge genesis-tools/jd-assistant
# Should show what would happen without executing
```

**Step 7: Clean up test branch**

```bash
cd genesis-tools/jd-assistant
git checkout main
git branch -D test-feature-123
cd ../..
```

**Step 8: Final commit**

```bash
git add -A
git commit -m "feat: complete safe merge feature implementation"
```

---

## Summary

| Task | Description | Est. Time |
|------|-------------|-----------|
| 1 | SSH batch mode | 5 min |
| 2 | CLI flag + globals | 10 min |
| 3 | Helper functions | 15 min |
| 4 | Merge stats function | 10 min |
| 5 | Safe merge function | 15 min |
| 6 | update_repo() changes | 20 min |
| 7 | Batch confirmation | 15 min |
| 8 | Summary output | 10 min |
| 9 | Help text | 5 min |
| 10 | Integration testing | 20 min |

**Total estimated time: ~2 hours**

