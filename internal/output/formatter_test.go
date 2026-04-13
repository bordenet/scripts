package output_test

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"gitsync/internal/output"
	"gitsync/internal/sync"
)

func TestFormat_Updated(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusUpdated,
		CurrentBranch: "main", ParentBranch: "main", ElapsedMs: 1200}
	got := output.NewFormatter(false, 24).Format(r)
	if !strings.Contains(got, "✓") || !strings.Contains(got, "myrepo") {
		t.Errorf("Updated format missing expected content: %q", got)
	}
}

func TestFormat_Skipped(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusSkipped,
		SkipReason: sync.SkipEmptyRepo}
	got := output.NewFormatter(false, 24).Format(r)
	if !strings.Contains(got, "⊘") {
		t.Errorf("Skipped format missing ⊘: %q", got)
	}
}

func TestFormat_WhatIf(t *testing.T) {
	// Canonical WhatIf non-skip result: execute.go produces StatusUpdated (not Skipped)
	// with WhatIfAction set. SkipWhatIf is set as a legacy side-effect; the formatter
	// now routes via WhatIfAction != "" so StatusUpdated triggers the dry-run branch.
	r := sync.RepoResult{
		RepoPath:     "/repos/myrepo",
		Status:       sync.StatusUpdated,
		SkipReason:   sync.SkipWhatIf,
		WhatIfAction: "would fast-forward main from origin/main",
	}
	got := output.NewFormatter(false, 24).Format(r)
	if !strings.Contains(got, "○") {
		t.Errorf("WhatIf format missing ○: %q", got)
	}
	if !strings.Contains(got, "dry run") {
		t.Errorf("WhatIf format missing 'dry run': %q", got)
	}
}

func TestFormat_WhatIf_ActionSkip(t *testing.T) {
	// WhatIf ActionSkip: real skip reason set alongside WhatIfAction — distinct from
	// non-skip WhatIf results (which have StatusUpdated/Rebased/etc).
	r := sync.RepoResult{
		RepoPath:     "/repos/myrepo",
		Status:       sync.StatusSkipped,
		SkipReason:   sync.SkipNoStash,
		WhatIfAction: "would skip — local changes",
	}
	got := output.NewFormatter(false, 24).Format(r)
	if !strings.Contains(got, "○") {
		t.Errorf("WhatIf ActionSkip format missing ○: %q", got)
	}
	if !strings.Contains(got, "dry run") {
		t.Errorf("WhatIf ActionSkip format missing 'dry run': %q", got)
	}
	if !strings.Contains(got, string(sync.SkipNoStash)) {
		t.Errorf("WhatIf ActionSkip format missing skip reason %q: %q", sync.SkipNoStash, got)
	}
}

func TestFormat_ForceRebase(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		ForceRebase: true, CurrentBranch: "feature/x", ParentBranch: "main"}
	got := output.NewFormatter(false, 24).Format(r)
	if !strings.Contains(got, "⚠") {
		t.Errorf("ForceRebase format missing ⚠: %q", got)
	}
}

func TestFormat_Updated_Verbose(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusUpdated,
		CurrentBranch: "main", ParentBranch: "main", ElapsedMs: 500}
	got := output.NewFormatter(true, 24).Format(r)
	if !strings.Contains(got, "[main]") {
		t.Errorf("verbose Updated missing branch suffix: %q", got)
	}
}

func TestFormat_Rebased_Verbose(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		CurrentBranch: "feature/foo", ParentBranch: "main"}
	got := output.NewFormatter(true, 24).Format(r)
	if !strings.Contains(got, "[feature/foo]") {
		t.Errorf("verbose Rebased missing branch suffix: %q", got)
	}
}

func TestFormat_ForceRebase_Verbose_NoDuplicateBranch(t *testing.T) {
	r := sync.RepoResult{RepoPath: "/repos/myrepo", Status: sync.StatusRebased,
		ForceRebase: true, CurrentBranch: "feature/x", ParentBranch: "main"}
	got := output.NewFormatter(true, 24).Format(r)
	// Branch name must appear exactly once (in the git command), not duplicated as a suffix.
	if count := strings.Count(got, "feature/x"); count != 1 {
		t.Errorf("ForceRebase verbose: branch 'feature/x' appears %d times, want 1: %q", count, got)
	}
}

// ── ShowSummary tests ─────────────────────────────────────────────────────────

func TestShowSummary_StashConflict_ExitsNonZero(t *testing.T) {
	var buf bytes.Buffer
	results := []sync.RepoResult{{
		RepoPath: "/repos/r", DisplayName: "r",
		Status: sync.StatusStashConflict,
	}}
	ok := output.ShowSummary(&buf, results, time.Second, sync.Flags{})
	if ok {
		t.Errorf("ShowSummary with StashConflict must return false (exit 1), got true.\nOutput:\n%s", buf.String())
	}
}

func TestShowSummary_WhatIf_ForceRebase_AdvisoryOnly(t *testing.T) {
	var buf bytes.Buffer
	// WhatIfAction is intentionally omitted — ShowSummary never reads it.
	results := []sync.RepoResult{{
		RepoPath: "/repos/feat", DisplayName: "feat",
		Status: sync.StatusRebased, ForceRebase: true,
		CurrentBranch: "feature",
	}}
	output.ShowSummary(&buf, results, time.Second, sync.Flags{WhatIf: true, ForceRebase: true})
	got := buf.String()
	// The advisory block uses a "Would need" header; the live block does not.
	// Asserting the header is present confirms we took the WhatIf branch.
	if !strings.Contains(got, "Would need force-push") {
		t.Errorf("WhatIf summary must use advisory header, got:\n%s", got)
	}
	// The git push command is still present (for copy-paste convenience) but
	// only under the advisory header — not as a bare action command.
	if !strings.Contains(got, "git push --force-with-lease origin feature") {
		t.Errorf("WhatIf summary must still show the push command for reference, got:\n%s", got)
	}
}

func TestShowSummary_CompactMode_SuccessOneLiner(t *testing.T) {
	var buf bytes.Buffer
	results := []sync.RepoResult{
		{RepoPath: "/repos/a", DisplayName: "a", Status: sync.StatusUpdated},
		{RepoPath: "/repos/b", DisplayName: "b", Status: sync.StatusNoOp},
	}
	ok := output.ShowSummary(&buf, results, time.Second, sync.Flags{})
	if !ok {
		t.Errorf("ShowSummary with all-clean results must return true, got false")
	}
	got := buf.String()
	if !strings.Contains(got, "synced") {
		t.Errorf("compact summary should contain 'synced': %q", got)
	}
	if !strings.Contains(got, "already current") {
		t.Errorf("compact summary should contain 'already current': %q", got)
	}
}
