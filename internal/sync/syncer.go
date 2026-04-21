package sync

import (
	"context"
	"time"

	"gitsync/internal/gitexec"
)

// RepoSyncer is the single extension point for adopters who need custom git
// operations. Implement this interface and pass it to Run (or Execute directly)
// to replace any or all of the three sync operations.
//
// The context passed to each method is the root (cancellable) context — not a
// pre-timed-out one. Implementations are responsible for wrapping it with their
// own timeouts if needed. DefaultSyncer derives its timeouts from Flags.
//
// Example — submodule-aware fork (import this package as "gosync" to avoid
// shadowing the stdlib "sync" package):
//
//	import gosync "gitsync/internal/sync"
//
//	type SubmoduleSyncer struct{ gosync.DefaultSyncer }
//
//	func (s SubmoduleSyncer) FastForward(ctx context.Context, state gosync.RepoState, flags gosync.Flags) error {
//	    if err := s.DefaultSyncer.FastForward(ctx, state, flags); err != nil {
//	        return err
//	    }
//	    // Also pull submodules after the fast-forward succeeds.
//	    _, err := exec.CommandContext(ctx, "git", "-C", state.RepoPath,
//	        "submodule", "update", "--init", "--recursive").CombinedOutput()
//	    return err
//	}
type RepoSyncer interface {
	// FastForward brings the local branch up to date with origin when the
	// local branch is strictly behind (default: git pull --ff-only origin <parent>).
	FastForward(ctx context.Context, state RepoState, flags Flags) error

	// Rebase replays local commits on top of origin/<parent>
	// (default: git rebase origin/<parent>).
	// Called only for feature branches; never for the default branch.
	Rebase(ctx context.Context, state RepoState, flags Flags) error

	// RebaseAbort aborts an in-progress rebase to roll back after a conflict.
	// Implementations must use context.Background() internally — the repo's
	// deadline context may already be cancelled by the time this is called.
	RebaseAbort(state RepoState) error

	// ResetHard resets the local branch to origin/<parent>, discarding all
	// local history (used only for default branches with unrelated history).
	ResetHard(ctx context.Context, state RepoState, flags Flags) error
}

// DefaultSyncer is the out-of-the-box implementation of RepoSyncer.
// It reproduces the original gitsync behaviour exactly.
// Zero-value is ready to use: var s DefaultSyncer
type DefaultSyncer struct{}

// FastForward runs git pull --ff-only origin <parent>, with a timeout derived
// from flags.FetchTimeout.
func (DefaultSyncer) FastForward(ctx context.Context, state RepoState, flags Flags) error {
	ffCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
	defer cancel()
	return gitexec.PullFFOnly(ffCtx, state.RepoPath, state.ParentBranch)
}

// Rebase runs git rebase origin/<parent>, with a timeout derived from
// flags.RebaseTimeout.
func (DefaultSyncer) Rebase(ctx context.Context, state RepoState, flags Flags) error {
	rebaseCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.RebaseTimeout)*time.Second)
	defer cancel()
	return gitexec.Rebase(rebaseCtx, state.RepoPath, "origin/"+state.ParentBranch)
}

// RebaseAbort runs git rebase --abort using context.Background() so that a
// cancelled parent context does not prevent cleanup.
func (DefaultSyncer) RebaseAbort(state RepoState) error {
	return gitexec.RebaseAbort(state.RepoPath)
}

// ResetHard runs git reset --hard origin/<parent>. Uses flags.FetchTimeout as
// the timeout; the reset is a local disk operation so this limit is never
// binding in practice.
func (DefaultSyncer) ResetHard(ctx context.Context, state RepoState, flags Flags) error {
	resetCtx, cancel := context.WithTimeout(ctx, time.Duration(flags.FetchTimeout)*time.Second)
	defer cancel()
	return gitexec.ResetHard(resetCtx, state.RepoPath, "origin/"+state.ParentBranch)
}
