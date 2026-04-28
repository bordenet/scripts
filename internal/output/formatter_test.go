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
	got := buf.String()
	if !strings.Contains(got, "had issues") {
		t.Errorf("issues path must emit warning text, got:\n%s", got)
	}
	// Verdict must not be preceded by a blank line when groups fire — the
	// needsSeparator logic emits exactly one blank line via fmt.Fprintln(w, "").
	// Two consecutive newlines (\n\n) would indicate a re-introduced leading \n.
	if strings.Contains(got, "\n\n\n") {
		t.Errorf("issues path must not produce double blank lines, got:\n%q", got)
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
	// DRY RUN banner must always be emitted in WhatIf mode.
	if !strings.Contains(got, "DRY RUN") {
		t.Errorf("WhatIf summary must contain DRY RUN banner, got:\n%s", got)
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
	// Compact all-clean mode must not produce blank lines — no per-repo groups fire,
	// so needsSeparator=false and no \n\n should appear anywhere.
	if strings.Contains(got, "\n\n") {
		t.Errorf("compact all-clean summary must not contain blank lines, got:\n%q", got)
	}
	// Final verdict must be present.
	if !strings.Contains(got, "All repositories processed successfully") {
		t.Errorf("compact summary must contain success verdict, got:\n%s", got)
	}
}

func TestShowSummary_Verbose_GroupsListed(t *testing.T) {
	var buf bytes.Buffer
	results := []sync.RepoResult{
		{RepoPath: "/repos/a", DisplayName: "a", Status: sync.StatusUpdated, CurrentBranch: "main", ParentBranch: "main"},
		{RepoPath: "/repos/b", DisplayName: "b", Status: sync.StatusNoOp},
	}
	ok := output.ShowSummary(&buf, results, time.Second, sync.Flags{Verbose: true})
	if !ok {
		t.Errorf("verbose all-clean must return true")
	}
	got := buf.String()
	if !strings.Contains(got, "Updated") {
		t.Errorf("verbose summary must contain 'Updated' group header: %q", got)
	}
	if !strings.Contains(got, "Up to date") {
		t.Errorf("verbose summary must contain 'Up to date' group: %q", got)
	}
	// In verbose mode a blank separator must appear before the verdict to visually
	// distinguish the per-repo list from the overall conclusion line.
	if !strings.Contains(got, "\n\n") {
		t.Errorf("verbose summary must have blank line before verdict: %q", got)
	}
	if !strings.Contains(got, "All repositories processed successfully") {
		t.Errorf("verbose summary must contain success verdict: %q", got)
	}
}

func TestShowSummary_WithSkipped_SeparatorBeforeVerdict(t *testing.T) {
	var buf bytes.Buffer
	results := []sync.RepoResult{
		{RepoPath: "/repos/a", DisplayName: "a", Status: sync.StatusUpdated},
		{RepoPath: "/repos/b", DisplayName: "b", Status: sync.StatusSkipped, SkipReason: sync.SkipEmptyRepo},
	}
	ok := output.ShowSummary(&buf, results, time.Second, sync.Flags{})
	if !ok {
		t.Errorf("run with skipped repos must return true (skipped is not a failure)")
	}
	got := buf.String()
	// When skipped repos are listed (per-repo bullet lines), a blank line must
	// separate the list from the verdict to prevent visual ambiguity.
	if !strings.Contains(got, "\n\n") {
		t.Errorf("summary with skipped repos must have blank line before verdict: %q", got)
	}
	if !strings.Contains(got, "All repositories processed successfully") {
		t.Errorf("summary with skipped repos must contain success verdict: %q", got)
	}
}
