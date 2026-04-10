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

func TestFind_SelfExclusion(t *testing.T) {
	root := t.TempDir()
	repoA := filepath.Join(root, "repoA")
	repoSelf := filepath.Join(root, "gitsync-source")
	initRepo(t, repoA)
	initRepo(t, repoSelf)

	t.Setenv("GITSYNC_SOURCE_DIR", repoSelf)

	repos := discover.Find(root, false)
	for _, r := range repos {
		if r == repoSelf {
			t.Error("GITSYNC_SOURCE_DIR repo should be excluded")
		}
	}
}
