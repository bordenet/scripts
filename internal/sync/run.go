package sync

import (
	"context"
	"os"
	"path/filepath"
	"time"

	"gitsync/internal/gitexec"
)

// Run processes a single repo: collect state → decide → execute.
//
// Pass a RepoSyncer to customise the underlying git operations. Use DefaultSyncer{}
// for the standard behaviour.
func Run(ctx context.Context, repoPath string, flags Flags, registry *StashRegistry, syncer RepoSyncer) RepoResult {
	start := time.Now()

	// Skip-recent gate: if FETCH_HEAD was written within flags.SkipRecent seconds,
	// a fetch happened recently and re-fetching is presumed wasteful. Lets callers
	// invoke gitsync repeatedly in a session (e.g. a dev-refresh script run right
	// after a manual sync) without re-paying full network cost for every repo.
	//
	// FETCH_HEAD is a WEAK signal on its own: git touches it on ANY fetch, not
	// just one gitsync performed — an IDE's background auto-fetch, another
	// terminal, or a manual `git fetch` all reset its mtime without updating the
	// local branch. Trusting FETCH_HEAD alone can skip a repo that is provably
	// behind its own already-cached origin/<branch> ref, silently masking a real
	// available update indefinitely (observed: a repo parked clean on main sat
	// stale across many daily runs because something else kept FETCH_HEAD fresh).
	//
	// isLikelyInSync() closes that gap with a second, local-only (no network)
	// check: local HEAD must equal the CACHED origin/<branch> ref before the
	// skip is honored. That cached ref already reflects whatever the last fetch
	// (by anyone) actually saw, so this check is free of the same blind spot.
	// Fail-open in both layers: any stat/parse error, or any ambiguity in the
	// local-only check, falls through to the normal path.
	if flags.SkipRecent > 0 {
		if fi, err := os.Stat(filepath.Join(repoPath, ".git", "FETCH_HEAD")); err == nil {
			if age := time.Since(fi.ModTime()); age < time.Duration(flags.SkipRecent)*time.Second {
				if isLikelyInSync(ctx, repoPath) {
					return RepoResult{
						RepoPath:   repoPath,
						Status:     StatusSkipped,
						SkipReason: SkipRecentFetch,
						SkipDetail: age.Round(time.Second).String() + " ago",
						ElapsedMs:  time.Since(start).Milliseconds(),
					}
				}
				// FETCH_HEAD is fresh but local HEAD does not match the cached
				// remote-tracking ref -- someone else's fetch, not confirmation
				// of sync. Fall through to the real fetch/decide/execute flow.
			}
		}
	}

	state := CollectState(ctx, repoPath, flags)

	// Auto-abort stale in-progress rebase or merge operations.
	// These are typically left behind by a previous interrupted gitsync run or
	// a suspended terminal session. Both rebase --abort and merge --abort restore
	// the repo to its pre-operation state with no data loss.
	//
	// Ghost-file fallback: if the abort command fails with "no rebase/merge in
	// progress" (stale REBASE_HEAD with no accompanying rebase-merge/ directory),
	// force-remove the residual state files — git already confirmed the working
	// tree is clean, so removal is safe.
	if state.HasRebaseHead {
		if err := syncer.RebaseAbort(state); err != nil {
			// Abort failed — likely a ghost REBASE_HEAD. Force-clean the stale files.
			_ = gitexec.ForceCleanRebaseState(repoPath)
		}
		state = CollectState(ctx, repoPath, flags)
	} else if state.HasMergeHead {
		if err := gitexec.MergeAbort(repoPath); err != nil {
			// Abort failed — likely a ghost MERGE_HEAD. Force-clean the stale files.
			_ = gitexec.ForceCleanMergeState(repoPath)
		}
		state = CollectState(ctx, repoPath, flags)
	}

	action := Decide(state, flags)
	// Propagate WhatIf from flags into action
	if flags.WhatIf {
		action.WhatIf = true
	}
	result := Execute(ctx, state, action, flags, registry, syncer)
	result.ElapsedMs = time.Since(start).Milliseconds()
	return result
}

// isLikelyInSync performs a fast, local-only (no network) check that the repo
// is genuinely caught up with its cached remote-tracking ref, for use by the
// --skip-recent gate above. It is deliberately conservative and scoped to the
// default branch: feature/ambiguous branches always return false (fall
// through to the full fetch/decide/execute path) because their correct
// action depends on the parent-branch comparison Decide() performs after a
// real fetch (rebase-vs-ff, upstream tracking, etc.) -- not safe to shortcut
// here. Any error, missing ref, or ambiguity also resolves to false.
func isLikelyInSync(ctx context.Context, repoPath string) bool {
	current := gitexec.CurrentBranch(ctx, repoPath)
	if current == "" {
		return false // detached HEAD -- let the normal path classify it
	}
	defaultBranch := gitexec.DefaultBranch(ctx, repoPath)
	if defaultBranch == "" || current != defaultBranch {
		return false
	}
	if !gitexec.RemoteTrackingRefExists(ctx, repoPath, current) {
		return false
	}
	head := gitexec.RevParse(ctx, repoPath, "HEAD")
	remote := gitexec.RevParse(ctx, repoPath, "origin/"+current)
	return head != "" && remote != "" && head == remote
}
