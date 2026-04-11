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
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "✓") || !strings.Contains(got, "myrepo") {
		t.Errorf("Updated format missing expected content: %q", got)
	}
}

func TestFormat_Skipped(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusSkipped,
		SkipReason: sync.SkipEmptyRepo}
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "⊘") {
		t.Errorf("Skipped format missing ⊘: %q", got)
	}
}

func TestFormat_WhatIf(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusSkipped,
		SkipReason: sync.SkipWhatIf, WhatIfAction: "would fast-forward main"}
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "○") {
		t.Errorf("WhatIf format missing ○: %q", got)
	}
}

func TestFormat_ForceRebase(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		ForceRebase: true, CurrentBranch: "feature/x", ParentBranch: "main"}
	got := output.NewFormatter().Format(r)
	if !strings.Contains(got, "⚠") {
		t.Errorf("ForceRebase format missing ⚠: %q", got)
	}
}
