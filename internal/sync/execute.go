package sync

import (
	"context"
	"fmt"
	"strings"
	"time"

	"gitsync/internal/gitexec"
)

// isUntrackedConflictError detects the specific git error from
// `git pull --ff-only` when an untracked working-tree file would be
// overwritten by the incoming merge. This is a common cross-machine-sync
// artifact (e.g., OneDrive-synced sibling clone leaves an untracked file
// that remote main has since added as tracked) — classifying it lets the
// formatter render a precise remediation hint instead of multi-line stderr.
func isUntrackedConflictError(err error) bool {
	if err == nil {
		return false
	}
	return strings.Contains(strings.ToLower(err.Error()),
		"untracked working tree files would be overwritten")
}

// shellQuotePath wraps a path in single quotes so it is safe to paste into
// a POSIX shell, even when the path contains spaces, `$`, backticks, `;`,
// `*`, or other metacharacters. Single-quote literals are escaped via the
// standard `'\''` close-reopen sequence.
//
// Repos discovered by the walk should never contain such characters in
// practice — but rendering paths into copy/pasteable command suggestions
// without escaping is a footgun. The formatter consumes ManualSteps verbatim,
// so the escape MUST happen at the producer side here in execute.go.
func shellQuotePath(p string) string {
	return "'" + strings.ReplaceAll(p, "'", `'\''`) + "'"
}

// Execute carries out the Action for a repo. It manages stash lifecycle explicitly
// (NOT via defer — stash pop is suppressed when rebase fails to avoid popping on
// a half-rebased repo).
func Execute(ctx context.Context, state RepoState, action Action, flags Flags, registry *StashRegistry, syncer RepoSyncer) RepoResult {
	base := RepoResult{
		RepoPath:       state.RepoPath,
		CurrentBranch:  state.CurrentBranch,
		ParentBranch:   state.ParentBranch,
		BranchType:     state.BranchType,
		FetchKind:      state.FetchKind,
		FetchLastError: state.FetchLastError,
	}

	// --what-if: return description, no writes.
	// Status reflects what WOULD have happened so the summary buckets are useful:
	//   ActionNoOp        → StatusNoOp   (WhatIfAction set; formatter routes via WhatIfAction != "")
	//   ActionFastForward → StatusUpdated (WhatIfAction set; SkipWhatIf kept for backward compat)
	//   ActionRebase      → StatusRebased (WhatIfAction set; SkipWhatIf kept for backward compat)
	//   ActionSkip        → StatusSkipped with the REAL SkipReason (shows ⊘ + reason)
	//   ActionFail        → StatusFailed  with the real FailReason  (shows ✗ + reason)
	if action.WhatIf {
		r := RepoResult{
			RepoPath:      state.RepoPath,
			WhatIfAction:  describeAction(action, state),
			CurrentBranch: state.CurrentBranch,
			ParentBranch:  state.ParentBranch,
		}
		switch action.Type {
		case ActionNoOp:
			r.Status = StatusNoOp
			r.SkipReason = SkipWhatIf
		case ActionFastForward:
			r.Status = StatusUpdated
			r.SkipReason = SkipWhatIf
		case ActionRebase:
			r.Status = StatusRebased
			r.SkipReason = SkipWhatIf
			r.ForceRebase = action.ForceRebase
		case ActionResetHard:
			r.Status = StatusReset
			r.SkipReason = SkipWhatIf
		case ActionSkip:
			r.Status = StatusSkipped
			r.SkipReason = action.SkipReason // real reason — formatter shows ⊘
			// Surface remediation steps in the dry-run preview too, so --what-if
			// matches the real run rather than silently dropping them.
			if action.SkipReason == SkipDefaultRenamed {
				r.ManualSteps = renameManualSteps(state)
			}
		case ActionFail:
			r.Status = StatusFailed
			r.FailReason = action.FailReason
		default:
			r.Status = StatusSkipped
			r.SkipReason = SkipWhatIf
		}
		return r
	}

	switch action.Type {
	case ActionNoOp:
		return withStatus(base, StatusNoOp)
	case ActionResetHard:
		if err := syncer.ResetHard(ctx, state, flags); err != nil {
			r := withStatus(base, StatusFailed)
			r.FailReason = truncateError("reset --hard failed: "+err.Error(), 300)
			return r
		}
		return withStatus(base, StatusReset)
	case ActionSkip:
		r := withStatus(base, StatusSkipped)
		r.SkipReason = action.SkipReason
		if action.SkipReason == SkipDefaultRenamed {
			r.ManualSteps = renameManualSteps(state)
		}
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
			r.FailReason = truncateError("stash push failed: "+err.Error(), 300)
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
		if err := syncer.FastForward(ctx, state, flags); err != nil {
			popStash() // safe: no rebase in flight
			// Untracked-file collision is a common cross-machine-sync artifact
			// (OneDrive / sibling-clone workflows). Surface it as a skip with
			// a concrete remediation path, not as a wall of multi-line stderr.
			if isUntrackedConflictError(err) {
				r := withStatus(base, StatusSkipped)
				r.SkipReason = SkipUntrackedConflict
				r.ManualSteps = []string{
					"cd " + shellQuotePath(state.RepoPath),
					"git status                          # find the untracked file(s)",
					"git stash push --include-untracked  # or move/delete them",
					"gitsync " + shellQuotePath(state.RepoPath) + "      # retry",
				}
				return r
			}
			r := withStatus(base, StatusFailed)
			r.FailReason = truncateError("pull --ff-only failed: "+err.Error(), 300)
			return r
		}
		if popStash() {
			r := withStatus(base, StatusStashConflict)
			r.ManualSteps = []string{"cd " + shellQuotePath(state.RepoPath), "git stash pop  # resolve conflicts manually"}
			return r
		}
		return withStatus(base, StatusUpdated)

	case ActionRebase:
		if err := syncer.Rebase(ctx, state, flags); err != nil {
			// Rebase failed — attempt abort. Use Background ctx (parent ctx may be cancelled).
			abortErr := syncer.RebaseAbort(state)
			if abortErr != nil {
				// Both rebase and abort failed — repo may be corrupt
				// Do NOT pop stash (repo state unknown)
				r := withStatus(base, StatusManualInterventionRequired)
				r.FailReason = "rebase and abort both failed"
				r.ManualSteps = []string{
					"cd " + shellQuotePath(state.RepoPath),
					"git rebase --abort  # or: git reset --hard HEAD",
					"git stash list     # check for orphaned stash",
				}
				return r
			}
			// Abort succeeded — safe to pop stash.
			// If stash pop also conflicts, surface that to the user.
			if popStash() {
				r := withStatus(base, StatusStashConflict)
				r.ManualSteps = []string{"cd " + shellQuotePath(state.RepoPath), "git stash pop  # rebase rolled back; stash pop also conflicted"}
				return r
			}
			r := withStatus(base, StatusRebaseConflict)
			r.FailReason = "rebase conflict, rolled back"
			return r
		}
		// Rebase succeeded — pop stash
		if popStash() {
			r := withStatus(base, StatusStashConflict)
			r.ManualSteps = []string{"cd " + shellQuotePath(state.RepoPath), "git stash pop  # resolve conflicts manually"}
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

// renameManualSteps builds the copy-pasteable remediation for a remote
// default-branch rename (master→main): rename the local branch, re-point its
// upstream, fast-forward, and refresh the local origin/HEAD. Derived entirely
// from the Renamed* fields CollectState recorded.
func renameManualSteps(state RepoState) []string {
	from, to := state.RenamedDefaultFrom, state.RenamedDefaultTo
	return []string{
		"cd " + shellQuotePath(state.RepoPath),
		"git fetch origin --prune",
		fmt.Sprintf("git branch -m %s %s", from, to),
		fmt.Sprintf("git branch -u origin/%s %s", to, to),
		fmt.Sprintf("git merge --ff-only origin/%s", to),
		"git remote set-head origin -a",
	}
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
	case ActionResetHard:
		return fmt.Sprintf("would reset --hard %s to origin/%s (unrelated history)", state.CurrentBranch, state.ParentBranch)
	case ActionSkip:
		return fmt.Sprintf("would skip: %s", action.SkipReason)
	case ActionFail:
		return fmt.Sprintf("would fail: %s", action.FailReason)
	}
	return "unknown"
}
