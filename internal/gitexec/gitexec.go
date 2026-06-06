package gitexec

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// run executes a git command in dir with the given args.
// Returns stdout as string (trimmed), or error.
func run(ctx context.Context, dir string, args ...string) (string, error) {
	cmd := exec.CommandContext(ctx, "git", args...)
	cmd.WaitDelay = 5 * time.Second // force-close pipes if child procs outlive the cancelled context
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

// isTransientFetchError returns true for network errors that warrant a retry
// (dropped connections, partial transfers) as opposed to permanent failures
// (repo not found, auth denied, HTTP 4xx).
//
// Patterns are matched against the full lowercased error string returned by run(),
// which includes git's stderr. "rpc failed" alone is intentionally excluded — it
// matches HTTP 401/403 auth failures; specific sub-patterns (curl exit codes,
// pack-layer disconnects) are used instead.
func isTransientFetchError(err error) bool {
	if err == nil {
		return false
	}
	msg := strings.ToLower(err.Error())
	// Trailing-space discipline on curl exit codes ("curl 18 ", "curl 28 ")
	// avoids false positives on "curl 186" / "curl 280" etc.
	// curl 28 fires when http.lowSpeedTime triggers OR when the operation
	// times out at the curl layer; "operation timed out" covers the same
	// class without the curl-code prefix on some git versions.
	// gnutls_handshake / SSL_read cover TLS-layer flakes (macOS gnutls,
	// Linux openssl) that present as transient connection drops.
	return strings.Contains(msg, "curl 18 ") ||
		strings.Contains(msg, "curl 28 ") ||
		strings.Contains(msg, "operation timed out") ||
		strings.Contains(msg, "early eof") ||
		strings.Contains(msg, "unexpected disconnect while reading sideband") ||
		strings.Contains(msg, "invalid index-pack output") ||
		strings.Contains(msg, "gnutls_handshake") ||
		strings.Contains(msg, "ssl_read")
}

// FetchMaxAttempts is the maximum number of fetch attempts per ref.
// Exported so callers (state.go) can derive the total retry budget.
const FetchMaxAttempts = 3

// fetchRetryDelays holds the backoff base duration before each retry attempt
// (i.e. before attempt 1, before attempt 2, …). Length must equal
// FetchMaxAttempts-1; TestFetchRetryDelaysInvariant enforces this at test time.
// To add a fourth attempt: increment FetchMaxAttempts AND add a third entry here.
var fetchRetryDelays = []time.Duration{1 * time.Second, 3 * time.Second}

// fetchWithRetry calls fetch up to FetchMaxAttempts times, retrying on transient
// network errors (curl 18, early EOF, sideband disconnect, invalid index-pack
// output, curl 28, gnutls/ssl handshake failures). Backoff uses fetchRetryDelays
// + up-to-50% jitter; both sleeps are ctx-cancellable via time.NewTimer so no
// goroutine outlives the call.
//
// Each attempt receives a child context with the perAttempt timeout derived
// from parentCtx; the loop also exits when parentCtx itself expires (caller's
// total budget exhausted). Per-attempt context.DeadlineExceeded (with parent
// still alive) is treated as a transient timeout-class failure and retried.
//
// The global math/rand source is auto-seeded (Go ≥1.20, enforced by go.mod) so
// jitter is uncorrelated across parallel goroutines without explicit seeding.
func fetchWithRetry(parentCtx context.Context, perAttempt time.Duration, fetch func(context.Context) error) error {
	var lastErr error
	for attempt := 0; attempt < FetchMaxAttempts; attempt++ {
		if parentCtx.Err() != nil {
			return parentCtx.Err()
		}
		if attempt > 0 {
			// idx is always in-bounds: TestFetchRetryDelaysInvariant guarantees
			// len(fetchRetryDelays) == FetchMaxAttempts-1, and attempt-1 ranges
			// from 0 to FetchMaxAttempts-2 inclusive.
			base := fetchRetryDelays[attempt-1]
			// Jitter up to 50% of base to spread retries across parallel goroutines.
			// Guard against base ≤ 1ns (test fixtures) where int64(base)/2 == 0.
			jitter := time.Duration(0)
			if half := int64(base) / 2; half > 0 {
				jitter = time.Duration(rand.Int63n(half))
			}
			t := time.NewTimer(base + jitter)
			select {
			case <-t.C:
			case <-parentCtx.Done():
				// Stop() returns false when the timer already fired and put a value
				// in t.C's one-element buffer. Drain it now so the buffer is empty;
				// t is about to go out of scope, but the buffered value would otherwise
				// sit until GC — draining is the standard Go timer hygiene pattern.
				if !t.Stop() {
					<-t.C
				}
				return parentCtx.Err()
			}
		}
		attemptCtx, cancel := context.WithTimeout(parentCtx, perAttempt)
		err := fetch(attemptCtx)
		cancel()
		if err == nil {
			return nil
		}
		// Per-attempt budget elapsed while parent still alive — retry as transient.
		if errors.Is(err, context.DeadlineExceeded) && parentCtx.Err() == nil {
			lastErr = fmt.Errorf("attempt %d: per-attempt timeout after %s", attempt+1, perAttempt)
			continue
		}
		if !isTransientFetchError(err) {
			return err
		}
		lastErr = err
	}
	return fmt.Errorf("fetch failed after %d attempts: %w", FetchMaxAttempts, lastErr)
}

// FetchMultiRef attempts to fetch every ref in turn, retrying transient errors
// per fetchWithRetry. All refs share the parentCtx total budget. Returns nil
// if at least one ref succeeds (including partial success where cancellation
// interrupts later refs). Returns parentCtx.Err() when the context is
// cancelled before any ref has successfully landed.
func FetchMultiRef(parentCtx context.Context, perAttempt time.Duration, dir string, refs []string) error {
	// Fetch each candidate individually so a missing ref on the remote doesn't
	// prevent other candidates from being updated.
	anySucceeded := false
	var errs []error
	for _, ref := range refs {
		if err := parentCtx.Err(); err != nil {
			// Context cancelled before we could attempt this ref.
			if anySucceeded {
				// Some refs landed — caller can proceed with what's available.
				return nil
			}
			return err
		}
		err := fetchWithRetry(parentCtx, perAttempt, func(ctx context.Context) error {
			_, err := runFetch(ctx, dir, ref)
			return err
		})
		if err == nil {
			anySucceeded = true
		} else {
			// Accumulate per-ref errors so the caller sees the full failure picture,
			// not just the last one. errors.Join preserves errors.Is traversal.
			errs = append(errs, fmt.Errorf("ref %s: %w", ref, err))
		}
	}
	if anySucceeded {
		return nil
	}
	// If the context was cancelled mid-loop (fetchWithRetry propagates ctx.Err()
	// directly), return that rather than a misleading domain error.
	if ctxErr := parentCtx.Err(); ctxErr != nil {
		return ctxErr
	}
	if len(errs) > 0 {
		return fmt.Errorf("all parent candidate refs unavailable: %w", errors.Join(errs...))
	}
	return fmt.Errorf("no parent candidate refs available")
}

// FetchSingleRef fetches a single ref from origin.
func FetchSingleRef(parentCtx context.Context, perAttempt time.Duration, dir, ref string) error {
	return fetchWithRetry(parentCtx, perAttempt, func(ctx context.Context) error {
		_, err := runFetch(ctx, dir, ref)
		return err
	})
}

// runFetch invokes `git -c http.version=HTTP/1.1 fetch origin <ref>`. The
// HTTP/1.1 downgrade applies only to this subprocess (no global git config
// mutation) and mitigates HTTP/2 multiplexing failures (curl 18 / sideband
// disconnect) on flaky links / large packs.
func runFetch(ctx context.Context, dir, ref string) (string, error) {
	return run(ctx, dir, "-c", "http.version=HTTP/1.1", "fetch", "origin", ref)
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

// ResetHard resets the current branch to ref, discarding all local changes.
func ResetHard(ctx context.Context, dir, ref string) error {
	_, err := run(ctx, dir, "reset", "--hard", ref)
	return err
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

// ForceCleanRebaseState removes stale rebase state files when git rebase --abort
// refuses to run (e.g. REBASE_HEAD exists but rebase-merge/ is missing).
// ONLY call this after RebaseAbort has already returned "no rebase in progress"
// — that confirms the working tree is clean and the files are safe to remove.
func ForceCleanRebaseState(dir string) error {
	gd, err := gitDir(context.Background(), dir)
	if err != nil {
		return err
	}
	for _, f := range []string{"REBASE_HEAD"} {
		os.Remove(filepath.Join(gd, f)) // best-effort; ignore missing
	}
	for _, d := range []string{"rebase-merge", "rebase-apply"} {
		os.RemoveAll(filepath.Join(gd, d)) // best-effort; ignore missing
	}
	return nil
}

// MergeAbort aborts an in-progress merge. Uses context.Background() — must not
// be cancelled by the repo's deadline context.
func MergeAbort(dir string) error {
	_, err := run(context.Background(), dir, "merge", "--abort")
	return err
}

// ForceCleanMergeState removes a stale MERGE_HEAD when git merge --abort
// refuses to run. ONLY call after MergeAbort returned "no merge in progress".
func ForceCleanMergeState(dir string) error {
	gd, err := gitDir(context.Background(), dir)
	if err != nil {
		return err
	}
	for _, f := range []string{"MERGE_HEAD", "MERGE_MSG", "MERGE_MODE"} {
		os.Remove(filepath.Join(gd, f)) // best-effort; ignore missing
	}
	return nil
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
