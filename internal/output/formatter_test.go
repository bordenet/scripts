package output_test

import (
	"strings"
	"testing"

	"gitsync/internal/output"
	"gitsync/internal/sync"
)

func TestFormat_Updated(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusUpdated,
		CurrentBranch: "main", ParentBranch: "main", ElapsedMs: 1200}
	got := output.NewFormatter(false).Format(r)
	if !strings.Contains(got, "✓") || !strings.Contains(got, "myrepo") {
		t.Errorf("Updated format missing expected content: %q", got)
	}
}

func TestFormat_Skipped(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusSkipped,
		SkipReason: sync.SkipEmptyRepo}
	got := output.NewFormatter(false).Format(r)
	if !strings.Contains(got, "⊘") {
		t.Errorf("Skipped format missing ⊘: %q", got)
	}
}

func TestFormat_WhatIf(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusSkipped,
		SkipReason: sync.SkipWhatIf, WhatIfAction: "would fast-forward main"}
	got := output.NewFormatter(false).Format(r)
	if !strings.Contains(got, "○") {
		t.Errorf("WhatIf format missing ○: %q", got)
	}
}

func TestFormat_ForceRebase(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		ForceRebase: true, CurrentBranch: "feature/x", ParentBranch: "main"}
	got := output.NewFormatter(false).Format(r)
	if !strings.Contains(got, "⚠") {
		t.Errorf("ForceRebase format missing ⚠: %q", got)
	}
}

func TestFormat_Updated_Verbose(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusUpdated,
		CurrentBranch: "main", ParentBranch: "main", ElapsedMs: 500}
	got := output.NewFormatter(true).Format(r)
	if !strings.Contains(got, "[main]") {
		t.Errorf("verbose Updated missing branch suffix: %q", got)
	}
}

func TestFormat_Rebased_Verbose(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		CurrentBranch: "feature/foo", ParentBranch: "main"}
	got := output.NewFormatter(true).Format(r)
	if !strings.Contains(got, "[feature/foo]") {
		t.Errorf("verbose Rebased missing branch suffix: %q", got)
	}
}

func TestFormat_ForceRebase_Verbose_NoDuplicateBranch(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		ForceRebase: true, CurrentBranch: "feature/x", ParentBranch: "main"}
	got := output.NewFormatter(true).Format(r)
	// Branch name must appear exactly once (in the git command), not duplicated as a suffix.
	if count := strings.Count(got, "feature/x"); count != 1 {
		t.Errorf("ForceRebase verbose: branch 'feature/x' appears %d times, want 1: %q", count, got)
	}
}
