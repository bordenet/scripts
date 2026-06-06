package sync

import (
	"context"
	"errors"
	"strings"
	"time"
	"unicode/utf8"

	"gitsync/internal/branch"
	"gitsync/internal/gitexec"
)

// parentCandidates is the ordered list of candidate parent branches.
var parentCandidates = []string{"main", "master", "dev", "develop", "staging"}

// fetchWithBudget runs fn with a fetch ctx whose deadline is
// perAttempt × FetchMaxAttempts × refCount. It calls cancel() before
// returning so the caller never sees a leaked context.
//
// refCount lets multi-ref callers (FetchMultiRef iterates 5 parent candidates)
// allocate a fair share to every ref instead of letting a flaky first ref
// drain the whole budget — without refCount, the second-through-Nth refs
// would never run when ref-1 hits transient errors. Single-ref callers pass 1.
//
// Budget semantics:
//   - perAttempt > 0  → totalBudget = perAttempt × FetchMaxAttempts × refCount.
//   - perAttempt <= 0 → totalBudget = 0, which context.WithTimeout treats as
//     an already-expired ctx. Preserves the existing test pattern where
//     FetchTimeout=0 forces immediate expiry. CLI users cannot reach this
//     state (main.go rejects <1).
//
// Context layering:
//
//	rootCtx (main.go, SIGINT-cancellable)
//	  └─ ctx (CollectState's parent)
//	       └─ fetchCtx (this function's WithTimeout, TOTAL budget)
//	            └─ attemptCtx (inside fetchWithRetry, per-attempt)
func fetchWithBudget(ctx context.Context, perAttempt time.Duration, refCount int, fn func(fetchCtx context.Context) error) (FetchKind, error) {
	if refCount < 1 {
		refCount = 1
	}
	totalBudget := perAttempt * time.Duration(gitexec.FetchMaxAttempts) * time.Duration(refCount)
	fetchCtx, cancel := context.WithTimeout(ctx, totalBudget)
	defer cancel()
	err := fn(fetchCtx)
	if err == nil {
		return FetchKindOK, nil
	}
	kind, _, _ := classifyFetchError(ctx, fetchCtx, err)
	return kind, err
}

// applyFetchFailure sets the failure-related fields on state from a
// (FetchKind, error) pair. Centralizes the mapping from FetchKind back to
// the legacy FetchTimeout / RemoteGone / FetchCancelled bools that
// decide.go reads. FetchLastError is populated for Timeout and
// TransientGaveUp — both benefit from the underlying error context in the
// formatter's remediation hint. Cancelled fetches have no useful error
// (it's ctx.Canceled), so we skip FetchLastError there.
func applyFetchFailure(s *RepoState, kind FetchKind, err error) {
	s.FetchKind = kind
	switch kind {
	case FetchKindCancelled:
		s.FetchCancelled = true
	case FetchKindTimeout:
		s.FetchTimeout = true
		s.FetchLastError = truncateError(err.Error(), 200)
	case FetchKindRepoGone:
		s.RemoteGone = true
	case FetchKindTransientGaveUp:
		s.FetchErr = err
		s.FetchLastError = truncateError(err.Error(), 200)
	default:
		// FetchKindOK should not reach here; defensive fall-through preserves err
		s.FetchErr = err
	}
}

// classifyFetchError maps a fetch error + the two relevant contexts to a
// FetchKind plus the legacy FetchTimeout / RemoteGone bools. The bools are
// retained so decide.go's existing branching is untouched.
//
// CRITICAL: Cancellation MUST be checked before timeout. SIGINT from main.go
// propagates via rootCtx → ctx → fetchCtx as context.Canceled. Misclassifying
// SIGINT as Timeout would spam the user with "fetch timed out" messages on
// Ctrl-C of a large multi-repo sync.
func classifyFetchError(parentCtx, fetchCtx context.Context, err error) (kind FetchKind, isTimeout bool, isGone bool) {
	// 1. SIGINT (Canceled) wins. Check parent first because cancellation
	//    propagates parent → child; once parent is Canceled, fetchCtx is
	//    also Canceled but the root cause is the parent.
	if errors.Is(parentCtx.Err(), context.Canceled) {
		return FetchKindCancelled, false, false
	}
	if errors.Is(fetchCtx.Err(), context.Canceled) {
		return FetchKindCancelled, false, false
	}
	// 2. Total-budget exhaustion (parent's WithTimeout fired).
	if errors.Is(parentCtx.Err(), context.DeadlineExceeded) {
		return FetchKindTimeout, true, false
	}
	// 3. Per-attempt / fetch budget elapsed without parent expiry.
	if errors.Is(fetchCtx.Err(), context.DeadlineExceeded) {
		return FetchKindTimeout, true, false
	}
	// 4. Remote-side permanent failure (repo not found / deleted).
	if isRemoteGoneError(err) {
		return FetchKindRepoGone, false, true
	}
	// 5. Default: transient retries exhausted, parent budget intact.
	return FetchKindTransientGaveUp, false, false
}

// truncateError flattens s to a single line (replacing \r\n / \n with " | "),
// then truncates to at most maxBytes UTF-8 bytes, backing up to the nearest
// rune boundary so we never emit invalid UTF-8. Appends "…" (U+2026, 3 bytes)
// when truncation occurred.
//
// Single-line flattening keeps the formatter's one-line-per-repo contract intact
// even when git stderr contains multi-line cascade ("error: ... \n fatal: ...").
func truncateError(s string, maxBytes int) string {
	s = strings.ReplaceAll(s, "\r\n", " | ")
	s = strings.ReplaceAll(s, "\n", " | ")
	if len(s) <= maxBytes {
		return s
	}
	cut := maxBytes
	for cut > 0 && !utf8.RuneStart(s[cut]) {
		cut--
	}
	return s[:cut] + "…"
}

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
	state.HasRebaseHead = gitexec.HasRebaseHead(ctx, repoPath)
	state.HasMergeHead = gitexec.HasMergeHead(ctx, repoPath)

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
		// Multi-ref budget scales by len(parentCandidates): each candidate
		// gets a fair retry budget, so a flaky first ref cannot drain refs 2..N.
		perAttempt := time.Duration(flags.FetchTimeout) * time.Second
		kind, ferr := fetchWithBudget(ctx, perAttempt, len(parentCandidates), func(fetchCtx context.Context) error {
			return gitexec.FetchMultiRef(fetchCtx, perAttempt, repoPath, parentCandidates)
		})
		if ferr != nil {
			applyFetchFailure(&state, kind, ferr)
			return state
		}
		state.FetchKind = FetchKindOK

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
		// 13. Default branch repos: targeted fetch
		parent := state.DefaultBranch
		if parent == "" {
			parent = "main"
		}
		state.ParentBranch = parent

		perAttempt := time.Duration(flags.FetchTimeout) * time.Second
		kind, ferr := fetchWithBudget(ctx, perAttempt, 1, func(fetchCtx context.Context) error {
			return gitexec.FetchSingleRef(fetchCtx, perAttempt, repoPath, parent)
		})
		if ferr != nil {
			applyFetchFailure(&state, kind, ferr)
			return state
		}
		state.FetchKind = FetchKindOK
	}

	// 14-16. Position SHAs (all require fetch to have completed)
	state.LocalSHA = gitexec.RevParse(ctx, repoPath, "HEAD")
	state.RemoteSHA = gitexec.RevParse(ctx, repoPath, "origin/"+state.ParentBranch)
	state.BaseSHA = gitexec.MergeBase(ctx, repoPath, "origin/"+state.ParentBranch)

	return state
}

// isRemoteGoneError returns true when a fetch error indicates the remote
// repository has been deleted, archived, or is otherwise permanently gone —
// as opposed to a transient network failure.
//
// Patterns covered:
//   - Azure DevOps TF401019: "does not exist or you do not have permissions"
//   - GitHub:                "ERROR: Repository not found"
//   - Generic git:           "fatal: repository '...' not found"
func isRemoteGoneError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	return strings.Contains(msg, "does not exist") ||
		strings.Contains(msg, "repository not found")
}
