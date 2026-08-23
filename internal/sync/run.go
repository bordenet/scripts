package sync

import (
	"context"
	"os"
	"path/filepath"
	"time"

	"gitsync/internal/gitexec"
)

// Run processes a single repo: collect state → decide → execute.
func Run(ctx context.Context, repoPath string, flags Flags, registry *StashRegistry, syncer RepoSyncer) RepoResult {
	start := time.Now()

	// Skip-recent gate: if FETCH_HEAD was written within flags.SkipRecent seconds,
	// the remote is presumed unchanged and all work is skipped. This lets callers
	// run gitsync multiple times in a session without paying full network cost.
	// Fail-open: any stat/parse error falls through to the normal path.
	if flags.SkipRecent > 0 {
		if fi, err := os.Stat(filepath.Join(repoPath, ".git", "FETCH_HEAD")); err == nil {
			if time.Since(fi.ModTime()) < time.Duration(flags.SkipRecent)*time.Second {
				return RepoResult{
					RepoPath:  repoPath,
					Status:    StatusSkipped,
					SkipReason: SkipRecentFetch,
					ElapsedMs: time.Since(start).Milliseconds(),
				}
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
