package sync

import (
	"context"
	"time"

	"gitsync/internal/gitexec"
)

// Run processes a single repo: collect state → decide → execute.
func Run(ctx context.Context, repoPath string, flags Flags, registry *StashRegistry) RepoResult {
	start := time.Now()
	state := CollectState(ctx, repoPath, flags)

	// Auto-abort stale in-progress rebase or merge operations.
	// These are typically left behind by a previous interrupted gitsync run or
	// a suspended terminal session. Both rebase --abort and merge --abort restore
	// the repo to its pre-operation state with no data loss.
	// After aborting, re-collect state and proceed with a fresh sync attempt.
	if state.HasRebaseHead {
		_ = gitexec.RebaseAbort(repoPath) // best-effort; re-collect reflects actual state
		state = CollectState(ctx, repoPath, flags)
	} else if state.HasMergeHead {
		_ = gitexec.MergeAbort(repoPath)
		state = CollectState(ctx, repoPath, flags)
	}

	action := Decide(state, flags)
	// Propagate WhatIf from flags into action
	if flags.WhatIf {
		action.WhatIf = true
	}
	result := Execute(ctx, state, action, flags, registry)
	result.ElapsedMs = time.Since(start).Milliseconds()
	return result
}
