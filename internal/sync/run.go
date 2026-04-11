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
