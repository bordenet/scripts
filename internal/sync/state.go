package sync

import (
	"context"
	"errors"
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
		fetchCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
		defer cancel()
		err := gitexec.FetchMultiRef(fetchCtx, repoPath, parentCandidates)
		if err != nil {
			if errors.Is(fetchCtx.Err(), context.DeadlineExceeded) {
				state.FetchTimeout = true
			} else if ctx.Err() != nil {
				// Parent context cancelled (SIGINT) — not a network timeout
				state.FetchCancelled = true
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
		// 13. Default branch repos: targeted fetch
		parent := state.DefaultBranch
		if parent == "" {
			parent = "main"
		}
		state.ParentBranch = parent

		fetchCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
		defer cancel()
		if err := gitexec.FetchSingleRef(fetchCtx, repoPath, parent); err != nil {
			if errors.Is(fetchCtx.Err(), context.DeadlineExceeded) {
				state.FetchTimeout = true
			} else if ctx.Err() != nil {
				// Parent context cancelled (SIGINT) — not a network timeout
				state.FetchCancelled = true
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
