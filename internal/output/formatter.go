package output

import (
	"fmt"
	"path/filepath"

	"github.com/charmbracelet/lipgloss"

	"gitsync/internal/sync"
)

// Shared lipgloss styles used by both the formatter and summary renderer.
// Lipgloss automatically disables colour when the terminal doesn't support it
// (NO_COLOR env var, dumb terminal, piped output, etc.).
var (
	styleGreen  = lipgloss.NewStyle().Foreground(lipgloss.Color("2"))
	styleYellow = lipgloss.NewStyle().Foreground(lipgloss.Color("3")).Bold(true)
	styleRed    = lipgloss.NewStyle().Foreground(lipgloss.Color("1"))
	styleBlue   = lipgloss.NewStyle().Foreground(lipgloss.Color("4"))
)

// Formatter formats a RepoResult into a terminal-displayable string.
// It holds immutable configuration after construction and is safe for use
// from a single goroutine. No I/O, no side effects.
type Formatter struct {
	verbose    bool
	maxNameLen int
	nameStyle  lipgloss.Style // cached to avoid per-call allocation
}

// NewFormatter returns a Formatter.
// maxNameLen controls the display-column width for repo names (use ComputeMaxNameLen).
// When verbose is true, branch names are included in updated/rebased lines.
func NewFormatter(verbose bool, maxNameLen int) *Formatter {
	if maxNameLen < 1 {
		maxNameLen = 24
	}
	return &Formatter{
		verbose:    verbose,
		maxNameLen: maxNameLen,
		nameStyle:  lipgloss.NewStyle().Width(maxNameLen).MaxWidth(maxNameLen),
	}
}

// Format returns the single-line display string for a repo result.
func (f *Formatter) Format(r sync.RepoResult) string {
	name := r.DisplayName
	if name == "" {
		name = filepath.Base(r.RepoPath)
	}
	// Use the cached lipgloss style for display-width-aware padding — consistent with progress.go.
	namePad := f.nameStyle.Render(name)

	elapsed := ""
	if r.ElapsedMs > 0 {
		elapsed = fmt.Sprintf(", %.1fs", float64(r.ElapsedMs)/1000)
	}
	branch := ""
	if f.verbose && r.CurrentBranch != "" {
		branch = fmt.Sprintf(" [%s]", r.CurrentBranch)
	}

	check  := styleGreen.Render("✓")
	warn   := styleYellow.Render("⚠")
	cross  := styleRed.Render("✗")
	skip   := styleYellow.Render("⊘")
	circle := styleBlue.Render("○")
	bullet := styleBlue.Render("•")

	switch {
	// WhatIf ActionSkip: real skip reason set alongside WhatIfAction — show both.
	case r.WhatIfAction != "" && r.Status == sync.StatusSkipped:
		return fmt.Sprintf("  %s %s (dry run — would skip: %s)", circle, namePad, r.SkipReason)

	// WhatIf non-skip (fast-forward, rebase, reset, no-op): show the action description.
	case r.WhatIfAction != "":
		return fmt.Sprintf("  %s %s (dry run: %s)", circle, namePad, r.WhatIfAction)

	case r.Status == sync.StatusUpdated:
		return fmt.Sprintf("  %s %s (updated %s%s%s)", check, namePad, r.ParentBranch, elapsed, branch)

	case r.Status == sync.StatusReset:
		return fmt.Sprintf("  %s %s (reset --hard to %s%s%s)", check, namePad, r.ParentBranch, elapsed, branch)

	case r.Status == sync.StatusRebased && r.ForceRebase:
		return fmt.Sprintf("  %s %s (rebased — force-push needed: git push --force-with-lease origin %s)",
			warn, namePad, r.CurrentBranch)

	case r.Status == sync.StatusRebased:
		return fmt.Sprintf("  %s %s (rebased onto %s%s%s)", check, namePad, r.ParentBranch, elapsed, branch)

	case r.Status == sync.StatusNoOp:
		return fmt.Sprintf("  %s %s (up to date)", bullet, namePad)

	case r.Status == sync.StatusSkipped:
		return fmt.Sprintf("  %s %s (%s)", skip, namePad, r.SkipReason)

	case r.Status == sync.StatusStashConflict:
		return fmt.Sprintf("  %s %s (stash pop conflict — run: git stash pop)", skip, namePad)

	case r.Status == sync.StatusRebaseConflict:
		return fmt.Sprintf("  %s %s (rebase conflict, rolled back)", cross, namePad)

	case r.Status == sync.StatusFailed:
		return fmt.Sprintf("  %s %s (failed: %s)", cross, namePad, r.FailReason)

	case r.Status == sync.StatusManualInterventionRequired:
		return fmt.Sprintf("  %s %s (manual intervention needed: %s)", cross, namePad, r.FailReason)

	default:
		return fmt.Sprintf("  ? %s (unknown status %d)", namePad, r.Status)
	}
}

// ComputeMaxNameLen returns the display-column width for the name column —
// the widest display name measured by go-runewidth (via lipgloss.Width),
// clamped to [minWidth, maxWidth].
func ComputeMaxNameLen(results []sync.RepoResult, minWidth, maxWidth int) int {
	n := minWidth
	for _, r := range results {
		name := r.DisplayName
		if name == "" {
			name = filepath.Base(r.RepoPath)
		}
		if w := lipgloss.Width(name); w > n {
			n = w
		}
	}
	if n > maxWidth {
		return maxWidth
	}
	return n
}
