# gitsync Design Spec

**Date**: 2026-04-09  
**Revision**: 3 (post second spec-reviewer pass)  
**Status**: Approved — ready for implementation  
**Replaces**: `fetch-github-projects.sh` (sequential bash implementation)  
**Target**: Sub-20s sync of 21 repos (down from ~90s)  
**Confidence**: 9.3/10 (after Debate + 3-round PHR + Code Review Battery + Spec Review)

---

## 1. Problem Statement

`fetch-github-projects.sh` is sequential: each repo's fetch blocks the next. With 21+ repos
under `~/git`, runtime reaches 90s. Core bottlenecks:

1. `git remote show origin` — 2–10s network call per repo (eliminated in new design)
2. Sequential fetch — repos processed one-at-a-time
3. No parallelism possible in bash without complex IPC

Additional pain points:
- Diverged branches: silently skipped, accumulate over time
- Feature branches: no parent-tracking, pulled from wrong upstream
- Local changes: interactive prompt blocks automation

---

## 2. Architecture

```
scripts/
  fetch-github-projects.sh     ← kept as filename (backwards compat); wraps binary
  cmd/gitsync/
    main.go                    ← CLI entry point, goroutine dispatch
  internal/
    discover/                  ← repo walk (symlinks, dedup, .fetchignore)
    gitexec/                   ← subprocess wrappers; all funcs take context.Context
    branch/                    ← Classify() + DetectParent()
    sync/                      ← RepoState, Decide(), Execute()
    output/                    ← Formatter (pure) + ProgressWriter (stateful)
  go.mod                       ← go 1.21 minimum (uses slices, maps stdlib)
  go.sum
  .gitsync.hash                ← gitignored; SHA-256 of source tree
  gitsync                      ← gitignored; compiled binary
```

### Backwards Compatibility

The wrapper **keeps the filename `fetch-github-projects.sh`**. All existing shell aliases,
cron jobs, and muscle memory continue working. The file's content changes from bash to a
thin wrapper that builds and invokes the Go binary.

### Day 0 `.gitignore` Additions (must be added before any implementation commits)

```
gitsync
gitsync_new
.gitsync.hash
.gitsync.lock
```

---

## 3. Type Definitions

All types below must be defined before implementing any other package. They form the
shared interface between packages.

### Status Enum

```go
type Status int

const (
    StatusUpdated              Status = iota // fast-forward succeeded
    StatusRebased                            // rebase succeeded
    StatusNoOp                              // already up to date or local ahead
    StatusSkipped                           // deliberate skip (see SkipReason)
    StatusFailed                            // unrecoverable error
    StatusRebaseConflict                    // rebase attempted, conflict, rolled back
    StatusStashConflict                     // stash pop conflicted after successful op
    StatusManualInterventionRequired        // git state corrupt, human must fix
)
```

### SkipReason (used when Status == StatusSkipped)

```go
type SkipReason string

const (
    SkipEmptyRepo         SkipReason = "empty repo (no commits)"
    SkipNoRemote          SkipReason = "no origin remote"
    SkipDetachedHEAD      SkipReason = "detached HEAD"
    SkipUnresolvedConflict SkipReason = "unresolved conflicts"
    SkipRebaseInProgress  SkipReason = "rebase in progress (REBASE_HEAD present)"
    SkipMergeInProgress   SkipReason = "merge in progress (MERGE_HEAD present)"
    SkipFetchTimeout      SkipReason = "fetch timed out"
    SkipNoCommonAncestor  SkipReason = "no common ancestor with parent branch"
    SkipNoRemoteTracking  SkipReason = "remote tracking ref missing after fetch"
    SkipAmbiguousBranch   SkipReason = "ambiguous branch pattern"
    SkipDivergedNoRebase  SkipReason = "diverged (use --rebase or default behavior)"
    SkipPushedNeedForce   SkipReason = "branch pushed to origin; use --force-rebase"
    SkipShallowClone      SkipReason = "shallow clone, rebase unsafe"
    SkipHasSubmodules     SkipReason = "submodules present, rebase unsafe"
    SkipNoStash           SkipReason = "local changes present and --no-stash set"
    SkipWhatIf            SkipReason = "dry run (--what-if)"
)
```

### ActionType Enum

```go
type ActionType int

const (
    ActionNoOp        ActionType = iota // nothing to do
    ActionFastForward                   // git pull --ff-only
    ActionRebase                        // git rebase origin/<parent>
    ActionSkip                          // deliberate skip, no git writes
    ActionFail                          // unrecoverable, no git writes
)
```

### Action (output of Decide)

```go
type Action struct {
    Type        ActionType
    SkipReason  SkipReason // set when Type == ActionSkip
    FailReason  string     // set when Type == ActionFail
    ForceRebase bool       // true when rebasing a pushed branch (--force-rebase)
    WhatIf      bool       // true when --what-if; action describes what WOULD happen
    // RequiresCleanWorktree: true for FastForward and Rebase; false for NoOp, Skip, Fail
    // The Execute function checks this field to decide whether to auto-stash.
    RequiresCleanWorktree bool
}
```

**RequiresCleanWorktree truth table** (implementers must follow this exactly):

| ActionType | RequiresCleanWorktree |
|---|---|
| ActionNoOp | false |
| ActionFastForward | true |
| ActionRebase | true |
| ActionSkip | false |
| ActionFail | false |

### RepoState (all observed facts about a repo — populated before Decide is called)

```go
type RepoState struct {
    RepoPath        string
    IsEmpty         bool     // true if no HEAD (git rev-parse HEAD fails)
    CurrentBranch   string   // "" if detached HEAD; populated via git symbolic-ref HEAD
    DefaultBranch   string   // detected via git symbolic-ref refs/remotes/origin/HEAD
    ParentBranch    string   // for feature branches; populated by DetectParent()
    BranchType      BranchType
    LocalSHA        string   // git rev-parse HEAD
    RemoteSHA       string   // git rev-parse origin/<parent> AFTER fetch; "" if not found
    BaseSHA         string   // git merge-base HEAD origin/<parent>; "" if no common ancestor
    HasLocalChanges bool     // true if working tree or index is dirty
    HasUnmerged     bool     // true if git ls-files --unmerged has output
    HasRebaseHead   bool     // true if .git/REBASE_HEAD exists
    HasMergeHead    bool     // true if .git/MERGE_HEAD exists
    IsShallow       bool     // git rev-parse --is-shallow-repository == "true"
    HasSubmodules   bool     // .gitmodules file exists in repo root
    IsPushed        bool     // true if refs/remotes/origin/<CurrentBranch> exists LOCALLY
                             // checked via: git show-ref --verify refs/remotes/origin/<CurrentBranch>
                             // this is a LOCAL check; no network call required
                             // populated BEFORE the multi-ref fetch so it reflects pre-fetch state
    HasOrigin       bool     // true if origin remote is configured
    FetchErr        error    // non-nil if the fetch (multi-ref or targeted) failed
    FetchTimeout    bool     // true if fetch failed due to context deadline exceeded
}
```

### BranchType Enum

```go
type BranchType int

const (
    BranchTypeDefault   BranchType = iota
    BranchTypeFeature
    BranchTypeAmbiguous
)
```

### RepoResult (output of Execute — sent on results channel)

```go
type RepoResult struct {
    RepoPath       string
    Status         Status
    SkipReason     SkipReason  // set when Status == StatusSkipped
    FailReason     string      // set when Status == StatusFailed or StatusManualInterventionRequired
    CurrentBranch  string
    ParentBranch   string
    BranchType     BranchType
    ForceRebase    bool        // true if --force-rebase was used (triggers summary warning)
    WhatIfAction   string      // non-empty when --what-if: human-readable description of what would happen
    ElapsedMs      int64
    ManualSteps    []string    // actionable instructions (e.g., "git rebase --abort")
}
```

### Flags (parsed CLI flags — passed to Decide and Execute)

```go
type Flags struct {
    NoRebase     bool // --no-rebase: warn+skip diverged instead of rebasing
    NoStash      bool // --no-stash: skip repos with local changes instead of stashing
    ForceRebase  bool // --force-rebase: rebase even if branch is pushed to origin
    WhatIf       bool // --what-if: dry run, no git writes
    Concurrency  int  // --concurrency N (default: min(runtime.NumCPU(), 8))
    FetchTimeout int  // --fetch-timeout N in seconds (default: 30)
    RebaseTimeout int // --rebase-timeout N in seconds (default: 120)
    Recursive    bool // --recursive
    Verbose      bool // --verbose
    All          bool // --all (non-interactive, process all repos)
}
```

### StashRegistry (goroutine-safe registry of repos with active auto-stashes)

```go
// StashRegistry tracks repos that have an active auto-stash so that
// SIGINT handling can pop orphaned stashes.
// All methods are goroutine-safe (protected by sync.Mutex).
// The stash message is stored so SIGINT handling can confirm it pops the right stash.
type StashEntry struct {
    RepoPath     string
    StashMessage string // e.g. "gitsync auto-stash 2026-04-09T12:34:56Z"
                        // Used to confirm identity: check `git stash list` output
                        // before popping. If top stash message matches, pop safely.
                        // If it doesn't match (user pushed stash after gitsync), do NOT pop.
}

type StashRegistry struct {
    mu      sync.Mutex
    entries map[string]StashEntry // key: repoPath
}

func (r *StashRegistry) Add(entry StashEntry)
func (r *StashRegistry) Remove(repoPath string)
func (r *StashRegistry) List() []StashEntry // returns copy sorted by RepoPath
```

**SIGINT stash pop logic**: For each entry in registry, run `git stash list --max-count=1`
and check if the top stash message matches `entry.StashMessage`. If yes: `git stash pop`.
If no match: print `"⚠ Could not safely pop stash in [repo] — stash order changed; run: git stash list"`.
This is a best-effort operation; never blindly pop without confirming the right stash is on top.

---

## 4. Bash Wrapper (`fetch-github-projects.sh`)

Responsibilities (≤65 lines):

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/gitsync"
HASH_FILE="$SCRIPT_DIR/.gitsync.hash"
LOCK_FILE="$SCRIPT_DIR/.gitsync.lock"

# 1. Require Go toolchain
command -v go >/dev/null 2>&1 || {
    echo "gitsync requires Go. Install: brew install go" >&2; exit 1
}

# 2. Concurrent invocation guard (flock requires util-linux on macOS: brew install util-linux)
if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || { echo "Another gitsync instance is running" >&2; exit 1; }
fi

# 3. Content-hash cache check
#    Hash = SHA-256 of sorted(find cmd/ internal/ -name "*.go" | sort) + go.mod + go.sum
#    Uses shasum -a 256 (macOS BSD — NOT sha256sum which is GNU/Linux only)
current_hash=$(
    {
        find "$SCRIPT_DIR/cmd" "$SCRIPT_DIR/internal" -name "*.go" | sort | xargs shasum -a 256
        shasum -a 256 "$SCRIPT_DIR/go.mod" "$SCRIPT_DIR/go.sum"
    } | shasum -a 256 | awk '{print $1}'
)
cached_hash=$(cat "$HASH_FILE" 2>/dev/null || echo "")

# 4. Rebuild if hash changed or binary missing
if [[ "$current_hash" != "$cached_hash" ]] || [[ ! -x "$BINARY" ]]; then
    echo "Building gitsync..." >&2
    rm -f "$SCRIPT_DIR/gitsync_new"
    go build -o "$SCRIPT_DIR/gitsync_new" "$SCRIPT_DIR/cmd/gitsync/" \
        && mv "$SCRIPT_DIR/gitsync_new" "$BINARY" \
        && echo "$current_hash" > "$HASH_FILE" \
        || { echo "Build failed" >&2; rm -f "$SCRIPT_DIR/gitsync_new"; exit 1; }
fi

# 5. Pre-warm SSH ControlMaster BEFORE exec (runs on every invocation, not just rebuilds)
#    This ensures all goroutines in the binary find an existing ControlMaster socket,
#    preventing a connection storm when 8+ goroutines fire simultaneously.
#    NOTE: ControlPersist=60s leaves the SSH master process alive for 60s after exit.
#    This is intentional — it benefits subsequent SSH operations in the same shell session.
ssh -o ControlMaster=auto \
    -o "ControlPath=$HOME/.ssh/cm-%r@%h:%p" \
    -o ControlPersist=60s \
    git@github.com info 2>/dev/null || true

# 6. Exec binary (replaces this shell process; passes SCRIPT_DIR for self-exclusion)
export GITSYNC_SOURCE_DIR="$SCRIPT_DIR"
exec "$BINARY" "$@"
```

**Key notes for implementers**:
- SSH pre-warm is **outside** the build `if` block — it runs on every invocation
- `shasum -a 256` (BSD) not `sha256sum` (GNU) — macOS compatibility
- `flock` is optional (graceful no-op if unavailable) to avoid hard macOS dependency
- `rm -f gitsync_new` before build cleans any partial artifact from a previous failed build
- `exec` replaces the shell process — no wrapper PID left running

---

## 5. Go Binary — Concurrency Model

```go
func main() {
    flags := parseFlags()  // returns Flags struct
    targetDir := resolveTargetDir(flags)
    repos := discover.Find(targetDir, flags.Recursive)  // []string, canonical paths

    if len(repos) == 0 {
        fmt.Fprintf(os.Stderr, "No git repositories found in %s\n", targetDir)
        os.Exit(0)
    }

    // Root context with signal handling
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()

    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

    stashRegistry := &sync.StashRegistry{}
    results := make(chan output.RepoResult, len(repos))  // buffered: goroutines never block
    tick := make(chan struct{}, 1)                        // ticker events for progress updates
    sem := make(chan struct{}, flags.Concurrency)

    // Launch goroutines
    for _, repo := range repos {
        go func(repoPath string) {
            sem <- struct{}{}
            defer func() { <-sem }()
            result := sync.Run(ctx, repoPath, flags, stashRegistry)
            results <- result
        }(repo)
    }

    // Ticker goroutine (non-blocking send — never blocks main loop)
    go func() {
        ticker := time.NewTicker(250 * time.Millisecond)
        defer ticker.Stop()
        for {
            select {
            case <-ticker.C:
                select {
                case tick <- struct{}{}:
                default: // main loop busy; drop tick
                }
            case <-ctx.Done():
                return
            }
        }
    }()

    // Main select loop — ONLY goroutine that writes to stdout
    writer := output.NewProgressWriter(os.Stdout, len(repos))
    formatter := output.NewFormatter()
    completed := 0
    start := time.Now()
    var allResults []output.RepoResult // accumulated for ShowSummary at end

    loop:
    for {
        select {
        case r := <-results:
            allResults = append(allResults, r)   // accumulate for summary
            writer.PrintResult(formatter.Format(r))
            completed++
            writer.UpdateProgress(completed, len(repos), time.Since(start))
            if completed == len(repos) {
                break loop
            }
        case <-tick:
            writer.UpdateProgress(completed, len(repos), time.Since(start))
        case sig := <-sigChan:
            _ = sig
            cancel()
            fmt.Fprintln(os.Stdout, "\nInterrupted — waiting for in-flight repos to clean up...")
            // Drain with 10s grace period
            drainCtx, drainCancel := context.WithTimeout(context.Background(), 10*time.Second)
            defer drainCancel()
            for completed < len(repos) {
                select {
                case r := <-results:
                    writer.PrintResult(formatter.Format(r))
                    completed++
                case <-drainCtx.Done():
                    goto afterLoop
                }
            }
            afterLoop:
            // Report orphaned stashes
            if orphaned := stashRegistry.List(); len(orphaned) > 0 {
                fmt.Fprintln(os.Stdout, "\n⚠ Orphaned stashes (run `git stash pop` manually):")
                for _, r := range orphaned {
                    fmt.Fprintf(os.Stdout, "  • %s\n", r)
                }
            }
            os.Exit(130)
        }
    }

    output.ShowSummary(allResults, time.Since(start), flags)
}
```

**--all flag behavior**: When `--all` is set, `discover.Find` returns all repos without
presenting an interactive selection menu. The flag is passed to `discover.Find` which
skips any menu/interactive prompt and returns all discovered repos. When `--all` is NOT
set and multiple repos are found, the binary presents a numbered menu (same as current
script) and waits for user input. `--all` is implied when a specific DIRECTORY is passed
as a positional argument.

---

## 6. Per-Repo State Machine (`sync.Run`)

### Data Collection Phase (populates RepoState — all gitexec calls happen here)

**Important: guard order is load-bearing. Do not reorder.**

```
1. git rev-parse HEAD → if fails: IsEmpty=true
2. git remote get-url origin → if fails: HasOrigin=false
3. git symbolic-ref HEAD → CurrentBranch; if fails: CurrentBranch=""
4. git ls-files --unmerged | grep -q . → HasUnmerged
5. REBASE_HEAD file exists? → HasRebaseHead
6. MERGE_HEAD file exists? → HasMergeHead
7. git rev-parse --is-shallow-repository → IsShallow
8. .gitmodules file exists? → HasSubmodules
9. git diff --quiet && git diff --cached --quiet → HasLocalChanges (invert result)
10. git symbolic-ref refs/remotes/origin/HEAD → DefaultBranch (local, no network)
    fallback: check refs/remotes/origin/main, then refs/remotes/origin/master
11. branch.Classify(CurrentBranch, DefaultBranch) → BranchType
12. If BranchType == Feature:
    a. git show-ref --verify refs/remotes/origin/<CurrentBranch> → IsPushed
       (LOCAL check — no network; done BEFORE fetch so it reflects pre-fetch state)
    b. git fetch origin main master dev develop staging 2>/dev/null || true
       (multi-ref fetch; partial failures silently ignored for non-existent refs;
        if ALL refs fail due to network error, set FetchErr = error)
    c. branch.DetectParent(candidates) → ParentBranch
13. If BranchType == Default:
    a. git fetch origin <DefaultBranch> → if fails: FetchErr=error, FetchTimeout=true if ctx deadline
14. git rev-parse HEAD → LocalSHA
15. git rev-parse origin/<ParentBranch or DefaultBranch> → RemoteSHA; if fails: RemoteSHA=""
16. git merge-base HEAD origin/<parent> → BaseSHA; if fails: BaseSHA=""
```

### Decision Phase: `Decide(state RepoState, flags Flags) → Action`

**Pure function — no I/O, no side effects. Guard order is load-bearing: do not reorder.**

```
// EARLY EXITS (no git writes; RequiresCleanWorktree = false)
state.IsEmpty                           → Action{Skip, SkipEmptyRepo}
!state.HasOrigin                        → Action{Skip, SkipNoRemote}
state.CurrentBranch == ""              → Action{Skip, SkipDetachedHEAD}
state.HasUnmerged                       → Action{Skip, SkipUnresolvedConflict}
state.HasRebaseHead                     → Action{Skip, SkipRebaseInProgress}
state.HasMergeHead                      → Action{Skip, SkipMergeInProgress}
state.FetchTimeout                      → Action{Skip, SkipFetchTimeout}
state.FetchErr != nil                   → Action{Fail, reason: state.FetchErr.Error()}
state.BranchType == Ambiguous           → Action{Skip, SkipAmbiguousBranch}
state.RemoteSHA == ""                   → Action{Skip, SkipNoRemoteTracking}
state.BaseSHA == ""                     → Action{Skip, SkipNoCommonAncestor}

// NO-OP (nothing to do; RequiresCleanWorktree = false)
state.LocalSHA == state.RemoteSHA       → Action{NoOp}           // already up to date
state.RemoteSHA == state.BaseSHA        → Action{NoOp}           // local ahead of remote

// FAST FORWARD (state.LocalSHA == state.BaseSHA; RequiresCleanWorktree = true)
state.LocalSHA == state.BaseSHA:
    flags.NoStash && state.HasLocalChanges → Action{Skip, SkipNoStash}
    else → Action{FastForward, RequiresCleanWorktree: true}

// DIVERGED (none of the above matched; RequiresCleanWorktree = true for rebase)
// Diverged = LocalSHA != RemoteSHA && LocalSHA != BaseSHA && RemoteSHA != BaseSHA
flags.NoRebase                                      → Action{Skip, SkipDivergedNoRebase}
// Default branch diverged: never auto-rebase main/master — user has unpushed commits.
// IsPushed is NOT populated for default branches (no need: default is always pushed).
state.BranchType == BranchTypeDefault               → Action{Skip, SkipDivergedNoRebase}
state.IsShallow                                     → Action{Skip, SkipShallowClone}
state.HasSubmodules                                 → Action{Skip, SkipHasSubmodules}
flags.NoStash && state.HasLocalChanges              → Action{Skip, SkipNoStash}
// IsPushed is only populated for Feature branches (see data collection step 12a).
// It is always false (zero value) for Default and Ambiguous branches, which are
// handled by earlier guards. Do not use IsPushed for non-Feature branches.
state.IsPushed && !flags.ForceRebase                → Action{Skip, SkipPushedNeedForce}
else → Action{Rebase, ForceRebase: state.IsPushed && flags.ForceRebase,
              RequiresCleanWorktree: true}

// --what-if modifier: if flags.WhatIf, wrap any computed Action with WhatIf=true
// The Action.Type remains the same (describes what WOULD happen), but Execute will
// not perform any git writes and will set result.WhatIfAction to a description string.
// Decide() does NOT need special casing for WhatIf — Execute() checks WhatIf.
```

### Execution Phase: `Execute(ctx context.Context, state RepoState, action Action, flags Flags, registry *StashRegistry) → RepoResult`

```
// --what-if: return immediately with description, no writes
if action.WhatIf {
    return RepoResult{
        Status: StatusSkipped,
        SkipReason: SkipWhatIf,
        WhatIfAction: describeAction(action, state),
        // all other fields populated from state
    }
}

// STASH (if action.RequiresCleanWorktree && state.HasLocalChanges)
stashed := false
if action.RequiresCleanWorktree && state.HasLocalChanges {
    stashMsg := fmt.Sprintf("gitsync auto-stash %s", time.Now().Format(time.RFC3339))
    err := gitexec.StashPush(ctx, state.RepoPath, stashMsg)
    if err != nil {
        return RepoResult{Status: StatusFailed, FailReason: "stash push failed: " + err.Error()}
    }
    stashed = true
    registry.Add(state.RepoPath)
}

// popStash is a helper called at the end of each code path (NOT as a defer).
// It is called explicitly because we must NOT pop if rebase failed/aborted
// (the repo might be in a half-rebased state).
popStash := func() (stashConflict bool) {
    if !stashed {
        return false
    }
    registry.Remove(state.RepoPath)
    stashed = false
    if err := gitexec.StashPop(ctx, state.RepoPath); err != nil {
        return true // stash pop conflicted
    }
    return false
}

switch action.Type {
case ActionNoOp:
    return RepoResult{Status: StatusNoOp, ...}

case ActionFastForward:
    ffCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
    defer cancel()
    err := gitexec.PullFFOnly(ffCtx, state.RepoPath, state.ParentBranch)
    if err != nil {
        // FF failed: pop stash (safe — no rebase in flight), report failure
        popStash()
        if errors.Is(err, context.DeadlineExceeded) {
            return RepoResult{Status: StatusFailed, FailReason: "pull --ff-only timed out"}
        }
        return RepoResult{Status: StatusFailed, FailReason: "pull --ff-only failed: " + err.Error()}
    }
    if conflict := popStash(); conflict {
        return RepoResult{Status: StatusStashConflict, ...}
        // Note: fast-forward succeeded and is preserved. Repo is ff'd but has stash conflict.
        // User must manually run `git stash pop` to resolve.
    }
    return RepoResult{Status: StatusUpdated, ...}

case ActionRebase:
    rebaseCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.RebaseTimeout)*time.Second)
    defer cancel()
    err := gitexec.Rebase(rebaseCtx, state.RepoPath, "origin/"+state.ParentBranch)
    if err != nil {
        // Rebase failed. DO NOT pop stash — repo may be in mid-rebase state.
        // Attempt abort to restore clean state.
        abortErr := gitexec.RebaseAbort(context.Background(), state.RepoPath)
        // Use Background context (not rebaseCtx which may be cancelled) for abort.
        if abortErr != nil {
            // Abort also failed — repo may be corrupt.
            // Do NOT attempt stash pop; stash remains orphaned; registry retains entry.
            return RepoResult{
                Status: StatusManualInterventionRequired,
                FailReason: "rebase and abort both failed",
                ManualSteps: []string{
                    "cd " + state.RepoPath,
                    "git rebase --abort  # or: git reset --hard HEAD",
                    "git stash list     # check for orphaned stash",
                },
            }
        }
        // Abort succeeded. Now safe to pop stash.
        if conflict := popStash(); conflict {
            return RepoResult{Status: StatusRebaseConflict, ...}
            // Note: rebase conflict, rolled back. Stash pop also conflicted.
            // Both are reported; user must resolve stash manually.
        }
        return RepoResult{Status: StatusRebaseConflict, ...}
    }
    // Rebase succeeded. Now safe to pop stash.
    if conflict := popStash(); conflict {
        return RepoResult{Status: StatusStashConflict, ...}
        // Rebase succeeded and is preserved. Stash pop conflicted.
    }
    return RepoResult{
        Status: StatusRebased,
        ForceRebase: action.ForceRebase, // triggers force-push warning in summary
        ...
    }
}
```

**Stash pop suppression rule** (load-bearing — do not change):
> `popStash()` is called ONLY after the primary git operation (FF or rebase) completes or
> is fully aborted. It is NEVER called via `defer`. This prevents popping a stash on top
> of a half-completed rebase that exec.CommandContext SIGKILL'd mid-operation.

---

## 7. Branch Classification and Parent Detection

### Classification (`branch.Classify(current, defaultBranch string) → BranchType`)

```
current == defaultBranch                → BranchTypeDefault
release/*, hotfix/*, staging,
develop, development                    → BranchTypeAmbiguous (closed set; not user-configurable)
anything else                           → BranchTypeFeature
```

### Default Branch Detection (no network — local refs only)

```
git symbolic-ref refs/remotes/origin/HEAD → trim prefix "refs/remotes/origin/" → branch name
fallback 1: git show-ref --verify refs/remotes/origin/main && echo "main"
fallback 2: git show-ref --verify refs/remotes/origin/master && echo "master"
fallback 3: CurrentBranch (last resort; may be wrong but avoids crash)
```

Never calls `git remote show origin` — eliminates the 2–10s per-repo bottleneck.

### Parent Detection (`branch.DetectParent(repoPath string, candidates []string) → string`)

Candidates list (fixed order): `["main", "master", "dev", "develop", "staging"]`

```
1. For each candidate in candidates:
   a. Check if refs/remotes/origin/<candidate> exists locally (git show-ref --verify)
   b. If not: skip (don't count missing remote tracking refs)
   c. If yes: count commits HEAD is behind: git rev-list --count HEAD..origin/<candidate>
2. Return candidate with lowest count (fewest commits behind = closest parent)
3. If no candidates exist as local refs: return "main" (safe default; Decide will
   set RemoteSHA="" → SkipNoRemoteTracking)
```

### Multi-ref fetch error handling

`git fetch origin main master dev develop staging 2>/dev/null || true`

In Go:
- Run as single exec.CommandContext call; ignore non-zero exit (some refs may not exist)
- If exit code is non-zero AND all 5 refs are missing from local tracking refs after the call:
  set `FetchErr = errors.New("all parent candidate refs unavailable")`
- If at least one candidate ref exists locally after the call: `FetchErr = nil`

---

## 8. CLI Flags

| Flag | Default | Description |
|---|---|---|
| `[DIRECTORY]` | `.` | Positional arg — target directory (backwards compat). Implies `--all`. |
| `--dir <path>` / `-d` | `.` | Named alternative to positional arg. Positional takes precedence if both given. |
| `--all` / `-a` | off | Process all repos non-interactively (skip selection menu). Auto-set by positional arg. |
| `--recursive` / `-r` | off | Walk all subdirectories |
| `--what-if` | off | Dry-run: compute and display what WOULD happen; no git writes. Discovery and Decide() run normally. |
| `--verbose` / `-v` | off | Per-repo detail (see §9 for content) |
| `--no-rebase` | off | Warn+skip diverged branches instead of rebasing |
| `--no-stash` | off | Skip repos with local changes instead of stashing. Checked in Decide() before FastForward and Rebase. |
| `--force-rebase` | off | Rebase even if branch is pushed to origin. ⚠ SOLO BRANCHES ONLY: force-push overwrites origin if shared. |
| `--merge` | alias | No-op alias for backwards compatibility. The current default behavior (rebase) is what `--merge` previously enabled. |
| `--concurrency N` | min(NumCPU, 8) | Max parallel repos |
| `--fetch-timeout N` | 30 | Per-repo fetch/pull timeout in seconds (network operations only) |
| `--rebase-timeout N` | 120 | Per-repo rebase timeout in seconds (local operations) |

---

## 9. Output and UX

### Verbose Mode Content (`--verbose`)

Per-repo, printed to stderr (non-verbose output goes to stdout):
```
[repo] INFO: branch=feature/my-work type=Feature parent=main isPushed=false
[repo] INFO: multi-ref fetch complete; candidates found: main, master
[repo] INFO: position: LocalSHA=abc123 RemoteSHA=def456 BaseSHA=789abc → diverged
[repo] INFO: stash created: gitsync auto-stash 2026-04-09T12:34:56Z
[repo] INFO: rebase origin/main → SUCCESS
[repo] INFO: stash popped
```

### Live Progress Line (non-verbose)

Updated by main select loop on each repo result and on each tick event.
Only the main goroutine touches stdout.

Before printing a repo result line:
```
\r\033[2K   # carriage return + erase line
```
Print result, then immediately reprint progress on the same line (overwrite).

Progress format:
```
Syncing 21 repos...  [14/21]  00:09
```

### Per-Repo Results (printed as goroutines complete — non-deterministic order)

```
  ✓ claude-code           (updated main, 1.2s)
  • scripts               (up to date)
  ✓ genesis               (rebased onto main, 2.1s)
  ⊘ jd-assistant          (local changes — stash pop conflict)
  ✗ legacy-api            (fetch timed out after 30s)
  ⚠ my-feature            (rebased — force-push needed)
  ○ old-feature           (dry run: would rebase onto main)   ← --what-if
```

Icons: `✓` = success, `•` = no-op, `⊘` = skipped, `✗` = failed, `⚠` = warning, `○` = what-if

### Summary

```
Summary (8s)
✓ Updated (12):             claude-code, ...
✓ Rebased (3):              genesis, ...
⊘ Skipped (4):              ...
✗ Failed (2):               legacy-api (fetch timeout), ...
⚠ Force-push needed (1):    my-feature → git push --force-with-lease origin my-feature
                             ⚠ Solo branches only — force-push overwrites shared branches
⚠ Stash conflicts (1):      jd-assistant (run: git stash pop)
⚠ Manual intervention (0):

✓ All repositories processed.
```

### `--what-if` Output

When `--what-if` is set, the summary header says:
```
DRY RUN — no changes were made
```
Each repo result shows what WOULD have happened using the `○` icon and `WhatIfAction` string.
The exit code is 0 (success) even if some repos would have had issues.

### SIGINT / Graceful Drain

1. Cancel all repo contexts
2. Print: `"\nInterrupted — waiting for in-flight repos to clean up..."`
3. Drain remaining results (10s grace period via `context.WithTimeout`)
4. For each entry in `StashRegistry.List()` (repos with active auto-stashes):
   - Run `git stash list --max-count=1` in that repo
   - If top stash message matches `entry.StashMessage`: run `git stash pop`
     - If pop succeeds: remove from registry; no warning
     - If pop fails: print `"⚠ Stash pop failed in [repo] — run: git stash pop"`
   - If message does NOT match: print `"⚠ Could not safely pop stash in [repo] — stash order changed; run: git stash list"`
5. Exit 130 (SIGINT convention; `--what-if` does NOT suppress this exit code — if the user ctrl-C's, exit 130 regardless of `--what-if`)

---

## 10. Repo Discovery (`internal/discover`)

### `discover.Find(targetDir string, recursive bool) → []string`

Returns canonical absolute paths of all git repos, deduplicated.

**Symlink following**: Go's `filepath.WalkDir` does NOT follow symlinks. Implement a custom
walk using `os.Lstat` + `os.Readlink` + recursion. Deduplication: maintain a `map[string]bool`
of canonical paths (via `filepath.EvalSymlinks`); skip if already seen.

**.git detection**: Both `.git` as directory (normal repos) AND `.git` as regular file
(git worktrees, submodules) count as git repos.

**.fetchignore**: Load from `targetDir/.fetchignore` if present.
- One path per line; paths relative to targetDir
- Lines starting with `#` are comments; blank lines ignored
- Resolve each entry to canonical path; skip any repo whose canonical path matches

**Self-exclusion**: The env var `GITSYNC_SOURCE_DIR` (set by wrapper) contains the
scripts repo path. `discover.Find` must skip any repo whose canonical path equals
`filepath.EvalSymlinks(os.Getenv("GITSYNC_SOURCE_DIR"))`.

**Non-recursive mode**: Only look 2 levels deep (direct children and grandchildren of targetDir).

---

## 11. SSH Configuration

Set on all gitexec subprocess calls via `GIT_SSH_COMMAND` env var:

```
ssh -oBatchMode=yes
    -oControlMaster=auto
    -oControlPath=~/.ssh/cm-%r@%h:%p
    -oControlPersist=60s
```

The SSH pre-warm in the wrapper ensures the ControlMaster socket exists before any goroutine
fires, preventing the connection storm that would occur if 8 goroutines simultaneously attempt
full SSH handshakes.

`ControlPersist=60s` intentionally leaves the SSH master process alive for 60s after gitsync
exits to benefit subsequent SSH operations in the same shell session.

---

## 12. Test Strategy

### Run with Race Detector (mandatory)

```bash
go test -race ./...
```

This is required because `StashRegistry` is the primary concurrency surface.
A `go test ./...` without `-race` is insufficient.

### Unit Tests (pure logic — zero subprocesses, zero filesystem access)

All tests are table-driven using `[]struct{ input ...; expected ... }`.

- `branch.Classify` — all branch patterns including edge cases (`release/1.0`, `hotfix/urgent`, `develop`, `development`, `staging`, feature branches, default branch)
- `branch.DetectParent` — all candidate orderings; missing candidates; all missing
- `sync.Decide` — **all 15 canonical scenarios** (see integration test table below — same scenarios, pure state input)
- `output.Formatter.Format` — all Status values, all SkipReason values, WhatIf=true

### Integration Tests (real git repos in `t.TempDir()`)

Each test:
1. Creates a real git repo with `git init`, `git config`, `git commit`
2. Creates a local "remote" repo as a second temp dir, wires it as origin
3. Runs `sync.Run` with a real context
4. Asserts `RepoResult.Status` and `RepoResult.SkipReason`

| # | Scenario | Setup | Expected Status | Expected SkipReason |
|---|---|---|---|---|
| 1 | Empty repo | `git init` only (no commits) | StatusSkipped | SkipEmptyRepo |
| 2 | No origin remote | init + commit, no remote configured | StatusSkipped | SkipNoRemote |
| 3 | Detached HEAD | checkout specific commit SHA | StatusSkipped | SkipDetachedHEAD |
| 4 | Conflict in progress | create unmerged files in index | StatusSkipped | SkipUnresolvedConflict |
| 5 | REBASE_HEAD present | write a REBASE_HEAD file to .git/ | StatusSkipped | SkipRebaseInProgress |
| 6 | Up to date | local == remote | StatusNoOp | — |
| 7 | FF available | remote ahead by 2 commits | StatusUpdated | — |
| 8 | Local ahead | local ahead by 1 commit | StatusNoOp | — |
| 9 | Diverged + --no-rebase | both sides have commits, flags.NoRebase=true | StatusSkipped | SkipDivergedNoRebase |
| 10 | Diverged + rebase + not pushed | both sides have commits, IsPushed=false | StatusRebased | — |
| 11 | Diverged + pushed (no --force-rebase) | IsPushed=true, flags.ForceRebase=false | StatusSkipped | SkipPushedNeedForce |
| 12 | Diverged + --force-rebase | IsPushed=true, flags.ForceRebase=true | StatusRebased + ForceRebase=true | — |
| 13 | Shallow + diverged | `git clone --depth 1` as setup | StatusSkipped | SkipShallowClone |
| 14 | Submodules + diverged | write `.gitmodules` to repo root | StatusSkipped | SkipHasSubmodules |
| 15 | Fetch timeout | use flags.FetchTimeout=1 with a mock remote that sleeps 5s | StatusSkipped | SkipFetchTimeout |

### Additional Integration Tests

| Test | What to verify |
|---|---|
| `--what-if` flag | No git writes occur; result.WhatIfAction is non-empty; exit code 0 |
| `--no-stash` + local changes + ff available | StatusSkipped with SkipNoStash |
| stash push failure | Return StatusFailed with "stash push failed" in FailReason |
| stash pop conflict after ff | StatusStashConflict; fast-forward is preserved in repo |
| rebase conflict + stash pop success | StatusRebaseConflict; repo is clean (abort succeeded) |
| rebase conflict + stash pop conflict | StatusRebaseConflict; manual steps in result |
| `.fetchignore` — repo in ignore list | Repo not in discover.Find output |
| symlink to repo — canonical dedup | Only one entry in discover.Find output |

### Build and Lint

```bash
shellcheck fetch-github-projects.sh   # wrapper lint
go vet ./...
go test -race ./...                   # race detector mandatory
```

---

## 13. Performance Model

| Scenario | Time Estimate |
|---|---|
| 21 repos, all up-to-date, warm SSH | ~6–8s |
| 21 repos, mixed ff/rebase, warm SSH | ~10–14s |
| 21 repos, cold SSH (first run) | ~12–18s |
| First build (warm Go module cache) | +2–4s (one-time) |

Target: **under 20s** ✅

Key performance properties:
- `git symbolic-ref` (local) replaces `git remote show origin` (2–10s network per repo)
- Feature branches: ONE multi-ref fetch covers both parent detection AND data sync
- Default branch repos: ONE targeted fetch
- SSH ControlMaster pre-warmed before goroutines fire (no connection storm)
- Default concurrency = min(NumCPU, 8): ⌈21/8⌉ = 3 batches × ~3s ≈ 9s

---

## 14. Package Responsibilities Summary

| Package | Responsibility | Key constraint |
|---|---|---|
| `cmd/gitsync` | CLI, flag parsing, goroutine dispatch, main select loop, SIGINT handling | Only goroutine that writes to stdout |
| `internal/discover` | Repo walk, symlink dedup, `.fetchignore`, self-exclusion | Must follow symlinks; must handle `.git` as file |
| `internal/gitexec` | `exec.CommandContext` wrappers | Every function takes `context.Context` as first arg |
| `internal/branch` | `Classify()`, `DetectParent()` | Pure logic; no I/O |
| `internal/sync` | `RepoState`, `Decide()`, `Execute()`, `StashRegistry` | `Decide` is pure; `Execute` is not; stash pop is never deferred |
| `internal/output` | `Formatter` (pure), `ProgressWriter` (stateful, owns stdout) | `Formatter.Format` takes no I/O; `ProgressWriter` is injected |

---

## 15. Rejected Alternatives

**Bash + xargs -P**: Parallel output requires temp files/FIFOs; stash+rebase state machines
in subshells are untestable; shared state coordination is fragile at this complexity level.

**Python + concurrent.futures**: No compiled artifact; runtime version variance on macOS;
no meaningful advantage over Go for this use case.

**Go without bash wrapper**: Build-on-demand pattern requires a shell layer to check the hash
and rebuild. Wrapper is thin (≤65 lines) and well-isolated.

**Named `gitsync.sh` instead of `fetch-github-projects.sh`**: Would break every existing
alias, cron job, and muscle memory. Zero benefit vs. keeping the filename.
