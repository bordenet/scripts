package sync

import (
	"context"
	"fmt"
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
	// Uses context.Background() so cancellation doesn't prevent stash cleanup.
	// registry.Remove is called AFTER a successful pop so the interrupt handler
	// can retry on SIGINT if pop fails.
	// Idempotent: stashed is set to false on first call; subsequent calls return false immediately.
	popStash := func() bool {
		if !stashed {
			return false
		}
		stashed = false
		if err := gitexec.StashPop(context.Background(), state.RepoPath); err != nil {
			return true // conflict — stash still in place, registry entry preserved
		}
		registry.Remove(state.RepoPath)
		return false
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
			// Abort succeeded — safe to pop stash.
			// If stash pop also conflicts, surface that to the user.
			if popStash() {
				r := withStatus(base, StatusStashConflict)
				r.ManualSteps = []string{"cd " + state.RepoPath, "git stash pop  # rebase rolled back; stash pop also conflicted"}
				return r
			}
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
