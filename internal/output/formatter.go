package output

import (
	"fmt"
	"path/filepath"

	"gitsync/internal/sync"
)

// ANSI color codes
const (
	colorReset  = "\033[0m"
	colorGreen  = "\033[0;32m"
	colorYellow = "\033[1;33m"
	colorRed    = "\033[0;31m"
	colorBlue   = "\033[0;34m"
)

// Formatter formats a RepoResult into a terminal-displayable string.
// It is a pure function — no I/O.
type Formatter struct {
	verbose     bool
	maxNameLen  int
}

// NewFormatter returns a Formatter.
// maxNameLen controls the column width for repo names (use ComputeMaxNameLen).
// When verbose is true, branch names are included in updated/rebased lines.
func NewFormatter(verbose bool, maxNameLen int) *Formatter {
	if maxNameLen < 1 {
		maxNameLen = 24
	}
	return &Formatter{verbose: verbose, maxNameLen: maxNameLen}
}

// Format returns the single-line display string for a repo result.
func (f *Formatter) Format(r sync.RepoResult) string {
	name := r.DisplayName
	if name == "" {
		name = filepath.Base(r.RepoPath)
	}
	pad := fmt.Sprintf("%%-%ds", f.maxNameLen)
	namePad := fmt.Sprintf(pad, name)

	elapsed := ""
	if r.ElapsedMs > 0 {
		elapsed = fmt.Sprintf(", %.1fs", float64(r.ElapsedMs)/1000)
	}
	branch := ""
	if f.verbose && r.CurrentBranch != "" {
		branch = fmt.Sprintf(" [%s]", r.CurrentBranch)
	}

	switch {
	case r.SkipReason == sync.SkipWhatIf:
		return fmt.Sprintf("  %s○%s %s (dry run: %s)",
			colorBlue, colorReset, namePad, r.WhatIfAction)

	case r.Status == sync.StatusUpdated:
		return fmt.Sprintf("  %s✓%s %s (updated %s%s%s)",
			colorGreen, colorReset, namePad, r.ParentBranch, elapsed, branch)

	case r.Status == sync.StatusReset:
		return fmt.Sprintf("  %s✓%s %s (reset --hard to %s%s%s)",
			colorGreen, colorReset, namePad, r.ParentBranch, elapsed, branch)

	case r.Status == sync.StatusRebased && r.ForceRebase:
		return fmt.Sprintf("  %s⚠%s %s (rebased — force-push needed: git push --force-with-lease origin %s)",
			colorYellow, colorReset, namePad, r.CurrentBranch)

	case r.Status == sync.StatusRebased:
		return fmt.Sprintf("  %s✓%s %s (rebased onto %s%s%s)",
			colorGreen, colorReset, namePad, r.ParentBranch, elapsed, branch)

	case r.Status == sync.StatusNoOp:
		return fmt.Sprintf("  %s•%s %s (up to date)",
			colorBlue, colorReset, namePad)

	case r.Status == sync.StatusSkipped:
		return fmt.Sprintf("  %s⊘%s %s (%s)",
			colorYellow, colorReset, namePad, r.SkipReason)

	case r.Status == sync.StatusStashConflict:
		return fmt.Sprintf("  %s⊘%s %s (stash pop conflict — run: git stash pop)",
			colorYellow, colorReset, namePad)

	case r.Status == sync.StatusRebaseConflict:
		return fmt.Sprintf("  %s✗%s %s (rebase conflict, rolled back)",
			colorRed, colorReset, namePad)

	case r.Status == sync.StatusFailed:
		return fmt.Sprintf("  %s✗%s %s (failed: %s)",
			colorRed, colorReset, namePad, r.FailReason)

	case r.Status == sync.StatusManualInterventionRequired:
		return fmt.Sprintf("  %s✗%s %s (manual intervention needed: %s)",
			colorRed, colorReset, namePad, r.FailReason)

	default:
		return fmt.Sprintf("  ? %s (unknown status %d)", namePad, r.Status)
	}
}

// ComputeMaxNameLen returns the width to use for the name column — the length
// of the longest display name, clamped to [minWidth, maxWidth].
func ComputeMaxNameLen(results []sync.RepoResult, minWidth, maxWidth int) int {
	n := minWidth
	for _, r := range results {
		name := r.DisplayName
		if name == "" {
			name = filepath.Base(r.RepoPath)
		}
		if len(name) > n {
			n = len(name)
		}
	}
	if n > maxWidth {
		return maxWidth
	}
	return n
}
