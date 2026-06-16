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
	switch state.FetchKind {
	case FetchKindOK:
		// happy path — fall through to position-SHA checks below
	case FetchKindTimeout:
		return skip(SkipFetchTimeout)
	case FetchKindCancelled:
		return skip(SkipCancelled)
	case FetchKindRepoGone:
		return skip(SkipRemoteGone)
	case FetchKindTransientGaveUp:
		if state.FetchErr != nil {
			return fail(state.FetchErr.Error())
		}
		// Defensive: TransientGaveUp without FetchErr is a caller bug (Run
		// applied the kind without setting err). Fall through rather than
		// panic — the absence of err makes the success path benign.
	default:
		// Unhandled FetchKind enum value. Panic on the spot so a future
		// kind added to types.go MUST add a case here — silent fall-through
		// to the success path would treat an unfetched repo as up-to-date.
		panic("unhandled FetchKind in Decide: " + state.FetchKind.String())
	}
	// Remote renamed its default branch (e.g. master→main) and the local branch
	// still carries the old name. CollectState set the Renamed* fields after a
	// network refresh of origin/HEAD. Auto-renaming a user's branch is unsafe for
	// a sync tool, so require manual intervention; Execute attaches the exact
	// remediation commands derived from the Renamed* fields.
	if state.RenamedDefaultTo != "" {
		return skip(SkipDefaultRenamed)
	}
	if state.BranchType == BranchTypeAmbiguous {
		return skip(SkipAmbiguousBranch)
	}
	if state.RemoteSHA == "" {
		return skip(SkipNoRemoteTracking)
	}
	if state.BaseSHA == "" {
		// Default branch with unrelated history: reset hard to origin is safe and expected.
		// Feature branches: skip — unrelated history on a feature branch is unusual enough
		// to warrant manual inspection.
		if state.BranchType == BranchTypeDefault {
			if state.HasLocalChanges {
				return skip(SkipNoCommonAncestor)
			}
			return Action{Type: ActionResetHard}
		}
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
