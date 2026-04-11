package sync_test

import (
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	syncp "gitsync/internal/sync"
)

// makeRepo creates a git repo with one commit and returns its path.
func makeRepo(t *testing.T) string {
	t.Helper()
	dir := t.TempDir()
	mustRun(t, dir, "git", "init", "--initial-branch=main")
	mustRun(t, dir, "git", "config", "user.email", "test@test.com")
	mustRun(t, dir, "git", "config", "user.name", "Test")
	mustRun(t, dir, "git", "commit", "--allow-empty", "-m", "init")
	return dir
}

// makeRepoWithRemote creates a repo wired to a local "remote" repo.
// Returns (local, remote) paths.
func makeRepoWithRemote(t *testing.T) (string, string) {
	t.Helper()
	remote := makeRepo(t)
	local := t.TempDir()
	mustRun(t, t.TempDir(), "git", "clone", remote, local)
	mustRun(t, local, "git", "config", "user.email", "test@test.com")
	mustRun(t, local, "git", "config", "user.name", "Test")
	return local, remote
}

func mustRun(t *testing.T, dir string, args ...string) {
	t.Helper()
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Dir = dir
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("cmd %v: %v\n%s", args, err, out)
	}
}

func addCommit(t *testing.T, dir, msg string) {
	t.Helper()
	mustRun(t, dir, "git", "commit", "--allow-empty", "-m", msg)
}

func writeFile(t *testing.T, dir, name, content string) {
	t.Helper()
	if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0644); err != nil {
		t.Fatal(err)
	}
}

// makeRepoWithFile creates a local+remote pair where both have a tracked file.
func makeRepoWithFile(t *testing.T) (local, remote string) {
	t.Helper()
	remote = t.TempDir()
	mustRun(t, remote, "git", "init", "--initial-branch=main")
	mustRun(t, remote, "git", "config", "user.email", "test@test.com")
	mustRun(t, remote, "git", "config", "user.name", "Test")
	writeFile(t, remote, "tracked.txt", "initial")
	mustRun(t, remote, "git", "add", "tracked.txt")
	mustRun(t, remote, "git", "commit", "-m", "init with tracked file")
	local = t.TempDir()
	// git clone with absolute paths: cwd is irrelevant; use remote dir for stability.
	mustRun(t, remote, "git", "clone", remote, local)
	mustRun(t, local, "git", "config", "user.email", "test@test.com")
	mustRun(t, local, "git", "config", "user.name", "Test")
	return
}

func TestRun_UpToDate(t *testing.T) {
	local, _ := makeRepoWithRemote(t)
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusNoOp {
		t.Errorf("expected NoOp, got %v (skip: %s, fail: %s)", result.Status, result.SkipReason, result.FailReason)
	}
}

func TestRun_FastForward(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	// Add a commit to remote
	addCommit(t, remote, "remote commit")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusUpdated {
		t.Errorf("expected Updated, got %v (skip: %s, fail: %s)", result.Status, result.SkipReason, result.FailReason)
	}
}

func TestRun_LocalAhead(t *testing.T) {
	local, _ := makeRepoWithRemote(t)
	addCommit(t, local, "local only commit")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusNoOp {
		t.Errorf("expected NoOp (local ahead), got %v", result.Status)
	}
}

func TestRun_Diverged_Rebase(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	// Switch to a feature branch so Decide permits rebase (diverged default branch is always skipped)
	mustRun(t, local, "git", "checkout", "-b", "feature/test-branch")
	addCommit(t, remote, "remote commit")
	addCommit(t, local, "local commit")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusRebased {
		t.Errorf("expected Rebased, got %v (skip: %s, fail: %s)", result.Status, result.SkipReason, result.FailReason)
	}
}

func TestRun_NoRebase_Diverged(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	addCommit(t, remote, "remote commit")
	addCommit(t, local, "local commit")
	flags := syncp.Flags{NoRebase: true, FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusSkipped {
		t.Errorf("expected Skipped, got %v", result.Status)
	}
}

func TestRun_WhatIf(t *testing.T) {
	local, remote := makeRepoWithRemote(t)
	addCommit(t, remote, "remote commit")
	flags := syncp.Flags{WhatIf: true, FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	// --what-if: status must be Skipped with WhatIf reason, and action described
	if result.Status != syncp.StatusSkipped || result.SkipReason != syncp.SkipWhatIf {
		t.Errorf("expected StatusSkipped/SkipWhatIf, got status=%v reason=%q", result.Status, result.SkipReason)
	}
	if result.WhatIfAction == "" {
		t.Error("expected WhatIfAction to be non-empty")
	}
	// Verify the ff actually didn't happen by re-running without --what-if
	// and checking status is still Updated (meaning we didn't ff already)
	flags2 := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	result2 := syncp.Run(context.Background(), local, flags2, registry)
	if result2.Status != syncp.StatusUpdated {
		t.Errorf("after --what-if, real run should still update; got %v", result2.Status)
	}
}

func TestRun_EmptyRepo(t *testing.T) {
	dir := t.TempDir()
	mustRun(t, dir, "git", "init")
	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), dir, flags, registry)
	if result.Status != syncp.StatusSkipped || result.SkipReason != syncp.SkipEmptyRepo {
		t.Errorf("expected SkipEmptyRepo, got %v / %v", result.Status, result.SkipReason)
	}
}

func TestRun_FetchTimeout(t *testing.T) {
	local, _ := makeRepoWithRemote(t)
	// FetchTimeout=0 → context.WithTimeout(ctx, 0*time.Second) creates a context whose
	// deadline is already in the past. Go's context.WithDeadline calls cancel() synchronously
	// when the deadline has passed, so fetchCtx.Err() == context.DeadlineExceeded immediately.
	// FetchMultiRef checks ctx.Err() before spawning any subprocess, so this is deterministic.
	// NOTE: do not lower go.mod below go 1.20 without re-evaluating this test.
	flags := syncp.Flags{FetchTimeout: 0, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusSkipped || result.SkipReason != syncp.SkipFetchTimeout {
		t.Errorf("expected SkipFetchTimeout, got status=%v reason=%q", result.Status, result.SkipReason)
	}
}

func TestRun_FastForward_DirtyWorktree(t *testing.T) {
	local, remote := makeRepoWithFile(t)
	// Remote adds a new file (no conflict with local dirty state)
	writeFile(t, remote, "other.txt", "from-remote")
	mustRun(t, remote, "git", "add", "other.txt")
	addCommit(t, remote, "remote adds other file")
	// Dirty the local tracked.txt (unstaged)
	writeFile(t, local, "tracked.txt", "dirty-local")

	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusUpdated {
		t.Errorf("expected Updated (FF with stash), got %v (skip=%s fail=%s)", result.Status, result.SkipReason, result.FailReason)
	}
	// tracked.txt should be restored to local dirty content after stash pop
	content, err := os.ReadFile(filepath.Join(local, "tracked.txt"))
	if err != nil {
		t.Fatalf("tracked.txt missing after stash pop: %v", err)
	}
	if string(content) != "dirty-local" {
		t.Errorf("tracked.txt = %q after stash pop, want %q", string(content), "dirty-local")
	}
	// Registry must be empty — no orphaned stash entries
	if entries := registry.List(); len(entries) != 0 {
		t.Errorf("registry has %d orphaned entries after successful FF+stash", len(entries))
	}
}

func TestRun_Rebase_DirtyWorktree(t *testing.T) {
	local, remote := makeRepoWithFile(t)
	mustRun(t, local, "git", "checkout", "-b", "feature/stash-test")
	// Diverge: remote and local each add a distinct commit
	writeFile(t, remote, "remote-change.txt", "from-remote")
	mustRun(t, remote, "git", "add", "remote-change.txt")
	addCommit(t, remote, "remote commit")
	writeFile(t, local, "local-change.txt", "from-local")
	mustRun(t, local, "git", "add", "local-change.txt")
	addCommit(t, local, "local commit")
	// Dirty the local tracked.txt (unstaged)
	writeFile(t, local, "tracked.txt", "dirty-local")

	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusRebased {
		t.Errorf("expected Rebased (rebase with stash), got %v (skip=%s fail=%s)", result.Status, result.SkipReason, result.FailReason)
	}
	// tracked.txt should be restored to local dirty content after stash pop
	content, err := os.ReadFile(filepath.Join(local, "tracked.txt"))
	if err != nil {
		t.Fatalf("tracked.txt missing after stash pop: %v", err)
	}
	if string(content) != "dirty-local" {
		t.Errorf("tracked.txt = %q after stash pop, want %q", string(content), "dirty-local")
	}
	// Registry must be empty
	if entries := registry.List(); len(entries) != 0 {
		t.Errorf("registry has %d orphaned entries after successful rebase+stash", len(entries))
	}
}

func TestRun_FastForward_StashConflict(t *testing.T) {
	local, remote := makeRepoWithFile(t)
	// Remote modifies the SAME file that local has dirty — stash pop will conflict.
	writeFile(t, remote, "tracked.txt", "from-remote")
	mustRun(t, remote, "git", "add", "tracked.txt")
	addCommit(t, remote, "remote modifies tracked.txt")
	writeFile(t, local, "tracked.txt", "dirty-local")

	flags := syncp.Flags{FetchTimeout: 10, RebaseTimeout: 30, Concurrency: 1}
	registry := &syncp.StashRegistry{}
	result := syncp.Run(context.Background(), local, flags, registry)
	if result.Status != syncp.StatusStashConflict {
		t.Errorf("expected StatusStashConflict, got %v (skip=%s fail=%s)", result.Status, result.SkipReason, result.FailReason)
	}
	// Registry entry MUST remain — stash was not popped, interrupt handler can retry.
	if entries := registry.List(); len(entries) != 1 {
		t.Errorf("registry should have 1 orphaned entry after stash conflict, got %d", len(entries))
	}
}
