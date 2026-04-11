# gitsync Code Review Battery Findings
> Written 2026-04-11 — Verdict: REJECT. Do not merge until C1+C2+C3 fixed.

## Critical Findings (must fix before merge)

### C1+C2: Stash lifecycle race in `execute.go` `popStash` closure
**File:** `internal/sync/execute.go`  
**Problem:**
```go
// CURRENT (BROKEN):
popStash := func() bool {
    if !stashed { return false }
    registry.Remove(state.RepoPath)  // BUG C1: Remove called BEFORE StashPop confirms success
    stashed = false
    return gitexec.StashPop(ctx, state.RepoPath) != nil  // BUG C2: uses cancellable ctx
}
```
**Fix:**
```go
// CORRECT:
popStash := func() bool {
    if !stashed { return false }
    stashed = false
    if err := gitexec.StashPop(context.Background(), state.RepoPath); err != nil {
        return false
    }
    registry.Remove(state.RepoPath)  // Only remove AFTER successful pop
    return true
}
```

### C3: Semaphore acquisition not context-aware in `cmd/gitsync/main.go`
**File:** `cmd/gitsync/main.go`  
**Problem:** On SIGINT, goroutines blocked on `sem <- struct{}{}` never unblock:
```go
// CURRENT (BROKEN):
go func(repoPath string) {
    sem <- struct{}{}  // blocks forever if ctx cancelled while waiting
    defer func() { <-sem }()
    results <- gosync.Run(rootCtx, repoPath, flags, registry)
}(repo)
```
**Fix:**
```go
// CORRECT:
go func(repoPath string) {
    select {
    case sem <- struct{}{}:
    case <-rootCtx.Done():
        results <- gosync.RepoResult{RepoPath: repoPath, Skipped: true, SkipReason: "cancelled"}
        return
    }
    defer func() { <-sem }()
    results <- gosync.Run(rootCtx, repoPath, flags, registry)
}(repo)
```

---

## Important Findings (fix before merge if possible)

### I1: Unquoted `$HOME` in `GIT_SSH_COMMAND`
**File:** `internal/gitexec/gitexec.go`  
**Fix:** Quote `os.Getenv("HOME")` when constructing path: use `fmt.Sprintf` with proper quoting or `filepath.Join`.

### I2: `--verbose` flag parsed but never used
**File:** `cmd/gitsync/main.go` + output layer  
**Fix:** Either pass `flags.Verbose` through to formatter and emit per-field detail, or remove the flag.

### I3: `defer drainCancel()` never runs before `os.Exit(130)`
**File:** `cmd/gitsync/main.go` SIGINT handler  
**Fix:** Replace `defer drainCancel()` with explicit `drainCancel()` call before `os.Exit(130)`.

### I4: `TestRun_FetchTimeout` is flaky (sleep-based)
**File:** `internal/sync/execute_test.go`  
**Fix:** Replace with a pre-cancelled context: `ctx, cancel := context.WithCancel(context.Background()); cancel()` — deterministic, no sleep.

### I5: No stash integration tests
**File:** `internal/sync/execute_test.go`  
**Fix:** Add two tests:
- `TestRun_FastForward_DirtyWorktree` — local uncommitted changes, FF succeeds, stash popped
- `TestRun_Rebase_DirtyWorktree` — local uncommitted changes, rebase succeeds, stash popped

---

## Minor Findings (9 suppressed — address in follow-up)
- `stash_helpers.go` forwarding layer adds no value (thin pass-through)
- `ShowSummary` calls `os.Exit(1)` making it untestable
- Various naming/comment improvements

---

## File Hygiene Notes (scripts/ repo)
- Root level getting busy (~20+ bash scripts + go.mod + config files)
- `lib/fetch-github-lib.sh` is dead code (wrapper no longer sources it) — should be deleted
- Two untracked stray files: `.code-review-cleared` (sentinel, should be gitignored) and `Nv,f8H811` (accidentally created file — delete it)
- `.gitignore` needs entry for `.code-review-cleared`
- Overall structure is sensible: root bash scripts, Go in `internal/`+`cmd/`, docs in `docs/`, tool suites in subdirectories

---

## Post-Fix Checklist
- [ ] Fix C1+C2 in `internal/sync/execute.go`
- [ ] Fix C3 in `cmd/gitsync/main.go`
- [ ] Fix I1 in `internal/gitexec/gitexec.go`
- [ ] Fix I2 (`--verbose`)
- [ ] Fix I3 (explicit drainCancel before os.Exit)
- [ ] Fix I4 (deterministic timeout test)
- [ ] Fix I5 (stash integration tests)
- [ ] Delete `Nv,f8H811` stray file
- [ ] Delete `lib/fetch-github-lib.sh` (dead code)
- [ ] Add `.code-review-cleared` to `.gitignore`
- [ ] Re-run code review battery
- [ ] Write sentinel (`tools/run-battery.sh --verdict PASS`)
- [ ] Merge to origin/main
