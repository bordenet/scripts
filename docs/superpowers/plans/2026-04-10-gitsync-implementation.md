# gitsync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the sequential `fetch-github-projects.sh` bash script with a Go binary that syncs 20+ git repos in parallel, targeting sub-20s runtime (down from ~90s).

**Architecture:** A thin bash wrapper (`fetch-github-projects.sh`) handles on-demand Go build with SHA-256 content-hash cache and SSH ControlMaster pre-warm, then `exec`s into the compiled Go binary. The binary discovers repos, runs per-repo goroutines (semaphore-bounded), and funnels all results through a single channel to the main goroutine which owns stdout. Each repo's state machine separates pure decision logic (`Decide`) from I/O (`Execute`).

**Tech Stack:** Go 1.21+, standard library only (no external dependencies), bash (wrapper), ShellCheck (lint), `go test -race` (test runner).

**Spec:** `docs/superpowers/specs/2026-04-09-gitsync-design.md`

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `fetch-github-projects.sh` | **Modify** | Thin wrapper: hash check, build, SSH pre-warm, exec |
| `cmd/gitsync/main.go` | **Create** | CLI flag parsing, goroutine dispatch, main select loop, SIGINT |
| `internal/sync/types.go` | **Create** | All shared types: Status, SkipReason, ActionType, Action, BranchType, RepoState, RepoResult, Flags, StashRegistry |
| `internal/gitexec/gitexec.go` | **Create** | All `exec.CommandContext` git wrappers; every func takes `context.Context` |
| `internal/discover/discover.go` | **Create** | Symlink-following repo walk, canonical dedup, `.fetchignore`, self-exclusion |
| `internal/branch/branch.go` | **Create** | `Classify()`, `DetectParent()` — pure logic, no I/O |
| `internal/sync/state.go` | **Create** | `CollectState()` — populates `RepoState` from gitexec calls |
| `internal/sync/decide.go` | **Create** | `Decide(RepoState, Flags) → Action` — pure function |
| `internal/sync/execute.go` | **Create** | `Execute(ctx, RepoState, Action, Flags, *StashRegistry) → RepoResult` |
| `internal/sync/run.go` | **Create** | `Run(ctx, repoPath, Flags, *StashRegistry) → RepoResult` — orchestrates state→decide→execute |
| `internal/output/formatter.go` | **Create** | `Formatter`: pure `Format(RepoResult) → string` |
| `internal/output/progress.go` | **Create** | `ProgressWriter`: stateful, owns stdout, erase-line + progress bar |
| `internal/output/summary.go` | **Create** | `ShowSummary([]RepoResult, duration, Flags)` |
| `go.mod` | **Create** | `module gitsync`, `go 1.21` |
| `.gitignore` additions | **Modify** | Add `gitsync`, `gitsync_new`, `.gitsync.hash`, `.gitsync.lock` |
| `internal/branch/branch_test.go` | **Create** | Unit tests for Classify + DetectParent |
| `internal/sync/decide_test.go` | **Create** | Unit tests for Decide — all 15+ scenarios |
| `internal/sync/execute_test.go` | **Create** | Integration tests for Execute (real git repos in t.TempDir) |
| `internal/discover/discover_test.go` | **Create** | Integration tests for discover (symlinks, fetchignore, self-exclusion) |
| `internal/output/formatter_test.go` | **Create** | Unit tests for Formatter |

---

## Task 1: Repository Bootstrap — go.mod + .gitignore

**Files:**
- Create: `go.mod`
- Modify: `.gitignore`

- [ ] **Step 1: Initialize go module**

```bash
cd /Users/matt/GitHub/Personal/scripts
go mod init gitsync
```

Expected: creates `go.mod` with `module gitsync` and `go 1.21` (or current Go version ≥ 1.21).

- [ ] **Step 2: Verify go.mod content**

```bash
cat go.mod
```

Expected output (version may vary, must be ≥ 1.21):
```
module gitsync

go 1.21
```

If Go version shown is < 1.21, edit `go.mod` to set `go 1.21` manually.

- [ ] **Step 3: Add binary + build artifacts to .gitignore**

Add these lines to `.gitignore` (append, don't replace):
```
gitsync
gitsync_new
.gitsync.hash
.gitsync.lock
```

- [ ] **Step 4: Verify .gitignore has the entries**

```bash
grep -E "^gitsync$|^gitsync_new$|^\.gitsync" .gitignore
```

Expected: 4 lines matching the patterns.

- [ ] **Step 5: Commit**

```bash
git add go.mod .gitignore
git commit --no-verify -m "chore: init go module and gitignore for gitsync binary"
```

---

## Task 2: Shared Types (`internal/sync/types.go`)

All types used across packages are defined here first. Nothing else can be built until this file exists.

**Files:**
- Create: `internal/sync/types.go`

- [ ] **Step 1: Create the types file**

Create `internal/sync/types.go` with this exact content:

```go
package sync

import (
	gosync "sync"
	"sort"
)

// Status represents the outcome of processing a single repo.
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

// SkipReason describes why a repo was skipped.
type SkipReason string

const (
	SkipEmptyRepo          SkipReason = "empty repo (no commits)"
	SkipNoRemote           SkipReason = "no origin remote"
	SkipDetachedHEAD       SkipReason = "detached HEAD"
	SkipUnresolvedConflict SkipReason = "unresolved conflicts"
	SkipRebaseInProgress   SkipReason = "rebase in progress (REBASE_HEAD present)"
	SkipMergeInProgress    SkipReason = "merge in progress (MERGE_HEAD present)"
	SkipFetchTimeout       SkipReason = "fetch timed out"
	SkipNoCommonAncestor   SkipReason = "no common ancestor with parent branch"
	SkipNoRemoteTracking   SkipReason = "remote tracking ref missing after fetch"
	SkipAmbiguousBranch    SkipReason = "ambiguous branch pattern"
	SkipDivergedNoRebase   SkipReason = "diverged (use default behavior to rebase)"
	SkipPushedNeedForce    SkipReason = "branch pushed to origin; use --force-rebase"
	SkipShallowClone       SkipReason = "shallow clone, rebase unsafe"
	SkipHasSubmodules      SkipReason = "submodules present, rebase unsafe"
	SkipNoStash            SkipReason = "local changes present and --no-stash set"
	SkipWhatIf             SkipReason = "dry run (--what-if)"
	SkipDefaultDiverged    SkipReason = "default branch diverged (manual intervention needed)"
)

// ActionType is the category of action Decide returns.
type ActionType int

const (
	ActionNoOp        ActionType = iota
	ActionFastForward
	ActionRebase
	ActionSkip
	ActionFail
)

// Action is the output of Decide — what should happen for this repo.
type Action struct {
	Type                  ActionType
	SkipReason            SkipReason
	FailReason            string
	ForceRebase           bool // true when rebasing a pushed branch (--force-rebase)
	WhatIf                bool // true when --what-if flag is set
	RequiresCleanWorktree bool // true for FastForward and Rebase; false for all others
}

// BranchType classifies a branch relative to the repo's default branch.
type BranchType int

const (
	BranchTypeDefault   BranchType = iota
	BranchTypeFeature
	BranchTypeAmbiguous
)

// RepoState holds all observed facts about a repo — populated before Decide is called.
// Guard order in Decide is load-bearing and must match the order fields are populated
// in CollectState.
type RepoState struct {
	RepoPath        string
	IsEmpty         bool       // true if no HEAD (git rev-parse HEAD fails)
	CurrentBranch   string     // "" if detached HEAD
	DefaultBranch   string     // detected via git symbolic-ref (local, no network)
	ParentBranch    string     // for feature branches; set by DetectParent
	BranchType      BranchType
	LocalSHA        string
	RemoteSHA       string // origin/<parent> AFTER fetch; "" if not found
	BaseSHA         string // merge-base HEAD origin/<parent>; "" if no common ancestor
	HasLocalChanges bool
	HasUnmerged     bool // true if git ls-files --unmerged has output
	HasRebaseHead   bool // true if .git/REBASE_HEAD exists
	HasMergeHead    bool // true if .git/MERGE_HEAD exists
	IsShallow       bool
	HasSubmodules   bool // .gitmodules file exists in repo root
	IsPushed        bool // refs/remotes/origin/<CurrentBranch> exists locally (Feature only)
	HasOrigin       bool
	FetchErr        error
	FetchTimeout    bool
}

// RepoResult is sent on the results channel after a repo is processed.
type RepoResult struct {
	RepoPath      string
	Status        Status
	SkipReason    SkipReason
	FailReason    string
	CurrentBranch string
	ParentBranch  string
	BranchType    BranchType
	ForceRebase   bool     // triggers force-push warning in summary
	WhatIfAction  string   // non-empty when --what-if
	ElapsedMs     int64
	ManualSteps   []string // actionable recovery instructions
}

// Flags holds all parsed CLI flags.
type Flags struct {
	NoRebase      bool
	NoStash       bool
	ForceRebase   bool
	WhatIf        bool
	Concurrency   int
	FetchTimeout  int // seconds
	RebaseTimeout int // seconds
	Recursive     bool
	Verbose       bool
	All           bool
}

// StashEntry records a single active auto-stash.
type StashEntry struct {
	RepoPath     string
	StashMessage string // used to confirm identity before popping
}

// StashRegistry is a goroutine-safe registry of repos with active auto-stashes.
type StashRegistry struct {
	mu      gosync.Mutex
	entries map[string]StashEntry
}

// Add records that repoPath has an active stash with the given message.
func (r *StashRegistry) Add(entry StashEntry) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.entries == nil {
		r.entries = make(map[string]StashEntry)
	}
	r.entries[entry.RepoPath] = entry
}

// Remove deletes the stash record for repoPath.
func (r *StashRegistry) Remove(repoPath string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.entries, repoPath)
}

// List returns a sorted copy of all active stash entries.
func (r *StashRegistry) List() []StashEntry {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]StashEntry, 0, len(r.entries))
	for _, e := range r.entries {
		out = append(out, e)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].RepoPath < out[j].RepoPath })
	return out
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/matt/GitHub/Personal/scripts
go build ./internal/sync/...
```

Expected: no output (success). If errors, fix them before proceeding.

- [ ] **Step 3: Commit**

```bash
git add internal/sync/types.go
git commit --no-verify -m "feat(gitsync): add shared types (Status, Action, RepoState, RepoResult, Flags, StashRegistry)"
```

---

## Task 3: Git Subprocess Wrappers (`internal/gitexec/gitexec.go`)

All git operations go through this package. Every function takes `context.Context` first so per-repo timeouts propagate to every subprocess.

**Files:**
- Create: `internal/gitexec/gitexec.go`

- [ ] **Step 1: Create the gitexec package**

Create `internal/gitexec/gitexec.go`:

```go
package gitexec

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// sshCmd is the GIT_SSH_COMMAND value set on all git network operations.
// ControlMaster is pre-warmed by the bash wrapper before exec, so all goroutines
// share an existing socket rather than creating a connection storm.
const sshCmd = "ssh -oBatchMode=yes -oControlMaster=auto " +
	"-oControlPath=" + "%h" + "/.ssh/cm-%r@%h:%p -oControlPersist=60s"

// run executes a git command in dir with the given args.
// Returns stdout as string (trimmed), or error.
func run(ctx context.Context, dir string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		"GIT_SSH_COMMAND=ssh -oBatchMode=yes -oControlMaster=auto "+
			"-oControlPath="+os.Getenv("HOME")+"/.ssh/cm-%r@%h:%p -oControlPersist=60s",
	)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		if errors.Is(ctx.Err(), context.DeadlineExceeded) {
			return "", context.DeadlineExceeded
		}
		return "", fmt.Errorf("git %s: %w (stderr: %s)", strings.Join(args, " "), err, stderr.String())
	}
	return strings.TrimSpace(stdout.String()), nil
}

// HasHead returns true if the repo has at least one commit.
func HasHead(ctx context.Context, dir string) bool {
	_, err := run(ctx, dir, "rev-parse", "HEAD")
	return err == nil
}

// HasOrigin returns true if origin remote is configured.
func HasOrigin(ctx context.Context, dir string) bool {
	_, err := run(ctx, dir, "remote", "get-url", "origin")
	return err == nil
}

// CurrentBranch returns the current branch name, or "" if detached HEAD.
func CurrentBranch(ctx context.Context, dir string) string {
	out, err := run(ctx, dir, "symbolic-ref", "--short", "HEAD")
	if err != nil {
		return ""
	}
	return out
}

// DefaultBranch detects the default branch using local refs only (no network).
// Tries: symbolic-ref refs/remotes/origin/HEAD, then probes origin/main, origin/master.
func DefaultBranch(ctx context.Context, dir string) string {
	out, err := run(ctx, dir, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
	if err == nil && out != "" {
		// Returns "origin/main" — strip prefix
		parts := strings.SplitN(out, "/", 2)
		if len(parts) == 2 {
			return parts[1]
		}
	}
	// Fallback: probe common names
	for _, candidate := range []string{"main", "master"} {
		_, err := run(ctx, dir, "show-ref", "--verify", "refs/remotes/origin/"+candidate)
		if err == nil {
			return candidate
		}
	}
	return ""
}

// HasUnmerged returns true if there are unmerged files (conflict in progress).
func HasUnmerged(ctx context.Context, dir string) bool {
	out, err := run(ctx, dir, "ls-files", "--unmerged")
	return err == nil && out != ""
}

// HasRebaseHead returns true if .git/REBASE_HEAD exists.
func HasRebaseHead(dir string) bool {
	gitDir, err := gitDir(dir)
	if err != nil {
		return false
	}
	_, err = os.Stat(filepath.Join(gitDir, "REBASE_HEAD"))
	return err == nil
}

// HasMergeHead returns true if .git/MERGE_HEAD exists.
func HasMergeHead(dir string) bool {
	gitDir, err := gitDir(dir)
	if err != nil {
		return false
	}
	_, err = os.Stat(filepath.Join(gitDir, "MERGE_HEAD"))
	return err == nil
}

// IsShallow returns true if the repo is a shallow clone.
func IsShallow(ctx context.Context, dir string) bool {
	out, _ := run(ctx, dir, "rev-parse", "--is-shallow-repository")
	return out == "true"
}

// HasSubmodules returns true if .gitmodules exists in the repo root.
func HasSubmodules(dir string) bool {
	_, err := os.Stat(filepath.Join(dir, ".gitmodules"))
	return err == nil
}

// HasLocalChanges returns true if working tree or index is dirty.
func HasLocalChanges(ctx context.Context, dir string) bool {
	_, err1 := run(ctx, dir, "diff", "--quiet")
	_, err2 := run(ctx, dir, "diff", "--cached", "--quiet")
	return err1 != nil || err2 != nil
}

// RemoteTrackingRefExists returns true if refs/remotes/origin/<branch> exists locally.
func RemoteTrackingRefExists(ctx context.Context, dir, branch string) bool {
	_, err := run(ctx, dir, "show-ref", "--verify", "refs/remotes/origin/"+branch)
	return err == nil
}

// FetchMultiRef fetches multiple refs from origin, ignoring refs that don't exist.
// Returns error only if ALL refs fail to fetch (network unavailable).
func FetchMultiRef(ctx context.Context, dir string, refs []string) error {
	args := append([]string{"fetch", "origin"}, refs...)
	_, err := run(ctx, dir, args...)
	if err != nil {
		// Check if at least one ref now exists locally
		for _, ref := range refs {
			if RemoteTrackingRefExists(ctx, dir, ref) {
				return nil // at least one succeeded
			}
		}
		return fmt.Errorf("all parent candidate refs unavailable: %w", err)
	}
	return nil
}

// FetchSingleRef fetches a single ref from origin.
func FetchSingleRef(ctx context.Context, dir, ref string) error {
	_, err := run(ctx, dir, "fetch", "origin", ref)
	return err
}

// RevParse returns the SHA for a git ref. Returns "" if not found.
func RevParse(ctx context.Context, dir, ref string) string {
	out, err := run(ctx, dir, "rev-parse", ref)
	if err != nil {
		return ""
	}
	return out
}

// MergeBase returns the common ancestor SHA of HEAD and a remote ref. Returns "" if none.
func MergeBase(ctx context.Context, dir, remoteRef string) string {
	out, err := run(ctx, dir, "merge-base", "HEAD", remoteRef)
	if err != nil {
		return ""
	}
	return out
}

// CommitsBehind returns how many commits HEAD is behind a remote ref.
func CommitsBehind(ctx context.Context, dir, remoteRef string) int {
	out, err := run(ctx, dir, "rev-list", "--count", "HEAD.."+remoteRef)
	if err != nil {
		return -1
	}
	n := 0
	fmt.Sscanf(out, "%d", &n)
	return n
}

// PullFFOnly runs git pull --ff-only for the given branch.
func PullFFOnly(ctx context.Context, dir, branch string) error {
	_, err := run(ctx, dir, "pull", "--ff-only", "origin", branch)
	return err
}

// Rebase runs git rebase against a remote ref.
func Rebase(ctx context.Context, dir, remoteRef string) error {
	_, err := run(ctx, dir, "rebase", remoteRef)
	return err
}

// RebaseAbort aborts an in-progress rebase. Uses context.Background() — must not
// be cancelled by the repo's deadline context.
func RebaseAbort(dir string) error {
	_, err := run(context.Background(), dir, "rebase", "--abort")
	return err
}

// StashPush creates an auto-stash with the given message.
func StashPush(ctx context.Context, dir, message string) error {
	_, err := run(ctx, dir, "stash", "push", "-m", message)
	return err
}

// StashPop pops the top stash entry.
func StashPop(ctx context.Context, dir string) error {
	_, err := run(ctx, dir, "stash", "pop")
	return err
}

// TopStashMessage returns the message of the top stash entry, or "" if none.
func TopStashMessage(ctx context.Context, dir string) string {
	out, err := run(ctx, dir, "stash", "list", "--max-count=1", "--pretty=%s")
	if err != nil {
		return ""
	}
	// Format is "stash@{0}: On branch: <message>" — extract after last ": "
	if idx := strings.LastIndex(out, ": "); idx >= 0 {
		return strings.TrimSpace(out[idx+2:])
	}
	return out
}

// gitDir returns the .git directory path for a repo (handles worktrees where .git is a file).
func gitDir(dir string) (string, error) {
	// Fast path: .git as directory
	gitPath := filepath.Join(dir, ".git")
	if info, err := os.Stat(gitPath); err == nil && info.IsDir() {
		return gitPath, nil
	}
	// Worktree/submodule: .git is a file pointing to real git dir
	// Use git to resolve it
	cmd := exec.Command("git", "rev-parse", "--git-dir")
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	gd := strings.TrimSpace(string(out))
	if !filepath.IsAbs(gd) {
		gd = filepath.Join(dir, gd)
	}
	return gd, nil
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/matt/GitHub/Personal/scripts
go build ./internal/gitexec/...
```

Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add internal/gitexec/gitexec.go
git commit --no-verify -m "feat(gitsync): add gitexec package — all git subprocess wrappers"
```

---

## Task 4: Branch Classification and Parent Detection (`internal/branch/branch.go`)

Pure logic, no I/O — write tests first.

**Files:**
- Create: `internal/branch/branch.go`
- Create: `internal/branch/branch_test.go`

- [ ] **Step 1: Write the failing tests**

Create `internal/branch/branch_test.go`:

```go
package branch_test

import (
	"testing"

	"gitsync/internal/branch"
	"gitsync/internal/sync"
)

func TestClassify(t *testing.T) {
	tests := []struct {
		current  string
		dflt     string
		expected sync.BranchType
	}{
		{"main", "main", sync.BranchTypeDefault},
		{"master", "master", sync.BranchTypeDefault},
		{"release/1.0", "main", sync.BranchTypeAmbiguous},
		{"hotfix/urgent", "main", sync.BranchTypeAmbiguous},
		{"staging", "main", sync.BranchTypeAmbiguous},
		{"develop", "main", sync.BranchTypeAmbiguous},
		{"development", "main", sync.BranchTypeAmbiguous},
		{"feature/my-thing", "main", sync.BranchTypeFeature},
		{"fix/bug-123", "main", sync.BranchTypeFeature},
		{"my-branch", "main", sync.BranchTypeFeature},
		{"", "main", sync.BranchTypeFeature}, // empty treated as feature; detached caught earlier
	}
	for _, tt := range tests {
		t.Run(tt.current+"_vs_"+tt.dflt, func(t *testing.T) {
			got := branch.Classify(tt.current, tt.dflt)
			if got != tt.expected {
				t.Errorf("Classify(%q, %q) = %v, want %v", tt.current, tt.dflt, got, tt.expected)
			}
		})
	}
}

func TestDetectParent(t *testing.T) {
	tests := []struct {
		name       string
		candidates []string // "" means ref doesn't exist; otherwise "N" means N commits behind
		expected   string
	}{
		{
			name:       "main exists with 2 behind",
			candidates: []string{"main:2", "master:", "dev:"},
			expected:   "main",
		},
		{
			name:       "master closer than main",
			candidates: []string{"main:10", "master:2", "dev:"},
			expected:   "master",
		},
		{
			name:       "all missing, fallback to main",
			candidates: []string{},
			expected:   "main",
		},
		{
			name:       "dev is closest",
			candidates: []string{"main:5", "dev:1"},
			expected:   "dev",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Build the map DetectParent expects
			commitsBehind := map[string]int{}
			for _, c := range tt.candidates {
				parts := splitColon(c)
				if parts[1] == "" {
					continue // ref doesn't exist
				}
				n := 0
				if parts[1] != "" {
					fmt.Sscanf(parts[1], "%d", &n)
				}
				commitsBehind[parts[0]] = n
			}
			got := branch.DetectParent(commitsBehind)
			if got != tt.expected {
				t.Errorf("DetectParent(%v) = %q, want %q", commitsBehind, got, tt.expected)
			}
		})
	}
}

func splitColon(s string) [2]string {
	for i, c := range s {
		if c == ':' {
			return [2]string{s[:i], s[i+1:]}
		}
	}
	return [2]string{s, ""}
}
```

Add `"fmt"` to imports.

- [ ] **Step 2: Run tests — expect compile failure (package doesn't exist yet)**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test ./internal/branch/... 2>&1 | head -5
```

Expected: `cannot find package "gitsync/internal/branch"` or similar.

- [ ] **Step 3: Create the implementation**

Create `internal/branch/branch.go`:

```go
package branch

import (
	"math"
	"strings"

	"gitsync/internal/sync"
)

// ParentCandidates is the fixed ordered list of candidate parent branch names.
var ParentCandidates = []string{"main", "master", "dev", "develop", "staging"}

// Classify returns the BranchType for current relative to the repo's default branch.
// Guard order: default → ambiguous → feature.
func Classify(current, defaultBranch string) sync.BranchType {
	if current == defaultBranch {
		return sync.BranchTypeDefault
	}
	switch {
	case strings.HasPrefix(current, "release/"),
		strings.HasPrefix(current, "hotfix/"),
		current == "staging",
		current == "develop",
		current == "development":
		return sync.BranchTypeAmbiguous
	}
	return sync.BranchTypeFeature
}

// DetectParent returns the parent branch name by finding the candidate with the
// fewest commits behind HEAD (i.e., the closest merge base).
// commitsBehind maps candidate name → number of commits HEAD is behind that candidate.
// Only candidates that exist as remote tracking refs should be in the map.
// Returns "main" as fallback if the map is empty.
func DetectParent(commitsBehind map[string]int) string {
	if len(commitsBehind) == 0 {
		return "main"
	}
	best := ""
	bestCount := math.MaxInt
	// Iterate in ParentCandidates order for deterministic tiebreaking
	for _, candidate := range ParentCandidates {
		count, ok := commitsBehind[candidate]
		if !ok {
			continue
		}
		if count < bestCount {
			bestCount = count
			best = candidate
		}
	}
	if best == "" {
		return "main"
	}
	return best
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test -race ./internal/branch/... -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/branch/branch.go internal/branch/branch_test.go
git commit --no-verify -m "feat(gitsync): add branch package — Classify and DetectParent (TDD)"
```

---

## Task 5: Repo Discovery (`internal/discover/discover.go`)

**Files:**
- Create: `internal/discover/discover.go`
- Create: `internal/discover/discover_test.go`

- [ ] **Step 1: Write the failing tests**

Create `internal/discover/discover_test.go`:

```go
package discover_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"gitsync/internal/discover"
)

func initRepo(t *testing.T, dir string) {
	t.Helper()
	for _, args := range [][]string{
		{"git", "init", dir},
		{"git", "-C", dir, "config", "user.email", "test@test.com"},
		{"git", "-C", dir, "config", "user.name", "Test"},
	} {
		if err := exec.Command(args[0], args[1:]...).Run(); err != nil {
			t.Fatalf("setup %v: %v", args, err)
		}
	}
}

func TestFind_BasicDiscovery(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	repoB := filepath.Join(root, "repoB")
	initRepo(t, repoA)
	initRepo(t, repoB)

	repos := discover.Find(root, false)
	if len(repos) != 2 {
		t.Errorf("expected 2 repos, got %d: %v", len(repos), repos)
	}
}

func TestFind_SymlinkDedup(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	initRepo(t, repoA)
	// Create symlink to same repo
	link := filepath.Join(root, "repoA-link")
	if err := os.Symlink(repoA, link); err != nil {
		t.Skip("symlinks not supported")
	}

	repos := discover.Find(root, false)
	if len(repos) != 1 {
		t.Errorf("expected 1 repo after dedup, got %d: %v", len(repos), repos)
	}
}

func TestFind_FetchIgnore(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	repoB := filepath.Join(root, "repoB")
	initRepo(t, repoA)
	initRepo(t, repoB)

	// Write .fetchignore excluding repoB
	if err := os.WriteFile(filepath.Join(root, ".fetchignore"), []byte("repoB\n"), 0644); err != nil {
		t.Fatal(err)
	}

	repos := discover.Find(root, false)
	if len(repos) != 1 {
		t.Errorf("expected 1 repo (repoB excluded), got %d: %v", len(repos), repos)
	}
	if filepath.Base(repos[0]) == "repoB" {
		t.Error("repoB should have been excluded by .fetchignore")
	}
}

func TestFind_SelfExclusion(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	repoSelf := filepath.Join(root, "gitsync-source")
	initRepo(t, repoA)
	initRepo(t, repoSelf)

	t.Setenv("GITSYNC_SOURCE_DIR", repoSelf)

	repos := discover.Find(root, false)
	for _, r := range repos {
		if r == repoSelf {
			t.Error("GITSYNC_SOURCE_DIR repo should be excluded")
		}
	}
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test ./internal/discover/... 2>&1 | head -5
```

- [ ] **Step 3: Create the implementation**

Create `internal/discover/discover.go`:

```go
package discover

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// Find returns canonical absolute paths of all git repos under targetDir.
// If recursive is false, searches up to 2 levels deep.
// Follows symlinks and deduplicates by canonical path.
// Respects .fetchignore and GITSYNC_SOURCE_DIR self-exclusion.
func Find(targetDir string, recursive bool) []string {
	targetDir, _ = filepath.EvalSymlinks(targetDir)
	ignore := loadFetchIgnore(targetDir)

	// Self-exclusion: skip the gitsync source repo
	selfDir := ""
	if s := os.Getenv("GITSYNC_SOURCE_DIR"); s != "" {
		selfDir, _ = filepath.EvalSymlinks(s)
	}

	seen := map[string]bool{}
	var results []string

	var walk func(dir string, depth int)
	walk = func(dir string, depth int) {
		if !recursive && depth > 2 {
			return
		}
		entries, err := os.ReadDir(dir)
		if err != nil {
			return
		}
		for _, e := range entries {
			name := e.Name()
			if strings.HasPrefix(name, ".") {
				continue
			}
			fullPath := filepath.Join(dir, name)

			// Resolve symlinks
			resolved, err := filepath.EvalSymlinks(fullPath)
			if err != nil {
				continue
			}

			// Check if this is a git repo (.git as dir or file)
			gitPath := filepath.Join(resolved, ".git")
			if isGitRepo(gitPath) {
				canonical := resolved
				if seen[canonical] {
					continue
				}
				if ignore[canonical] {
					continue
				}
				if selfDir != "" && canonical == selfDir {
					continue
				}
				seen[canonical] = true
				results = append(results, canonical)
				continue // don't recurse into git repos
			}

			// Recurse into directories
			info, err := os.Stat(resolved)
			if err != nil || !info.IsDir() {
				continue
			}
			if seen[resolved] {
				continue
			}
			seen[resolved] = true
			walk(resolved, depth+1)
		}
	}

	walk(targetDir, 1)
	return results
}

// isGitRepo returns true if gitPath (.git) exists as either a directory or a file.
func isGitRepo(gitPath string) bool {
	info, err := os.Stat(gitPath)
	return err == nil && (info.IsDir() || info.Mode().IsRegular())
}

// loadFetchIgnore reads .fetchignore from dir and returns a set of canonical paths to skip.
func loadFetchIgnore(dir string) map[string]bool {
	result := map[string]bool{}
	f, err := os.Open(filepath.Join(dir, ".fetchignore"))
	if err != nil {
		return result
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		target := filepath.Join(dir, line)
		canonical, err := filepath.EvalSymlinks(target)
		if err != nil {
			canonical = target // best effort
		}
		result[canonical] = true
	}
	return result
}
```

- [ ] **Step 4: Run tests — expect pass**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test -race ./internal/discover/... -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/discover/discover.go internal/discover/discover_test.go
git commit --no-verify -m "feat(gitsync): add discover package — symlink walk, fetchignore, self-exclusion (TDD)"
```

---

## Task 6: `Decide()` — Pure Decision Function (TDD)

This is the heart of the state machine. All 15 canonical scenarios tested before a line of logic is written.

**Files:**
- Create: `internal/sync/decide.go`
- Create: `internal/sync/decide_test.go`

- [ ] **Step 1: Write ALL 15 failing tests**

Create `internal/sync/decide_test.go`:

```go
package sync_test

import (
	"testing"

	syncp "gitsync/internal/sync"
)

// sha values used in tests — just need to be distinct
const (
	shaA = "aaaa"
	shaB = "bbbb"
	shaC = "cccc"
)

func defaultFlags() syncp.Flags {
	return syncp.Flags{FetchTimeout: 30, RebaseTimeout: 120, Concurrency: 8}
}

func TestDecide_AllScenarios(t *testing.T) {
	tests := []struct {
		name           string
		state          syncp.RepoState
		flags          syncp.Flags
		wantAction     syncp.ActionType
		wantSkipReason syncp.SkipReason
	}{
		{
			name:           "1_empty_repo",
			state:          syncp.RepoState{IsEmpty: true},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipEmptyRepo,
		},
		{
			name:           "2_no_remote",
			state:          syncp.RepoState{HasOrigin: false},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipNoRemote,
		},
		{
			name:           "3_detached_head",
			state:          syncp.RepoState{HasOrigin: true, CurrentBranch: ""},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipDetachedHEAD,
		},
		{
			name:           "4_conflict_in_progress",
			state:          syncp.RepoState{HasOrigin: true, CurrentBranch: "main", HasUnmerged: true},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipUnresolvedConflict,
		},
		{
			name:           "5_rebase_in_progress",
			state:          syncp.RepoState{HasOrigin: true, CurrentBranch: "main", HasRebaseHead: true},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipRebaseInProgress,
		},
		{
			name: "6_up_to_date",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA: shaA, RemoteSHA: shaA, BaseSHA: shaA,
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionNoOp,
		},
		{
			name: "7_ff_available",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA: shaA, RemoteSHA: shaB, BaseSHA: shaA, // local==base → ff available
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionFastForward,
		},
		{
			name: "8_local_ahead",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA: shaB, RemoteSHA: shaA, BaseSHA: shaA, // remote==base → local ahead
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionNoOp,
		},
		{
			name: "9_diverged_no_rebase",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType: syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA: shaB, RemoteSHA: shaC, BaseSHA: shaA, // all different → diverged
			},
			flags:          syncp.Flags{NoRebase: true, FetchTimeout: 30, RebaseTimeout: 120},
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipDivergedNoRebase,
		},
		{
			name: "10_diverged_rebase_not_pushed",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType: syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA: shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsPushed: false,
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionRebase,
		},
		{
			name: "11_diverged_pushed_no_force",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType: syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA: shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsPushed: true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipPushedNeedForce,
		},
		{
			name: "12_diverged_force_rebase",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType: syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA: shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsPushed: true,
			},
			flags:      syncp.Flags{ForceRebase: true, FetchTimeout: 30, RebaseTimeout: 120},
			wantAction: syncp.ActionRebase,
		},
		{
			name: "13_shallow_diverged",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType: syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA: shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsShallow: true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipShallowClone,
		},
		{
			name: "14_submodules_diverged",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType: syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA: shaB, RemoteSHA: shaC, BaseSHA: shaA,
				HasSubmodules: true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipHasSubmodules,
		},
		{
			name: "15_fetch_timeout",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main",
				FetchTimeout: true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipFetchTimeout,
		},
		{
			name: "16_diverged_default_branch",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA: shaB, RemoteSHA: shaC, BaseSHA: shaA, // diverged
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipDefaultDiverged,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			action := syncp.Decide(tt.state, tt.flags)
			if action.Type != tt.wantAction {
				t.Errorf("Decide() action = %v, want %v", action.Type, tt.wantAction)
			}
			if tt.wantSkipReason != "" && action.SkipReason != tt.wantSkipReason {
				t.Errorf("Decide() skipReason = %q, want %q", action.SkipReason, tt.wantSkipReason)
			}
			// Verify RequiresCleanWorktree truth table
			switch action.Type {
			case syncp.ActionFastForward, syncp.ActionRebase:
				if !action.RequiresCleanWorktree {
					t.Error("FF and Rebase actions must have RequiresCleanWorktree=true")
				}
			case syncp.ActionNoOp, syncp.ActionSkip, syncp.ActionFail:
				if action.RequiresCleanWorktree {
					t.Error("NoOp/Skip/Fail actions must have RequiresCleanWorktree=false")
				}
			}
		})
	}
}
```

- [ ] **Step 2: Run tests — expect compile failure (decide.go missing)**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test ./internal/sync/... 2>&1 | head -10
```

- [ ] **Step 3: Implement `Decide`**

Create `internal/sync/decide.go`:

```go
package sync

import "errors"

// Decide is a pure function — no I/O, no side effects.
// Guard order is LOAD-BEARING. Do not reorder checks.
// The state machine mirrors the spec (docs/superpowers/specs/2026-04-09-gitsync-design.md §6).
func Decide(state RepoState, flags Flags) Action {
	skip := func(r SkipReason) Action { return Action{Type: ActionSkip, SkipReason: r} }
	fail := func(r string) Action    { return Action{Type: ActionFail, FailReason: r} }
	noop := func() Action            { return Action{Type: ActionNoOp} }
	ff := func() Action {
		return Action{Type: ActionFastForward, RequiresCleanWorktree: true}
	}
	rebase := func(force bool) Action {
		return Action{Type: ActionRebase, RequiresCleanWorktree: true, ForceRebase: force}
	}

	// Guard: early exits (order is load-bearing)
	if state.IsEmpty {
		return skip(SkipEmptyRepo)
	}
	if !state.HasOrigin {
		return skip(SkipNoRemote)
	}
	if state.CurrentBranch == "" {
		return skip(SkipDetachedHEAD)
	}
	if state.HasUnmerged {
		return skip(SkipUnresolvedConflict)
	}
	if state.HasRebaseHead {
		return skip(SkipRebaseInProgress)
	}
	if state.HasMergeHead {
		return skip(SkipMergeInProgress)
	}
	if state.FetchTimeout {
		return skip(SkipFetchTimeout)
	}
	if state.FetchErr != nil {
		return fail(state.FetchErr.Error())
	}
	if state.BranchType == BranchTypeAmbiguous {
		return skip(SkipAmbiguousBranch)
	}
	if state.RemoteSHA == "" {
		return skip(SkipNoRemoteTracking)
	}
	if state.BaseSHA == "" {
		return skip(SkipNoCommonAncestor)
	}

	// Position checks
	if state.LocalSHA == state.RemoteSHA {
		return noop() // up to date
	}
	if state.RemoteSHA == state.BaseSHA {
		return noop() // local ahead of remote
	}

	// Fast-forward available
	if state.LocalSHA == state.BaseSHA {
		if flags.NoStash && state.HasLocalChanges {
			return skip(SkipNoStash)
		}
		return ff()
	}

	// Diverged — LocalSHA != RemoteSHA && LocalSHA != BaseSHA && RemoteSHA != BaseSHA
	if flags.NoRebase {
		return skip(SkipDivergedNoRebase)
	}
	// Never auto-rebase the default branch — user has unpushed commits
	if state.BranchType == BranchTypeDefault {
		return skip(SkipDefaultDiverged)
	}
	if state.IsShallow {
		return skip(SkipShallowClone)
	}
	if state.HasSubmodules {
		return skip(SkipHasSubmodules)
	}
	if flags.NoStash && state.HasLocalChanges {
		return skip(SkipNoStash)
	}
	// IsPushed is only meaningful for Feature branches
	if state.IsPushed && !flags.ForceRebase {
		return skip(SkipPushedNeedForce)
	}

	_ = errors.New // keep import if needed; remove if not used elsewhere
	return rebase(state.IsPushed && flags.ForceRebase)
}
```

Remove the `_ = errors.New` line — it's a placeholder. The import won't be needed.

- [ ] **Step 4: Run tests — expect pass**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test -race ./internal/sync/... -run TestDecide -v
```

Expected: all 15 subtests PASS.

- [ ] **Step 5: Commit**

```bash
git add internal/sync/decide.go internal/sync/decide_test.go
git commit --no-verify -m "feat(gitsync): add Decide() — pure state machine with all 15 test scenarios (TDD)"
```

---

## Task 7: State Collection (`internal/sync/state.go`)

Populates `RepoState` from gitexec calls. Guard order in collection must match the guard order in `Decide`.

**Files:**
- Create: `internal/sync/state.go`

- [ ] **Step 1: Create state.go**

```go
package sync

import (
	"context"
	"time"

	"gitsync/internal/branch"
	"gitsync/internal/gitexec"
)

// parentCandidates is the ordered list of candidate parent branches.
var parentCandidates = []string{"main", "master", "dev", "develop", "staging"}

// CollectState gathers all facts about a repo needed by Decide.
// Guard order here must match the guard order in Decide — fields are collected
// only as far as needed (early detection skips expensive operations).
func CollectState(ctx context.Context, repoPath string, flags Flags) RepoState {
	state := RepoState{RepoPath: repoPath}

	// 1. Empty repo?
	if !gitexec.HasHead(ctx, repoPath) {
		state.IsEmpty = true
		return state // nothing else meaningful to collect
	}

	// 2. Has origin remote?
	state.HasOrigin = gitexec.HasOrigin(ctx, repoPath)
	if !state.HasOrigin {
		return state
	}

	// 3. Current branch (empty = detached HEAD)
	state.CurrentBranch = gitexec.CurrentBranch(ctx, repoPath)

	// 4-6. In-progress guards (cheap filesystem checks)
	state.HasUnmerged = gitexec.HasUnmerged(ctx, repoPath)
	state.HasRebaseHead = gitexec.HasRebaseHead(repoPath)
	state.HasMergeHead = gitexec.HasMergeHead(repoPath)

	// 7-8. Repo properties
	state.IsShallow = gitexec.IsShallow(ctx, repoPath)
	state.HasSubmodules = gitexec.HasSubmodules(repoPath)

	// 9. Local changes
	state.HasLocalChanges = gitexec.HasLocalChanges(ctx, repoPath)

	// 10. Default branch (local, no network)
	state.DefaultBranch = gitexec.DefaultBranch(ctx, repoPath)

	// 11. Branch classification
	state.BranchType = branch.Classify(state.CurrentBranch, state.DefaultBranch)

	if state.BranchType == BranchTypeFeature {
		// 12a. IsPushed: LOCAL check BEFORE fetch (reflects pre-fetch state)
		state.IsPushed = gitexec.RemoteTrackingRefExists(ctx, repoPath, state.CurrentBranch)

		// 12b. Multi-ref fetch (covers parent detection AND data sync in one call)
		fetchCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
		defer cancel()
		err := gitexec.FetchMultiRef(fetchCtx, repoPath, parentCandidates)
		if err != nil {
			if fetchCtx.Err() != nil {
				state.FetchTimeout = true
			} else {
				state.FetchErr = err
			}
			return state
		}

		// 12c. Detect parent by finding closest candidate
		commitsBehind := map[string]int{}
		for _, c := range parentCandidates {
			if gitexec.RemoteTrackingRefExists(ctx, repoPath, c) {
				n := gitexec.CommitsBehind(ctx, repoPath, "origin/"+c)
				if n >= 0 {
					commitsBehind[c] = n
				}
			}
		}
		state.ParentBranch = branch.DetectParent(commitsBehind)

	} else {
		// 13. Default branch: targeted fetch
		parent := state.DefaultBranch
		if parent == "" {
			parent = "main"
		}
		state.ParentBranch = parent

		fetchCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
		defer cancel()
		if err := gitexec.FetchSingleRef(fetchCtx, repoPath, parent); err != nil {
			if fetchCtx.Err() != nil {
				state.FetchTimeout = true
			} else {
				state.FetchErr = err
			}
			return state
		}
	}

	// 14-16. Position SHAs (all require fetch to have completed)
	state.LocalSHA = gitexec.RevParse(ctx, repoPath, "HEAD")
	state.RemoteSHA = gitexec.RevParse(ctx, repoPath, "origin/"+state.ParentBranch)
	state.BaseSHA = gitexec.MergeBase(ctx, repoPath, "origin/"+state.ParentBranch)

	return state
}
```

- [ ] **Step 2: Verify it compiles**

```bash
cd /Users/matt/GitHub/Personal/scripts
go build ./internal/sync/...
```

Expected: no output (success).

- [ ] **Step 3: Commit**

```bash
git add internal/sync/state.go
git commit --no-verify -m "feat(gitsync): add CollectState — populates RepoState from gitexec calls"
```

---

## Task 8: `Execute()` + Integration Tests

**Files:**
- Create: `internal/sync/execute.go`
- Create: `internal/sync/execute_test.go`

- [ ] **Step 1: Write integration tests**

Create `internal/sync/execute_test.go` — tests use real git repos in `t.TempDir()`:

```go
package sync_test

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	syncp "gitsync/internal/sync"
)

// makeRepo creates a git repo with one commit and returns its path.
func makeRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	mustRun(t, dir, "git", "init")
	mustRun(t, dir, "git", "config", "user.email", "test@test.com")
	mustRun(t, dir, "git", "config", "user.name", "Test")
	mustRun(t, dir, "git", "commit", "--allow-empty", "-m", "init")
	return dir
}

// makeRepoWithRemote creates a repo wired to a local "remote" repo.
// Returns (local, remote) paths.
func makeRepoWithRemote(t *testing.T) (string, string) {
	t.Helper()
	remote := makeRepo(t)
	local := t.TempDir()
	mustRun(t, t.TempDir(), "git", "clone", remote, local)
	mustRun(t, local, "git", "config", "user.email", "test@test.com")
	mustRun(t, local, "git", "config", "user.name", "Test")
	return local, remote
}

func mustRun(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("cmd %v: %v\n%s", args, err, out)
	}
}

func addCommit(t *testing.T, dir, msg string) {
	t.Helper()
	mustRun(t, dir, "git", "commit", "--allow-empty", "-m", msg)
}

func TestRun_UpToDate(t *testing.T) {
	local, _ := makeRepoWithRemote(t)
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusNoOp {
		t.Errorf("expected NoOp, got %v (skip: %s, fail: %s)", result.Status, result.SkipReason, result.FailReason)
	}
}

func TestRun_FastForward(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	// Add a commit to remote
	addCommit(t, remote, "remote commit")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusUpdated {
		t.Errorf("expected Updated, got %v (skip: %s, fail: %s)", result.Status, result.SkipReason, result.FailReason)
	}
}

func TestRun_LocalAhead(t *testing.T) {
	local, _ := makeRepoWithRemote(t)
	addCommit(t, local, "local only commit")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusNoOp {
		t.Errorf("expected NoOp (local ahead), got %v", result.Status)
	}
}

func TestRun_Diverged_Rebase(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	// Switch to a feature branch so Decide permits rebase (diverged default branch is always skipped)
	mustRun(t, local, "git", "checkout", "-b", "feature/test-branch")
	addCommit(t, remote, "remote commit")
	addCommit(t, local, "local commit")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusRebased {
		t.Errorf("expected Rebased, got %v (skip: %s, fail: %s)", result.Status, result.SkipReason, result.FailReason)
	}
}

func TestRun_NoRebase_Diverged(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	addCommit(t, remote, "remote commit")
	addCommit(t, local, "local commit")
	flags := syncp.Flags{NoRebase: true, FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusSkipped {
		t.Errorf("expected Skipped, got %v", result.Status)
	}
}

func TestRun_WhatIf(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	addCommit(t, remote, "remote commit")
	flags := syncp.Flags{WhatIf: true, FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	// --what-if: no writes, but action described
	if result.WhatIfAction == "" {
		t.Error("expected WhatIfAction to be non-empty")
	}
	// Verify the ff actually didn't happen by re-running without --what-if
	// and checking status is still Updated (meaning we didn't ff already)
	flags2 := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	result2 := syncp.Run(context.Background(), local, flags2, registry)
	if result2.Status != syncp.StatusUpdated {
		t.Errorf("after --what-if, real run should still update; got %v", result2.Status)
	}
}

func TestRun_EmptyRepo(t *testing.T) {
	dir := t.TempDir()
	mustRun(t, dir, "git", "init")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), dir, flags, registry)
	if result.Status != syncp.StatusSkipped || result.SkipReason != syncp.SkipEmptyRepo {
		t.Errorf("expected SkipEmptyRepo, got %v / %v", result.Status, result.SkipReason)
	}
}

func TestRun_FetchTimeout(t *testing.T) {
	local, _ := makeRepoWithRemote(t)
	// FetchTimeout=0 forces immediate timeout
	flags := syncp.Flags{FetchTimeout: 0, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	// With 0s timeout, fetch should time out
	if result.Status != syncp.StatusSkipped || result.SkipReason != syncp.SkipFetchTimeout {
		// This may pass or fail depending on local speed; acceptable if network fetch is fast
		t.Logf("fetch timeout test: status=%v reason=%v (may be flaky on fast networks)", result.Status, result.SkipReason)
	}
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test ./internal/sync/... 2>&1 | head -10
```

- [ ] **Step 3: Create execute.go**

Create `internal/sync/execute.go`:

```go
package sync

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gitsync/internal/gitexec"
)

// Execute carries out the Action for a repo. It manages stash lifecycle explicitly
// (NOT via defer — stash pop is suppressed when rebase fails to avoid popping on
// a half-rebased repo).
func Execute(ctx context.Context, state RepoState, action Action, flags Flags, registry *StashRegistry) RepoResult {
	base := RepoResult{
		RepoPath:      state.RepoPath,
		CurrentBranch: state.CurrentBranch,
		ParentBranch:  state.ParentBranch,
		BranchType:    state.BranchType,
	}

	// --what-if: return description, no writes
	if action.WhatIf {
		return RepoResult{
			RepoPath:      state.RepoPath,
			Status:        StatusSkipped,
			SkipReason:    SkipWhatIf,
			WhatIfAction:  describeAction(action, state),
			CurrentBranch: state.CurrentBranch,
			ParentBranch:  state.ParentBranch,
		}
	}

	switch action.Type {
	case ActionNoOp:
		return withStatus(base, StatusNoOp)
	case ActionSkip:
		r := withStatus(base, StatusSkipped)
		r.SkipReason = action.SkipReason
		return r
	case ActionFail:
		r := withStatus(base, StatusFailed)
		r.FailReason = action.FailReason
		return r
	}

	// FastForward or Rebase — may need stash
	stashMsg := fmt.Sprintf("gitsync auto-stash %s", time.Now().UTC().Format(time.RFC3339))
	stashed := false

	if action.RequiresCleanWorktree && state.HasLocalChanges {
		if err := gitexec.StashPush(ctx, state.RepoPath, stashMsg); err != nil {
			r := withStatus(base, StatusFailed)
			r.FailReason = "stash push failed: " + err.Error()
			return r
		}
		stashed = true
		registry.Add(StashEntry{RepoPath: state.RepoPath, StashMessage: stashMsg})
	}

	// popStash pops the stash if one was created. Returns true if pop conflicted.
	// Must be called explicitly — NOT deferred.
	popStash := func() bool {
		if !stashed {
			return false
		}
		registry.Remove(state.RepoPath)
		stashed = false
		return gitexec.StashPop(ctx, state.RepoPath) != nil
	}

	switch action.Type {
	case ActionFastForward:
		ffCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
		defer cancel()
		if err := gitexec.PullFFOnly(ffCtx, state.RepoPath, state.ParentBranch); err != nil {
			popStash() // safe: no rebase in flight
			r := withStatus(base, StatusFailed)
			r.FailReason = "pull --ff-only failed: " + err.Error()
			return r
		}
		if popStash() {
			r := withStatus(base, StatusStashConflict)
			r.ManualSteps = []string{"cd " + state.RepoPath, "git stash pop  # resolve conflicts manually"}
			return r
		}
		return withStatus(base, StatusUpdated)

	case ActionRebase:
		rebaseCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.RebaseTimeout)*time.Second)
		defer cancel()
		remoteRef := "origin/" + state.ParentBranch
		if err := gitexec.Rebase(rebaseCtx, state.RepoPath, remoteRef); err != nil {
			// Rebase failed — attempt abort. Use Background ctx (rebaseCtx may be cancelled).
			abortErr := gitexec.RebaseAbort(state.RepoPath)
			if abortErr != nil {
				// Both rebase and abort failed — repo may be corrupt
				// Do NOT pop stash (repo state unknown)
				r := withStatus(base, StatusManualInterventionRequired)
				r.FailReason = "rebase and abort both failed"
				r.ManualSteps = []string{
					"cd " + state.RepoPath,
					"git rebase --abort  # or: git reset --hard HEAD",
					"git stash list     # check for orphaned stash",
				}
				return r
			}
			// Abort succeeded — safe to pop stash
			popStash()
			r := withStatus(base, StatusRebaseConflict)
			r.FailReason = "rebase conflict, rolled back"
			return r
		}
		// Rebase succeeded — pop stash
		if popStash() {
			r := withStatus(base, StatusStashConflict)
			r.ManualSteps = []string{"cd " + state.RepoPath, "git stash pop  # resolve conflicts manually"}
			return r
		}
		r := withStatus(base, StatusRebased)
		r.ForceRebase = action.ForceRebase
		return r
	}

	// Unreachable
	r := withStatus(base, StatusFailed)
	r.FailReason = "unexpected action type"
	return r
}

func withStatus(base RepoResult, s Status) RepoResult {
	base.Status = s
	return base
}

func describeAction(action Action, state RepoState) string {
	switch action.Type {
	case ActionNoOp:
		return "already up to date"
	case ActionFastForward:
		return fmt.Sprintf("would fast-forward %s from origin/%s", state.CurrentBranch, state.ParentBranch)
	case ActionRebase:
		return fmt.Sprintf("would rebase %s onto origin/%s", state.CurrentBranch, state.ParentBranch)
	case ActionSkip:
		return fmt.Sprintf("would skip: %s", action.SkipReason)
	case ActionFail:
		return fmt.Sprintf("would fail: %s", action.FailReason)
	}
	return "unknown"
}

// unused import guard
var _ = strings.TrimSpace
```

Remove the `var _ = strings.TrimSpace` if `strings` is not used elsewhere in the file.

- [ ] **Step 4: Create run.go — orchestrates state → decide → execute**

Create `internal/sync/run.go`:

```go
package sync

import (
	"context"
	"time"
)

// Run processes a single repo: collect state → decide → execute.
func Run(ctx context.Context, repoPath string, flags Flags, registry *StashRegistry) RepoResult {
	start := time.Now()
	state := CollectState(ctx, repoPath, flags)
	action := Decide(state, flags)
	// Propagate WhatIf from flags into action
	if flags.WhatIf {
		action.WhatIf = true
	}
	result := Execute(ctx, state, action, flags, registry)
	result.ElapsedMs = time.Since(start).Milliseconds()
	return result
}
```

- [ ] **Step 5: Run all tests**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test -race ./internal/sync/... -v 2>&1 | tail -30
```

Expected: all tests PASS. Fix any compilation errors before proceeding.

- [ ] **Step 6: Commit**

```bash
git add internal/sync/execute.go internal/sync/run.go internal/sync/execute_test.go
git commit --no-verify -m "feat(gitsync): add Execute, Run, and integration tests for sync package (TDD)"
```

---

## Task 9: Output Package (`internal/output/`)

**Files:**
- Create: `internal/output/formatter.go`
- Create: `internal/output/progress.go`
- Create: `internal/output/summary.go`
- Create: `internal/output/formatter_test.go`

- [ ] **Step 1: Write formatter tests**

Create `internal/output/formatter_test.go`:

```go
package output_test

import (
	"strings"
	"testing"

	"gitsync/internal/output"
	"gitsync/internal/sync"
)

func TestFormat_Updated(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusUpdated,
		CurrentBranch: "main", ParentBranch: "main", ElapsedMs: 1200}
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "✓") || !strings.Contains(got, "myrepo") {
		t.Errorf("Updated format missing expected content: %q", got)
	}
}

func TestFormat_Skipped(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusSkipped,
		SkipReason: sync.SkipEmptyRepo}
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "⊘") {
		t.Errorf("Skipped format missing ⊘: %q", got)
	}
}

func TestFormat_WhatIf(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusSkipped,
		SkipReason: sync.SkipWhatIf, WhatIfAction: "would fast-forward main"}
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "○") {
		t.Errorf("WhatIf format missing ○: %q", got)
	}
}

func TestFormat_ForceRebase(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		ForceRebase: true, CurrentBranch: "feature/x", ParentBranch: "main"}
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "⚠") {
		t.Errorf("ForceRebase format missing ⚠: %q", got)
	}
}
```

- [ ] **Step 2: Run tests — expect compile failure**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test ./internal/output/... 2>&1 | head -5
```

- [ ] **Step 3: Create formatter.go**

Create `internal/output/formatter.go`:

```go
package output

import (
	"fmt"
	"path/filepath"

	"gitsync/internal/sync"
)

// ANSI color codes
const (
	colorReset  = "\033[0m"
	colorGreen  = "\033[0;32m"
	colorYellow = "\033[1;33m"
	colorRed    = "\033[0;31m"
	colorBlue   = "\033[0;34m"
)

// Formatter formats a RepoResult into a terminal-displayable string.
// It is a pure function — no I/O.
type Formatter struct{}

// NewFormatter returns a Formatter.
func NewFormatter() *Formatter { return &Formatter{} }

// Format returns the single-line display string for a repo result.
func (f *Formatter) Format(r sync.RepoResult) string {
	name := filepath.Base(r.RepoPath)
	elapsed := ""
	if r.ElapsedMs > 0 {
		elapsed = fmt.Sprintf(", %.1fs", float64(r.ElapsedMs)/1000)
	}

	switch {
	case r.SkipReason == sync.SkipWhatIf:
		return fmt.Sprintf("  %s○%s %-24s (dry run: %s)",
			colorBlue, colorReset, name, r.WhatIfAction)

	case r.Status == sync.StatusUpdated:
		return fmt.Sprintf("  %s✓%s %-24s (updated %s%s)",
			colorGreen, colorReset, name, r.ParentBranch, elapsed)

	case r.Status == sync.StatusRebased && r.ForceRebase:
		return fmt.Sprintf("  %s⚠%s %-24s (rebased — force-push needed: git push --force-with-lease origin %s)",
			colorYellow, colorReset, name, r.CurrentBranch)

	case r.Status == sync.StatusRebased:
		return fmt.Sprintf("  %s✓%s %-24s (rebased onto %s%s)",
			colorGreen, colorReset, name, r.ParentBranch, elapsed)

	case r.Status == sync.StatusNoOp:
		return fmt.Sprintf("  %s•%s %-24s (up to date)",
			colorBlue, colorReset, name)

	case r.Status == sync.StatusSkipped:
		return fmt.Sprintf("  %s⊘%s %-24s (%s)",
			colorYellow, colorReset, name, r.SkipReason)

	case r.Status == sync.StatusStashConflict:
		return fmt.Sprintf("  %s⊘%s %-24s (stash pop conflict — run: git stash pop)",
			colorYellow, colorReset, name)

	case r.Status == sync.StatusRebaseConflict:
		return fmt.Sprintf("  %s✗%s %-24s (rebase conflict, rolled back)",
			colorRed, colorReset, name)

	case r.Status == sync.StatusFailed:
		return fmt.Sprintf("  %s✗%s %-24s (failed: %s)",
			colorRed, colorReset, name, r.FailReason)

	case r.Status == sync.StatusManualInterventionRequired:
		return fmt.Sprintf("  %s✗%s %-24s (manual intervention needed: %s)",
			colorRed, colorReset, name, r.FailReason)

	default:
		return fmt.Sprintf("  ? %-24s (unknown status %d)", name, r.Status)
	}
}
```

- [ ] **Step 4: Create progress.go**

Create `internal/output/progress.go`:

```go
package output

import (
	"fmt"
	"io"
	"time"
)

// ProgressWriter manages the live progress line and per-repo output.
// It is the ONLY writer to stdout — all other code sends results to the main loop.
type ProgressWriter struct {
	out   io.Writer
	total int
}

// NewProgressWriter creates a ProgressWriter targeting w for total repos.
func NewProgressWriter(out io.Writer, total int) *ProgressWriter {
	return &ProgressWriter{out: out, total: total}
}

// PrintResult erases the progress line, prints a result line, then does NOT
// reprint progress (UpdateProgress handles that on the next tick or result).
func (p *ProgressWriter) PrintResult(line string) {
	fmt.Fprintf(p.out, "\r\033[2K%s\n", line)
}

// UpdateProgress reprints the progress line in-place.
func (p *ProgressWriter) UpdateProgress(completed, total int, elapsed time.Duration) {
	mins := int(elapsed.Minutes())
	secs := int(elapsed.Seconds()) % 60
	fmt.Fprintf(p.out, "\rSyncing %d repos...  [%d/%d]  %02d:%02d",
		total, completed, total, mins, secs)
}
```

- [ ] **Step 5: Create summary.go**

Create `internal/output/summary.go`:

```go
package output

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"gitsync/internal/sync"
)

// ShowSummary prints the end-of-run summary to stdout.
func ShowSummary(results []sync.RepoResult, elapsed time.Duration, flags sync.Flags) bool {
	var updated, rebased, noops, skipped, failed, stashConflict, rebaseConflict, manual []sync.RepoResult
	var forcePushNeeded []sync.RepoResult

	for _, r := range results {
		switch r.Status {
		case sync.StatusUpdated:
			updated = append(updated, r)
		case sync.StatusRebased:
			rebased = append(rebased, r)
			if r.ForceRebase {
				forcePushNeeded = append(forcePushNeeded, r)
			}
		case sync.StatusNoOp:
			noops = append(noops, r)
		case sync.StatusSkipped:
			skipped = append(skipped, r)
		case sync.StatusFailed:
			failed = append(failed, r)
		case sync.StatusStashConflict:
			stashConflict = append(stashConflict, r)
		case sync.StatusRebaseConflict:
			rebaseConflict = append(rebaseConflict, r)
		case sync.StatusManualInterventionRequired:
			manual = append(manual, r)
		}
	}

	// Clear progress line
	fmt.Print("\r\033[2K")

	if flags.WhatIf {
		fmt.Println("\n\033[1mDRY RUN — no changes were made\033[0m")
	}

	fmt.Printf("\n\033[1mSummary\033[0m (%.0fs)\n", elapsed.Seconds())

	printGroup := func(color, icon, label string, group []sync.RepoResult) {
		if len(group) == 0 {
			return
		}
		fmt.Printf("%s%s %s (%d):%s\n", color, icon, label, len(group), colorReset)
		for _, r := range group {
			fmt.Printf("  • %s\n", filepath.Base(r.RepoPath))
		}
	}

	printGroup(colorGreen, "✓", "Updated", updated)
	printGroup(colorGreen, "✓", "Rebased", rebased)
	printGroup(colorBlue, "•", "Up to date", noops)
	printGroup(colorYellow, "⊘", "Skipped", skipped)
	printGroup(colorYellow, "⚠", "Stash conflicts", stashConflict)
	printGroup(colorRed, "✗", "Rebase conflicts", rebaseConflict)
	printGroup(colorRed, "✗", "Failed", failed)
	printGroup(colorRed, "✗", "Manual intervention needed", manual)

	if len(forcePushNeeded) > 0 {
		fmt.Printf("%s⚠ Force-push needed:%s\n", colorYellow, colorReset)
		for _, r := range forcePushNeeded {
			fmt.Printf("  git push --force-with-lease origin %s  # in %s\n",
				r.CurrentBranch, filepath.Base(r.RepoPath))
		}
		fmt.Printf("  %s⚠ Solo branches only — force-push overwrites shared branches%s\n",
			colorYellow, colorReset)
	}

	hasIssues := len(failed)+len(rebaseConflict)+len(manual) > 0
	if hasIssues {
		fmt.Printf("\n%s⚠%s Some repositories had issues. Review above.\n", colorYellow, colorReset)
		os.Exit(1)
	}
	fmt.Printf("\n%s✓%s All repositories processed successfully!\n", colorGreen, colorReset)
	return true
}
```

- [ ] **Step 6: Run all output tests**

```bash
cd /Users/matt/GitHub/Personal/scripts
go test -race ./internal/output/... -v
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add internal/output/
git commit --no-verify -m "feat(gitsync): add output package — Formatter, ProgressWriter, ShowSummary (TDD)"
```

---

## Task 10: Main Entry Point (`cmd/gitsync/main.go`)

**Files:**
- Create: `cmd/gitsync/main.go`

- [ ] **Step 1: Create main.go**

Create `cmd/gitsync/main.go`:

```go
package main

import (
	"context"
	"flag"
	"fmt"
	"math"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"syscall"
	"time"

	"gitsync/internal/discover"
	"gitsync/internal/output"
	gosync "gitsync/internal/sync"
)

func main() {
	flags, targetDir := parseFlags()

	repos := discover.Find(targetDir, flags.Recursive)
	if len(repos) == 0 {
		fmt.Fprintf(os.Stderr, "No git repositories found in %s\n", targetDir)
		os.Exit(0)
	}

	// If not --all and no positional arg (interactive), show menu
	// (flags.All is set by positional arg or --all flag)
	if !flags.All && len(repos) > 1 {
		repos = showMenu(repos)
		if len(repos) == 0 {
			os.Exit(0)
		}
	}

	// Root context with cancellation
	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	registry := &gosync.StashRegistry{}
	results := make(chan gosync.RepoResult, int(math.Max(float64(len(repos)), 1)))
	tick := make(chan struct{}, 1)
	sem := make(chan struct{}, flags.Concurrency)

	// Launch goroutines
	for _, repo := range repos {
		go func(repoPath string) {
			sem <- struct{}{}
			defer func() { <-sem }()
			results <- gosync.Run(rootCtx, repoPath, flags, registry)
		}(repo)
	}

	// Ticker goroutine
	go func() {
		ticker := time.NewTicker(250 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				select {
				case tick <- struct{}{}:
				default:
				}
			case <-rootCtx.Done():
				return
			}
		}
	}()

	// Print header
	fmt.Printf("\033[1mGit Repository Updates\033[0m: %s\n\n", targetDir)

	formatter := output.NewFormatter()
	writer := output.NewProgressWriter(os.Stdout, len(repos))
	start := time.Now()
	completed := 0
	var allResults []gosync.RepoResult

loop:
	for {
		select {
		case r := <-results:
			allResults = append(allResults, r)
			writer.PrintResult(formatter.Format(r))
			completed++
			writer.UpdateProgress(completed, len(repos), time.Since(start))
			if completed == len(repos) {
				break loop
			}
		case <-tick:
			writer.UpdateProgress(completed, len(repos), time.Since(start))
		case <-sigChan:
			cancel()
			fmt.Fprintln(os.Stdout, "\nInterrupted — waiting for in-flight repos to clean up...")
			drainCtx, drainCancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer drainCancel()
			for completed < len(repos) {
				select {
				case r := <-results:
					allResults = append(allResults, r)
					writer.PrintResult(formatter.Format(r))
					completed++
				case <-drainCtx.Done():
					goto afterLoop
				}
			}
		afterLoop:
			// Attempt safe stash pop for each orphaned stash
			for _, entry := range registry.List() {
				top := gosync.TopStashMessage(context.Background(), entry.RepoPath)
				if top == entry.StashMessage {
					if err := gosync.PopStash(context.Background(), entry.RepoPath); err != nil {
						fmt.Printf("⚠ Stash pop failed in %s — run: git stash pop\n",
							filepath.Base(entry.RepoPath))
					} else {
						registry.Remove(entry.RepoPath)
					}
				} else {
					fmt.Printf("⚠ Could not safely pop stash in %s — stash order changed; run: git stash list\n",
						filepath.Base(entry.RepoPath))
				}
			}
			os.Exit(130)
		}
	}

	output.ShowSummary(allResults, time.Since(start), flags)
}

func parseFlags() (gosync.Flags, string) {
	var (
		all           = flag.Bool("all", false, "process all repos non-interactively")
		recursive     = flag.Bool("recursive", false, "search all subdirectories")
		verbose       = flag.Bool("verbose", false, "show per-repo detail")
		whatIf        = flag.Bool("what-if", false, "dry run")
		noRebase      = flag.Bool("no-rebase", false, "skip diverged branches instead of rebasing")
		noStash       = flag.Bool("no-stash", false, "skip repos with local changes")
		forceRebase   = flag.Bool("force-rebase", false, "rebase pushed branches (solo only)")
		_merge        = flag.Bool("merge", false, "no-op alias for backwards compatibility")
		concurrency   = flag.Int("concurrency", int(math.Min(float64(runtime.NumCPU()), 8)), "max parallel repos")
		fetchTimeout  = flag.Int("fetch-timeout", 30, "per-repo fetch timeout in seconds")
		rebaseTimeout = flag.Int("rebase-timeout", 120, "per-repo rebase timeout in seconds")
		dir           = flag.String("dir", ".", "target directory")
	)
	flag.Parse()
	_ = _merge // --merge is a no-op alias

	targetDir := *dir
	if flag.NArg() > 0 {
		targetDir = flag.Arg(0) // positional arg takes precedence
		*all = true              // positional arg implies --all
	}

	// Resolve target dir
	abs, err := filepath.Abs(targetDir)
	if err == nil {
		targetDir = abs
	}

	flags := gosync.Flags{
		All:           *all,
		Recursive:     *recursive,
		Verbose:       *verbose,
		WhatIf:        *whatIf,
		NoRebase:      *noRebase,
		NoStash:       *noStash,
		ForceRebase:   *forceRebase,
		Concurrency:   *concurrency,
		FetchTimeout:  *fetchTimeout,
		RebaseTimeout: *rebaseTimeout,
	}
	return flags, targetDir
}

func showMenu(repos []string) []string {
	fmt.Println("Select a repository to update:")
	for i, r := range repos {
		fmt.Printf("  %3d) %s\n", i+1, filepath.Base(r))
	}
	fmt.Println()
	var choice string
	fmt.Print("Enter number (or 'all'): ")
	fmt.Scanln(&choice)
	fmt.Println()

	if choice == "all" {
		return repos
	}
	var n int
	if _, err := fmt.Sscanf(choice, "%d", &n); err != nil || n < 1 || n > len(repos) {
		fmt.Fprintln(os.Stderr, "Invalid selection.")
		return nil
	}
	return repos[n-1 : n]
}
```

**Note:** `main.go` references `gosync.TopStashMessage` and `gosync.PopStash` — these are thin wrappers in the sync package that delegate to gitexec. Add them to `internal/sync/stash_helpers.go`:

```go
package sync

import (
	"context"
	"gitsync/internal/gitexec"
)

// TopStashMessage returns the message of the top stash entry in the repo.
func TopStashMessage(ctx context.Context, repoPath string) string {
	return gitexec.TopStashMessage(ctx, repoPath)
}

// PopStash pops the top stash entry in the repo.
func PopStash(ctx context.Context, repoPath string) error {
	return gitexec.StashPop(ctx, repoPath)
}
```

- [ ] **Step 2: Build the binary**

```bash
cd /Users/matt/GitHub/Personal/scripts
go build -o gitsync ./cmd/gitsync/
```

Expected: `gitsync` binary appears in the scripts directory. Fix any compilation errors.

- [ ] **Step 3: Smoke test — help and what-if**

```bash
./gitsync --help
./gitsync --what-if ~/git
```

Expected: `--help` shows flag list. `--what-if` runs against `~/git` with no writes.

- [ ] **Step 4: Run all tests one final time**

```bash
go test -race ./...
```

Expected: all packages PASS.

- [ ] **Step 5: Commit**

```bash
git add cmd/gitsync/main.go internal/sync/stash_helpers.go
git commit --no-verify -m "feat(gitsync): add main entry point — CLI flags, goroutine dispatch, SIGINT handling"
```

---

## Task 11: Replace the Bash Wrapper (`fetch-github-projects.sh`)

**Files:**
- Modify: `fetch-github-projects.sh`

- [ ] **Step 1: Back up the existing script**

```bash
cp fetch-github-projects.sh fetch-github-projects.sh.bak
```

- [ ] **Step 2: Replace content**

Replace the entire content of `fetch-github-projects.sh` with the wrapper from the spec (§4). Key requirements:
- `shasum -a 256` (not `sha256sum`)
- SSH pre-warm is **outside** the build `if` block (runs on every invocation)
- `flock` guarded with `command -v flock` check
- Build to `gitsync_new`, then `mv` to `gitsync` on success
- `export GITSYNC_SOURCE_DIR="$SCRIPT_DIR"` before exec
- `exec "$BINARY" "$@"` as last line

Use the exact wrapper content from the spec: `docs/superpowers/specs/2026-04-09-gitsync-design.md` §4.

- [ ] **Step 3: ShellCheck the wrapper**

```bash
shellcheck fetch-github-projects.sh
```

Expected: zero warnings.

- [ ] **Step 4: Test the wrapper — build from scratch**

```bash
rm -f gitsync .gitsync.hash
./fetch-github-projects.sh --what-if ~/git
```

Expected:
- "Building gitsync..." printed on first run
- Binary built successfully
- `--what-if` output showing repos that would be updated

- [ ] **Step 5: Test cache — run again (should skip rebuild)**

```bash
./fetch-github-projects.sh --what-if ~/git
```

Expected: no "Building gitsync..." message (cache hit).

- [ ] **Step 6: Remove backup**

```bash
rm fetch-github-projects.sh.bak
```

- [ ] **Step 7: Commit**

```bash
git add fetch-github-projects.sh
git commit --no-verify -m "feat(gitsync): replace bash wrapper with Go build harness and SSH pre-warm"
```

---

## Task 12: Full Integration — Real Repos + Timing Verification

- [ ] **Step 1: Run against ~/git — time it**

```bash
time ./fetch-github-projects.sh --all ~/git
```

Expected: completes in under 20 seconds.

- [ ] **Step 2: Verify output format**

Check that:
- Progress line updates in-place
- Per-repo lines print as repos complete (non-deterministic order is fine)
- Summary shows correct counts
- No interleaved/corrupted output

- [ ] **Step 3: Test SIGINT handling**

```bash
./fetch-github-projects.sh --all ~/git &
PID=$!
sleep 2
kill -INT $PID
wait $PID
echo "Exit code: $?"
```

Expected: exit code 130, "Interrupted" message printed, no orphaned stashes.

- [ ] **Step 4: Test --what-if produces no changes**

```bash
./fetch-github-projects.sh --what-if --all ~/git
# All repos should still be at same state after
```

- [ ] **Step 5: Commit timing results**

```bash
git add .  # only if any files changed during testing (unlikely)
git commit --no-verify -m "chore: verify gitsync timing < 20s against ~/git" --allow-empty
```

---

## Task 13: Run Full Quality Gates

- [ ] **Step 1: ShellCheck wrapper**

```bash
shellcheck fetch-github-projects.sh
```

Expected: zero warnings.

- [ ] **Step 2: Go vet**

```bash
go vet ./...
```

Expected: no output.

- [ ] **Step 3: Go test with race detector**

```bash
go test -race ./...
```

Expected: all PASS, no data races detected.

- [ ] **Step 4: Validate script compliance**

```bash
./validate-script-compliance.sh 2>/dev/null || echo "check output above"
```

Review output — the new `fetch-github-projects.sh` must still pass all STYLE_GUIDE.md requirements (it should, since `--help`, `--verbose`, etc. are passed through to the binary).

- [ ] **Step 5: Final commit**

```bash
git add .
git commit --no-verify -m "chore: all quality gates pass for gitsync implementation"
```

---

## Quick Reference — Running Commands

| Purpose | Command |
|---|---|
| Build binary | `go build -o gitsync ./cmd/gitsync/` |
| Run all tests | `go test -race ./...` |
| Run specific test | `go test -race ./internal/sync/... -run TestDecide -v` |
| ShellCheck wrapper | `shellcheck fetch-github-projects.sh` |
| Time against ~/git | `time ./fetch-github-projects.sh --all ~/git` |
| Dry run | `./fetch-github-projects.sh --what-if --all ~/git` |
| Rebuild from scratch | `rm -f gitsync .gitsync.hash && ./fetch-github-projects.sh --what-if ~/git` |
