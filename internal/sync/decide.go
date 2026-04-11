package sync

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

	// Guard: early exits (order is load-bearing — do not reorder)
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
	if state.FetchCancelled {
		return skip(SkipCancelled)
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

	// Fast-forward available (local == base means remote is strictly ahead)
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
	// Never auto-rebase the default branch — user has unpushed commits; manual intervention needed
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
	// IsPushed is only meaningful for Feature branches (Default/Ambiguous are handled above)
	if state.IsPushed && !flags.ForceRebase {
		return skip(SkipPushedNeedForce)
	}

	return rebase(state.IsPushed && flags.ForceRebase)
}
