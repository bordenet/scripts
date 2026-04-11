package discover_test

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"gitsync/internal/discover"
)

func initRepo(t *testing.T, dir string) {
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

	repos := discover.Find(root, false)
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

	repos := discover.Find(root, false)
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

	repos := discover.Find(root, false)
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

	repos := discover.Find(root, false)
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

	repos := discover.Find(root, false)
	if len(repos) != 2 {
		t.Errorf("expected 2 repos (source repo must be included), got %d: %v", len(repos), repos)
	}
}
