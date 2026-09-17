package sync

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

// mustRunLocal runs a git command in dir, failing the test on error.
// Package-local counterpart to sync_test's mustRun (unexported there).
func mustRunLocal(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command(args[0], args[1:]...) // #nosec G204 -- test helper, args are hardcoded git commands
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("cmd %v: %v\n%s", args, err, out)
	}
}

// makeRepoWithRemoteLocal creates a local+remote clone pair on "main" with one
// commit, wired via a real origin remote. Mirrors sync_test.makeRepoWithRemote
// but lives in package sync (needed here since isLikelyInSync is unexported).
func makeRepoWithRemoteLocal(t *testing.T) (local, remote string) {
	t.Helper()
	remote = t.TempDir()
	mustRunLocal(t, remote, "git", "init", "--initial-branch=main")
	mustRunLocal(t, remote, "git", "config", "user.email", "test@test.com")
	mustRunLocal(t, remote, "git", "config", "user.name", "Test")
	mustRunLocal(t, remote, "git", "commit", "--allow-empty", "-m", "init")

	local = t.TempDir()
	mustRunLocal(t, t.TempDir(), "git", "clone", remote, local)
	mustRunLocal(t, local, "git", "config", "user.email", "test@test.com")
	mustRunLocal(t, local, "git", "config", "user.name", "Test")
	// `git clone` does NOT create .git/FETCH_HEAD (only `git fetch` does) --
	// an explicit no-op fetch here gives every test a real starting FETCH_HEAD
	// to rewrite the mtime of, matching what a genuinely-synced working repo
	// looks like on disk.
	mustRunLocal(t, local, "git", "fetch", "origin", "main")
	return local, remote
}

// setFetchHeadAge rewrites the mtime of repoPath/.git/FETCH_HEAD (created by
// the clone/fetch that already ran) to simulate it being fresh or stale.
func setFetchHeadAge(t *testing.T, repoPath string, age time.Duration) {
	t.Helper()
	fetchHead := filepath.Join(repoPath, ".git", "FETCH_HEAD")
	mtime := time.Now().Add(-age)
	if err := os.Chtimes(fetchHead, mtime, mtime); err != nil {
		t.Fatalf("chtimes FETCH_HEAD: %v", err)
	}
}

// revParseTrim runs `git -C dir rev-parse ref` and returns the trimmed SHA.
func revParseTrim(t *testing.T, dir, ref string) string {
	t.Helper()
	out, err := exec.Command("git", "-C", dir, "rev-parse", ref).Output() //nolint:gosec
	if err != nil {
		t.Fatalf("rev-parse %s in %s: %v", ref, dir, err)
	}
	return strings.TrimSpace(string(out))
}

// TestRun_SkipRecentGate covers both the original freshen.sh "everything got
// skipped" symptom and its regression: a repo that is genuinely caught up
// must skip cheaply, but a repo whose FETCH_HEAD was freshened by someone
// else's fetch (IDE auto-fetch, another terminal, a manual `git fetch`)
// without a merge must NOT be skipped just because FETCH_HEAD looks recent --
// isLikelyInSync()'s local-only HEAD-vs-origin/<branch> check must catch that
// and fall through to a real sync.
func TestRun_SkipRecentGate(t *testing.T) {
	t.Run("skips when in sync and FETCH_HEAD is within the window", func(t *testing.T) {
		local, _ := makeRepoWithRemoteLocal(t)
		setFetchHeadAge(t, local, 5*time.Second)

		flags := Flags{SkipRecent: 900} // 15 minutes, matches freshen.sh's default
		result := Run(context.Background(), local, flags, &StashRegistry{}, DefaultSyncer{})

		if result.Status != StatusSkipped {
			t.Fatalf("Status = %v, want StatusSkipped", result.Status)
		}
		if result.SkipReason != SkipRecentFetch {
			t.Fatalf("SkipReason = %q, want %q", result.SkipReason, SkipRecentFetch)
		}
		if result.SkipDetail == "" {
			t.Error("SkipDetail is empty, want a human-readable age (e.g. \"5s ago\")")
		}
	})

	t.Run("does NOT skip when FETCH_HEAD is fresh but local is behind (regression)", func(t *testing.T) {
		local, remote := makeRepoWithRemoteLocal(t)
		// Someone else pushes to remote after the clone.
		mustRunLocal(t, remote, "git", "commit", "--allow-empty", "-m", "second commit")
		// Simulate a background fetch (IDE, another terminal) that refreshes
		// FETCH_HEAD and the cached origin/main ref WITHOUT merging into local HEAD.
		mustRunLocal(t, local, "git", "fetch", "origin", "main")
		setFetchHeadAge(t, local, 5*time.Second)

		flags := Flags{SkipRecent: 900, FetchTimeout: 30}
		result := Run(context.Background(), local, flags, &StashRegistry{}, DefaultSyncer{})

		if result.Status == StatusSkipped && result.SkipReason == SkipRecentFetch {
			t.Fatal("repo behind origin/main was skipped due to a fresh FETCH_HEAD from someone else's fetch")
		}
		// The real sync must have happened: local HEAD should now match remote.
		headSHA := revParseTrim(t, local, "HEAD")
		remoteSHA := revParseTrim(t, remote, "main")
		if headSHA != remoteSHA {
			t.Errorf("local HEAD (%s) did not converge to remote main (%s) after fall-through sync", headSHA, remoteSHA)
		}
	})

	t.Run("does not skip when FETCH_HEAD is older than the window", func(t *testing.T) {
		local, _ := makeRepoWithRemoteLocal(t)
		setFetchHeadAge(t, local, 20*time.Minute)

		flags := Flags{SkipRecent: 900, FetchTimeout: 30}
		result := Run(context.Background(), local, flags, &StashRegistry{}, DefaultSyncer{})

		if result.Status == StatusSkipped && result.SkipReason == SkipRecentFetch {
			t.Fatal("stale FETCH_HEAD (20m) was treated as recent under a 900s window")
		}
	})

	t.Run("does not skip when SkipRecent is disabled", func(t *testing.T) {
		local, _ := makeRepoWithRemoteLocal(t)
		setFetchHeadAge(t, local, 5*time.Second)

		flags := Flags{SkipRecent: 0, FetchTimeout: 30}
		result := Run(context.Background(), local, flags, &StashRegistry{}, DefaultSyncer{})

		if result.Status == StatusSkipped && result.SkipReason == SkipRecentFetch {
			t.Fatal("SkipRecent=0 (disabled) still triggered the recent-fetch skip")
		}
	})

	t.Run("fails open when FETCH_HEAD is missing", func(t *testing.T) {
		repoPath := t.TempDir() // no .git dir at all

		flags := Flags{SkipRecent: 900}
		result := Run(context.Background(), repoPath, flags, &StashRegistry{}, DefaultSyncer{})

		if result.Status == StatusSkipped && result.SkipReason == SkipRecentFetch {
			t.Fatal("missing FETCH_HEAD was treated as a recent fetch instead of falling through")
		}
	})
}

// TestIsLikelyInSync exercises the helper directly for the cases Run()'s gate
// depends on: true only when on the default branch with local HEAD == cached
// origin/<branch>; false for feature branches (must always fall through to
// the full Decide()-driven path) and for any local-vs-remote mismatch.
func TestIsLikelyInSync(t *testing.T) {
	t.Run("true when default branch and HEAD matches origin", func(t *testing.T) {
		local, _ := makeRepoWithRemoteLocal(t)
		if !isLikelyInSync(context.Background(), local) {
			t.Error("expected true for a freshly-cloned, unmodified default-branch repo")
		}
	})

	t.Run("false when local is behind origin", func(t *testing.T) {
		local, remote := makeRepoWithRemoteLocal(t)
		mustRunLocal(t, remote, "git", "commit", "--allow-empty", "-m", "second commit")
		mustRunLocal(t, local, "git", "fetch", "origin", "main")
		if isLikelyInSync(context.Background(), local) {
			t.Error("expected false when local HEAD is behind the cached origin/main ref")
		}
	})

	t.Run("false on a feature branch", func(t *testing.T) {
		local, _ := makeRepoWithRemoteLocal(t)
		mustRunLocal(t, local, "git", "checkout", "-b", "feature/x")
		if isLikelyInSync(context.Background(), local) {
			t.Error("expected false on a non-default branch -- must always fall through to Decide()")
		}
	})
}
