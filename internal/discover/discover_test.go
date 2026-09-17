package discover_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"gitsync/internal/discover"
)

// initRepo creates a git repo with a fake remote so discover treats it as a
// leaf repo (repos without remotes are treated as organisational containers).
func initRepo(t *testing.T, dir string) {
	t.Helper()
	for _, args := range [][]string{
		{"git", "init", dir},
		{"git", "-C", dir, "config", "user.email", "test@test.com"},
		{"git", "-C", dir, "config", "user.name", "Test"},
		{"git", "-C", dir, "remote", "add", "origin", "https://example.com/repo.git"},
	} {
		if err := exec.Command(args[0], args[1:]...).Run(); err != nil {
			t.Fatalf("setup %v: %v", args, err)
		}
	}
}

// initContainerRepo creates a git repo with NO remote — simulates a top-level
// directory that was `git init`-ed but never pushed (e.g. ~/GitHub/WorkOrg).
// discover should recurse into it rather than surfacing it as a skipped leaf.
func initContainerRepo(t *testing.T, dir string) {
	t.Helper()
	for _, args := range [][]string{
		{"git", "init", dir},
		{"git", "-C", dir, "config", "user.email", "test@test.com"},
		{"git", "-C", dir, "config", "user.name", "Test"},
	} {
		if err := exec.Command(args[0], args[1:]...).Run(); err != nil {
			t.Fatalf("setup %v: %v", args, err)
		}
	}
}

// TestFind_TargetDirIsRepo covers the case where the user points gitsync directly
// at a git repo rather than a parent directory containing repos.
func TestFind_TargetDirIsRepo(t *testing.T) {
	root := t.TempDir()
	initRepo(t, root)

	// Resolve symlinks to match what Find() returns internally (macOS: /var -> /private/var).
	rootCanon, err := filepath.EvalSymlinks(root)
	if err != nil {
		t.Fatalf("EvalSymlinks: %v", err)
	}

	repos := discover.Find(root)
	if len(repos) != 1 {
		t.Fatalf("expected 1 repo (targetDir itself), got %d: %v", len(repos), repos)
	}
	if repos[0] != rootCanon {
		t.Errorf("expected %s, got %s", rootCanon, repos[0])
	}
}

func TestFind_BasicDiscovery(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	repoB := filepath.Join(root, "repoB")
	initRepo(t, repoA)
	initRepo(t, repoB)

	repos := discover.Find(root)
	if len(repos) != 2 {
		t.Errorf("expected 2 repos, got %d: %v", len(repos), repos)
	}
}

func TestFind_SymlinkDedup(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	initRepo(t, repoA)
	// Create symlink to same repo
	link := filepath.Join(root, "repoA-link")
	if err := os.Symlink(repoA, link); err != nil {
		t.Skip("symlinks not supported")
	}

	repos := discover.Find(root)
	if len(repos) != 1 {
		t.Errorf("expected 1 repo after dedup, got %d: %v", len(repos), repos)
	}
}

func TestFind_FetchIgnore(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	repoB := filepath.Join(root, "repoB")
	initRepo(t, repoA)
	initRepo(t, repoB)

	// Write .fetchignore excluding repoB
	if err := os.WriteFile(filepath.Join(root, ".fetchignore"), []byte("repoB\n"), 0644); err != nil {
		t.Fatal(err)
	}

	repos := discover.Find(root)
	if len(repos) != 1 {
		t.Errorf("expected 1 repo (repoB excluded), got %d: %v", len(repos), repos)
	}
	if len(repos) == 1 && filepath.Base(repos[0]) == "repoB" {
		t.Error("repoB should have been excluded by .fetchignore")
	}
}

// TestFind_SourceRepoIsIncluded verifies that the gitsync source repo itself
// IS included in results — it must be synced like any other repo.
// (Self-exclusion via GITSYNC_SOURCE_DIR was removed; it caused the scripts
// repo to silently skip itself on every --all run.)
func TestFind_SourceRepoIsIncluded(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	repoSource := filepath.Join(root, "scripts")
	initRepo(t, repoA)
	initRepo(t, repoSource)

	repos := discover.Find(root)
	if len(repos) != 2 {
		t.Errorf("expected 2 repos (source repo must be included), got %d: %v", len(repos), repos)
	}
}

// TestFind_ContainerRepoIsRecursed verifies that a git repo with no remote
// (e.g. ~/GitHub/WorkOrg) is treated as an organisational container: discover
// recurses into it to find the real repos inside rather than surfacing it as a
// skipped leaf with "no origin remote".
func TestFind_ContainerRepoIsRecursed(t *testing.T) {
	root := t.TempDir()

	// container has .git but no remote — simulates ~/GitHub/WorkOrg
	container := filepath.Join(root, "WorkOrg")
	initContainerRepo(t, container)

	// real repos live inside the container
	inner1 := filepath.Join(container, "tools", "superpowers-plus")
	inner2 := filepath.Join(container, "platform", "service-a")
	if err := os.MkdirAll(filepath.Dir(inner1), 0755); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(inner2), 0755); err != nil {
		t.Fatal(err)
	}
	initRepo(t, inner1)
	initRepo(t, inner2)

	repos := discover.Find(root)
	if len(repos) != 2 {
		t.Errorf("expected 2 inner repos, got %d: %v", len(repos), repos)
	}
	for _, r := range repos {
		base := filepath.Base(r)
		if base != "superpowers-plus" && base != "service-a" {
			t.Errorf("unexpected repo in results: %s", r)
		}
	}
}

// initRepoWithCommit creates a repo with a real commit and a remote pointing
// at a local bare repo, so `git worktree add` (which requires a valid HEAD)
// works against it. Returns the repo dir.
func initRepoWithCommit(t *testing.T, dir string) {
	t.Helper()
	bareDir := dir + "-bare.git"
	for _, args := range [][]string{
		{"git", "init", "-q", "--bare", "-b", "main", bareDir},
		{"git", "clone", "-q", bareDir, dir},
		{"git", "-C", dir, "config", "user.email", "test@test.com"},
		{"git", "-C", dir, "config", "user.name", "Test"},
	} {
		if err := exec.Command(args[0], args[1:]...).Run(); err != nil {
			t.Fatalf("setup %v: %v", args, err)
		}
	}
	if err := os.WriteFile(filepath.Join(dir, "f.txt"), []byte("a\n"), 0644); err != nil {
		t.Fatalf("write f.txt: %v", err)
	}
	for _, args := range [][]string{
		{"git", "-C", dir, "add", "f.txt"},
		{"git", "-C", dir, "commit", "-q", "-m", "c1"},
		{"git", "-C", dir, "push", "-q", "-u", "origin", "main"},
	} {
		if err := exec.Command(args[0], args[1:]...).Run(); err != nil {
			t.Fatalf("setup %v: %v", args, err)
		}
	}
}

// addWorktree runs `git worktree add -b <branch> <worktreePath> <fromRef>`
// against repoDir.
func addWorktree(t *testing.T, repoDir, worktreePath, branch, fromRef string) {
	t.Helper()
	cmd := exec.Command("git", "-C", repoDir, "worktree", "add", "-q", "-b", branch, worktreePath, fromRef)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("git worktree add: %v\n%s", err, out)
	}
}

// TestFind_WorktreeDiscoveredWhenTargetDirIsRepo covers pointing gitsync
// directly at a repo (targetDir IS the repo) that has a ".worktrees"
// subdirectory: both the main checkout and the worktree checkout must be
// discovered, since each is an independently-syncable branch.
func TestFind_WorktreeDiscoveredWhenTargetDirIsRepo(t *testing.T) {
	root := t.TempDir()
	repo := filepath.Join(root, "repo")
	initRepoWithCommit(t, repo)
	addWorktree(t, repo, filepath.Join(repo, ".worktrees", "feat", "x"), "feat/x", "main")

	repoCanon, err := filepath.EvalSymlinks(repo)
	if err != nil {
		t.Fatalf("EvalSymlinks: %v", err)
	}

	repos := discover.Find(repo)
	if len(repos) != 2 {
		t.Fatalf("expected 2 repos (main checkout + worktree), got %d: %v", len(repos), repos)
	}
	found := map[string]bool{}
	for _, r := range repos {
		found[r] = true
	}
	if !found[repoCanon] {
		t.Errorf("main checkout %s not in results: %v", repoCanon, repos)
	}
	wtPath := filepath.Join(repoCanon, ".worktrees", "feat", "x")
	if !found[wtPath] {
		t.Errorf("worktree %s not in results: %v", wtPath, repos)
	}
}

// TestFind_WorktreeDiscoveredViaParentWalk covers the more common case: the
// user points gitsync at a PARENT directory containing several repos, one of
// which has a ".worktrees" subdirectory. The worktree must be discovered as a
// sibling result alongside the repo's main checkout, not silently dropped.
func TestFind_WorktreeDiscoveredViaParentWalk(t *testing.T) {
	root := t.TempDir()
	repo := filepath.Join(root, "repo")
	initRepoWithCommit(t, repo)
	addWorktree(t, repo, filepath.Join(repo, ".worktrees", "feat", "y"), "feat/y", "main")

	repoCanon, err := filepath.EvalSymlinks(repo)
	if err != nil {
		t.Fatalf("EvalSymlinks: %v", err)
	}

	repos := discover.Find(root)
	if len(repos) != 2 {
		t.Fatalf("expected 2 repos (main checkout + worktree), got %d: %v", len(repos), repos)
	}
	found := map[string]bool{}
	for _, r := range repos {
		found[r] = true
	}
	if !found[repoCanon] {
		t.Errorf("main checkout %s not in results: %v", repoCanon, repos)
	}
	wtPath := filepath.Join(repoCanon, ".worktrees", "feat", "y")
	if !found[wtPath] {
		t.Errorf("worktree %s not in results: %v", wtPath, repos)
	}
}

// TestFind_PlainDotDirectoriesStillSkipped verifies the ".worktrees" carve-out
// didn't accidentally widen the dot-directory skip to other dot-dirs (.git,
// .github, etc. must remain invisible to discovery).
func TestFind_PlainDotDirectoriesStillSkipped(t *testing.T) {
	root := t.TempDir()
	repo := filepath.Join(root, "repo")
	initRepo(t, repo)
	// A dot-directory containing what LOOKS like a repo must still be skipped
	// (e.g. .github/, .vscode/ never house real per-branch checkouts).
	hidden := filepath.Join(repo, ".hidden-nested")
	if err := os.MkdirAll(hidden, 0755); err != nil {
		t.Fatal(err)
	}
	initRepo(t, filepath.Join(hidden, "should-not-be-found"))

	repos := discover.Find(root)
	if len(repos) != 1 {
		t.Errorf("expected 1 repo (dot-dir contents skipped), got %d: %v", len(repos), repos)
	}
}
