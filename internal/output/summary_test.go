package output

import (
	"bytes"
	"strings"
	"testing"
	"time"

	"gitsync/internal/sync"
)

// TestShowSummary_GroupsSkipReasons is the regression test for the
// freshen.sh confusion: a bare "N skipped: repo1, repo2, ..." line reads as a
// failure whether the cause is benign (fetched moments ago) or a real problem
// (no origin remote). Compact-mode output must name the reason per group.
func TestShowSummary_GroupsSkipReasons(t *testing.T) {
	results := []sync.RepoResult{
		{RepoPath: "/repos/a", DisplayName: "a", Status: sync.StatusSkipped, SkipReason: sync.SkipRecentFetch},
		{RepoPath: "/repos/b", DisplayName: "b", Status: sync.StatusSkipped, SkipReason: sync.SkipRecentFetch},
		{RepoPath: "/repos/c", DisplayName: "c", Status: sync.StatusSkipped, SkipReason: sync.SkipNoRemote},
	}

	var buf bytes.Buffer
	ShowSummary(&buf, results, time.Second, sync.Flags{})
	out := buf.String()

	if !strings.Contains(out, string(sync.SkipRecentFetch)) {
		t.Errorf("compact summary missing SkipRecentFetch reason text; got:\n%s", out)
	}
	if !strings.Contains(out, string(sync.SkipNoRemote)) {
		t.Errorf("compact summary missing SkipNoRemote reason text; got:\n%s", out)
	}
	// The two reasons must appear on separate lines, not merged into one
	// undifferentiated "3 skipped: a, b, c" line.
	recentLine, remoteLine := "", ""
	for _, line := range strings.Split(out, "\n") {
		if strings.Contains(line, string(sync.SkipRecentFetch)) {
			recentLine = line
		}
		if strings.Contains(line, string(sync.SkipNoRemote)) {
			remoteLine = line
		}
	}
	if recentLine == "" || remoteLine == "" || recentLine == remoteLine {
		t.Errorf("expected distinct lines per skip reason; recentLine=%q remoteLine=%q", recentLine, remoteLine)
	}
	if !strings.Contains(recentLine, "a") || !strings.Contains(recentLine, "b") {
		t.Errorf("SkipRecentFetch line missing expected repo names: %q", recentLine)
	}
	if !strings.Contains(remoteLine, "c") {
		t.Errorf("SkipNoRemote line missing expected repo name: %q", remoteLine)
	}
}

// TestShowSummary_VerboseSkipReasonDetail verifies --verbose bullets carry the
// reason (and optional detail) per repo, not just the bare name.
func TestShowSummary_VerboseSkipReasonDetail(t *testing.T) {
	results := []sync.RepoResult{
		{RepoPath: "/repos/a", DisplayName: "a", Status: sync.StatusSkipped, SkipReason: sync.SkipRecentFetch, SkipDetail: "12s ago"},
	}

	var buf bytes.Buffer
	ShowSummary(&buf, results, time.Second, sync.Flags{Verbose: true})
	out := buf.String()

	if !strings.Contains(out, "a") || !strings.Contains(out, string(sync.SkipRecentFetch)) || !strings.Contains(out, "12s ago") {
		t.Errorf("verbose skipped bullet missing name/reason/detail; got:\n%s", out)
	}
}
