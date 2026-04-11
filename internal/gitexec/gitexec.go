package gitexec

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// run executes a git command in dir with the given args.
// Returns stdout as string (trimmed), or error.
func run(ctx context.Context, dir string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.Dir = dir
	cmd.Env = append(os.Environ(),
		"GIT_TERMINAL_PROMPT=0",
		// Use $HOME (shell-expanded at runtime) rather than os.Getenv("HOME")
		// so spaces in the home path don't break SSH option parsing.
		"GIT_SSH_COMMAND=ssh -oBatchMode=yes -oControlMaster=auto -oControlPath=$HOME/.ssh/cm-%r@%h:%p -oControlPersist=60s",
	)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		// If context was cancelled or timed out, return the context error directly
		// so callers can use errors.Is(err, context.DeadlineExceeded) or
		// errors.Is(err, context.Canceled) to distinguish the cases.
		if ctx.Err() != nil {
			return "", ctx.Err()
		}
		return "", fmt.Errorf("git %s: %w (stderr: %s)", strings.Join(args, " "), err, stderr.String())
	}
	return strings.TrimSpace(stdout.String()), nil
}

// HasHead returns true if the repo has at least one commit.
func HasHead(ctx context.Context, dir string) bool {
	_, err := run(ctx, dir, "rev-parse", "HEAD")
	return err == nil
}

// HasOrigin returns true if origin remote is configured.
func HasOrigin(ctx context.Context, dir string) bool {
	_, err := run(ctx, dir, "remote", "get-url", "origin")
	return err == nil
}

// CurrentBranch returns the current branch name, or "" if detached HEAD.
func CurrentBranch(ctx context.Context, dir string) string {
	out, err := run(ctx, dir, "symbolic-ref", "--short", "HEAD")
	if err != nil {
		return ""
	}
	return out
}

// DefaultBranch detects the default branch using local refs only (no network).
// Tries: symbolic-ref refs/remotes/origin/HEAD, then probes origin/main, origin/master.
func DefaultBranch(ctx context.Context, dir string) string {
	out, err := run(ctx, dir, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
	if err == nil && out != "" {
		// Returns "origin/main" — strip prefix
		parts := strings.SplitN(out, "/", 2)
		if len(parts) == 2 {
			return parts[1]
		}
	}
	// Fallback: probe common names
	for _, candidate := range []string{"main", "master"} {
		_, err := run(ctx, dir, "show-ref", "--verify", "refs/remotes/origin/"+candidate)
		if err == nil {
			return candidate
		}
	}
	return ""
}

// HasUnmerged returns true if there are unmerged files (conflict in progress).
func HasUnmerged(ctx context.Context, dir string) bool {
	out, err := run(ctx, dir, "ls-files", "--unmerged")
	return err == nil && out != ""
}

// HasRebaseHead returns true if .git/REBASE_HEAD exists.
func HasRebaseHead(ctx context.Context, dir string) bool {
	gd, err := gitDir(ctx, dir)
	if err != nil {
		return false
	}
	_, err = os.Stat(filepath.Join(gd, "REBASE_HEAD"))
	return err == nil
}

// HasMergeHead returns true if .git/MERGE_HEAD exists.
func HasMergeHead(ctx context.Context, dir string) bool {
	gd, err := gitDir(ctx, dir)
	if err != nil {
		return false
	}
	_, err = os.Stat(filepath.Join(gd, "MERGE_HEAD"))
	return err == nil
}

// IsShallow returns true if the repo is a shallow clone.
func IsShallow(ctx context.Context, dir string) bool {
	out, _ := run(ctx, dir, "rev-parse", "--is-shallow-repository")
	return out == "true"
}

// HasSubmodules returns true if .gitmodules exists in the repo root.
func HasSubmodules(dir string) bool {
	_, err := os.Stat(filepath.Join(dir, ".gitmodules"))
	return err == nil
}

// HasLocalChanges returns true if working tree or index is dirty.
func HasLocalChanges(ctx context.Context, dir string) bool {
	_, err1 := run(ctx, dir, "diff", "--quiet")
	_, err2 := run(ctx, dir, "diff", "--cached", "--quiet")
	return err1 != nil || err2 != nil
}

// RemoteTrackingRefExists returns true if refs/remotes/origin/<branch> exists locally.
func RemoteTrackingRefExists(ctx context.Context, dir, branch string) bool {
	_, err := run(ctx, dir, "show-ref", "--verify", "refs/remotes/origin/"+branch)
	return err == nil
}

// FetchMultiRef fetches multiple refs from origin, ignoring refs that don't exist.
// Returns error only if ALL refs fail to fetch (network unavailable).
func FetchMultiRef(ctx context.Context, dir string, refs []string) error {
	// Fetch each candidate individually so a missing ref on the remote doesn't
	// prevent other candidates from being updated.
	anySucceeded := false
	var lastErr error
	for _, ref := range refs {
		if ctx.Err() != nil {
			break
		}
		_, err := run(ctx, dir, "fetch", "origin", ref)
		if err == nil {
			anySucceeded = true
		} else {
			lastErr = err
		}
	}
	if anySucceeded {
		return nil
	}
	if lastErr != nil {
		return fmt.Errorf("all parent candidate refs unavailable: %w", lastErr)
	}
	return fmt.Errorf("no parent candidate refs available")
}

// FetchSingleRef fetches a single ref from origin.
func FetchSingleRef(ctx context.Context, dir, ref string) error {
	_, err := run(ctx, dir, "fetch", "origin", ref)
	return err
}

// RevParse returns the SHA for a git ref. Returns "" if not found.
func RevParse(ctx context.Context, dir, ref string) string {
	out, err := run(ctx, dir, "rev-parse", ref)
	if err != nil {
		return ""
	}
	return out
}

// MergeBase returns the common ancestor SHA of HEAD and a remote ref. Returns "" if none.
func MergeBase(ctx context.Context, dir, remoteRef string) string {
	out, err := run(ctx, dir, "merge-base", "HEAD", remoteRef)
	if err != nil {
		return ""
	}
	return out
}

// CommitsBehind returns how many commits HEAD is behind a remote ref.
// Returns -1 if the command fails.
func CommitsBehind(ctx context.Context, dir, remoteRef string) int {
	out, err := run(ctx, dir, "rev-list", "--count", "HEAD.."+remoteRef)
	if err != nil {
		return -1
	}
	n := 0
	fmt.Sscanf(out, "%d", &n)
	return n
}

// PullFFOnly runs git pull --ff-only for the given branch.
func PullFFOnly(ctx context.Context, dir, branch string) error {
	_, err := run(ctx, dir, "pull", "--ff-only", "origin", branch)
	return err
}

// Rebase runs git rebase against a remote ref.
func Rebase(ctx context.Context, dir, remoteRef string) error {
	_, err := run(ctx, dir, "rebase", remoteRef)
	return err
}

// RebaseAbort aborts an in-progress rebase. Uses context.Background() — must not
// be cancelled by the repo's deadline context.
func RebaseAbort(dir string) error {
	_, err := run(context.Background(), dir, "rebase", "--abort")
	return err
}

// StashPush creates an auto-stash with the given message.
func StashPush(ctx context.Context, dir, message string) error {
	_, err := run(ctx, dir, "stash", "push", "-m", message)
	return err
}

// StashPop pops the top stash entry.
func StashPop(ctx context.Context, dir string) error {
	_, err := run(ctx, dir, "stash", "pop")
	return err
}

// TopStashMessage returns the message of the top stash entry, or "" if none.
func TopStashMessage(ctx context.Context, dir string) string {
	out, err := run(ctx, dir, "stash", "list", "--max-count=1", "--pretty=%s")
	if err != nil {
		return ""
	}
	// Format is "stash@{0}: On <branch>: <message>" — extract after last ": "
	if idx := strings.LastIndex(out, ": "); idx >= 0 {
		return strings.TrimSpace(out[idx+2:])
	}
	return out
}

// gitDir returns the .git directory path for a repo (handles worktrees where .git is a file).
// ctx is used for the git subprocess in the worktree/submodule case so it can be cancelled.
func gitDir(ctx context.Context, dir string) (string, error) {
	// Fast path: .git as directory (no subprocess needed)
	gitPath := filepath.Join(dir, ".git")
	if info, err := os.Stat(gitPath); err == nil && info.IsDir() {
		return gitPath, nil
	}
	// Worktree/submodule: .git is a file pointing to real git dir
	cmd := exec.CommandContext(ctx, "git", "rev-parse", "--git-dir")
	cmd.Dir = dir
	out, err := cmd.Output()
	if err != nil {
		return "", err
	}
	gd := strings.TrimSpace(string(out))
	if !filepath.IsAbs(gd) {
		gd = filepath.Join(dir, gd)
	}
	return gd, nil
}
