package sync

import (
	"context"
	"time"

	"gitsync/internal/gitexec"
)

// Run processes a single repo: collect state → decide → execute.
func Run(ctx context.Context, repoPath string, flags Flags, registry *StashRegistry, syncer RepoSyncer) RepoResult {
	start := time.Now()
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
