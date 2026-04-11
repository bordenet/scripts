package sync

import (
	"context"

	"gitsync/internal/gitexec"
)

// TopStashMessage returns the message of the top stash entry in the repo.
func TopStashMessage(ctx context.Context, repoPath string) string {
	return gitexec.TopStashMessage(ctx, repoPath)
}

// PopStash pops the top stash entry in the repo.
func PopStash(ctx context.Context, repoPath string) error {
	return gitexec.StashPop(ctx, repoPath)
}
