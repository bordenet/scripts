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
type Formatter struct{}

// NewFormatter returns a Formatter.
func NewFormatter() *Formatter { return &Formatter{} }

// Format returns the single-line display string for a repo result.
func (f *Formatter) Format(r sync.RepoResult) string {
	name := filepath.Base(r.RepoPath)
	elapsed := ""
	if r.ElapsedMs > 0 {
		elapsed = fmt.Sprintf(", %.1fs", float64(r.ElapsedMs)/1000)
	}

	switch {
	case r.SkipReason == sync.SkipWhatIf:
		return fmt.Sprintf("  %s○%s %-24s (dry run: %s)",
			colorBlue, colorReset, name, r.WhatIfAction)

	case r.Status == sync.StatusUpdated:
		return fmt.Sprintf("  %s✓%s %-24s (updated %s%s)",
			colorGreen, colorReset, name, r.ParentBranch, elapsed)

	case r.Status == sync.StatusRebased && r.ForceRebase:
		return fmt.Sprintf("  %s⚠%s %-24s (rebased — force-push needed: git push --force-with-lease origin %s)",
			colorYellow, colorReset, name, r.CurrentBranch)

	case r.Status == sync.StatusRebased:
		return fmt.Sprintf("  %s✓%s %-24s (rebased onto %s%s)",
			colorGreen, colorReset, name, r.ParentBranch, elapsed)

	case r.Status == sync.StatusNoOp:
		return fmt.Sprintf("  %s•%s %-24s (up to date)",
			colorBlue, colorReset, name)

	case r.Status == sync.StatusSkipped:
		return fmt.Sprintf("  %s⊘%s %-24s (%s)",
			colorYellow, colorReset, name, r.SkipReason)

	case r.Status == sync.StatusStashConflict:
		return fmt.Sprintf("  %s⊘%s %-24s (stash pop conflict — run: git stash pop)",
			colorYellow, colorReset, name)

	case r.Status == sync.StatusRebaseConflict:
		return fmt.Sprintf("  %s✗%s %-24s (rebase conflict, rolled back)",
			colorRed, colorReset, name)

	case r.Status == sync.StatusFailed:
		return fmt.Sprintf("  %s✗%s %-24s (failed: %s)",
			colorRed, colorReset, name, r.FailReason)

	case r.Status == sync.StatusManualInterventionRequired:
		return fmt.Sprintf("  %s✗%s %-24s (manual intervention needed: %s)",
			colorRed, colorReset, name, r.FailReason)

	default:
		return fmt.Sprintf("  ? %-24s (unknown status %d)", name, r.Status)
	}
}
