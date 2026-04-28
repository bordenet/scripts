package output

import (
	"fmt"
	"io"
	"path/filepath"
	"strings"
	"time"

	"github.com/charmbracelet/lipgloss"

	"gitsync/internal/sync"
)

// ShowSummary prints the end-of-run summary to w and returns false when any
// repositories had unrecoverable issues (Failed, conflicts, manual intervention).
// The caller owns the exit-code decision; this function never calls os.Exit.
func ShowSummary(w io.Writer, results []sync.RepoResult, elapsed time.Duration, flags sync.Flags) bool {
	var updated, rebased, reset, noops, skipped, failed, stashConflict, rebaseConflict, manual []sync.RepoResult
	var forcePushNeeded []sync.RepoResult

	for _, r := range results {
		switch r.Status {
		case sync.StatusUpdated:
			updated = append(updated, r)
		case sync.StatusReset:
			reset = append(reset, r)
		case sync.StatusRebased:
			rebased = append(rebased, r)
			if r.ForceRebase {
				forcePushNeeded = append(forcePushNeeded, r)
			}
		case sync.StatusNoOp:
			noops = append(noops, r)
		case sync.StatusSkipped:
			skipped = append(skipped, r)
		case sync.StatusFailed:
			failed = append(failed, r)
		case sync.StatusStashConflict:
			stashConflict = append(stashConflict, r)
		case sync.StatusRebaseConflict:
			rebaseConflict = append(rebaseConflict, r)
		case sync.StatusManualInterventionRequired:
			manual = append(manual, r)
		}
	}

	if flags.WhatIf {
		fmt.Fprintln(w, styleYellow.Render("DRY RUN — no changes were made"))
	}
	fmt.Fprintf(w, "%s (%.0fs)\n", styleYellow.Render("Summary"), elapsed.Seconds())

	displayName := func(r sync.RepoResult) string {
		if r.DisplayName != "" {
			return r.DisplayName
		}
		return filepath.Base(r.RepoPath)
	}

	printGroup := func(style lipgloss.Style, icon, label string, group []sync.RepoResult) {
		if len(group) == 0 {
			return
		}
		fmt.Fprintf(w, "%s %s (%d):\n", style.Render(icon), label, len(group))
		for _, r := range group {
			fmt.Fprintf(w, "  • %s\n", displayName(r))
		}
	}

	if flags.WhatIf {
		printGroup(styleBlue, "○", "Would update", updated)
		printGroup(styleBlue, "○", "Would rebase", rebased)
		printGroup(styleBlue, "○", "Would reset --hard", reset)
		printGroup(styleBlue, "•", "Up to date", noops)
		printGroup(styleYellow, "⊘", "Would skip", skipped)
	} else if flags.Verbose {
		printGroup(styleGreen, "✓", "Updated", updated)
		printGroup(styleGreen, "✓", "Rebased", rebased)
		printGroup(styleGreen, "✓", "Reset (unrelated history)", reset)
		printGroup(styleBlue, "•", "Up to date", noops)
		printGroup(styleYellow, "⊘", "Skipped", skipped)
	} else {
		// Compact: one-liner for clean outcomes; problem repos listed by group below.
		var parts []string
		if n := len(updated) + len(rebased) + len(reset); n > 0 {
			parts = append(parts, fmt.Sprintf("%d synced", n))
		}
		if len(noops) > 0 {
			parts = append(parts, fmt.Sprintf("%d already current", len(noops)))
		}
		if len(parts) > 0 {
			fmt.Fprintf(w, "%s %s\n", styleGreen.Render("✓"), strings.Join(parts, ", "))
		}
		printGroup(styleYellow, "⊘", "Skipped", skipped)
	}

	printGroup(styleYellow, "⚠", "Stash conflicts", stashConflict)
	printGroup(styleRed, "✗", "Rebase conflicts", rebaseConflict)
	printGroup(styleRed, "✗", "Failed", failed)
	printGroup(styleRed, "✗", "Manual intervention needed", manual)

	if len(forcePushNeeded) > 0 {
		printForcePushCommands(w, forcePushNeeded, displayName, flags.WhatIf)
	}

	// Stash conflicts require manual user action (git stash pop + resolve), so
	// they count as issues that should produce a non-zero exit code.
	hasIssues := len(failed)+len(rebaseConflict)+len(manual)+len(stashConflict) > 0

	// Add a blank line before the verdict when per-repo group lines were printed
	// above it — verbose mode and any run with skipped/failed/conflict/force-push
	// repos all emit indented bullet lines whose visual level matches the verdict
	// icon, so the separator is needed to distinguish list content from conclusion.
	// In compact all-clean mode no groups fire, so no separator is added.
	needsSeparator := flags.Verbose ||
		len(skipped) > 0 || len(stashConflict) > 0 ||
		len(rebaseConflict) > 0 || len(failed) > 0 ||
		len(manual) > 0 || len(forcePushNeeded) > 0
	if needsSeparator {
		fmt.Fprintln(w, "")
	}

	if hasIssues {
		fmt.Fprintf(w, "%s Some repositories had issues. Review above.\n", styleYellow.Render("⚠"))
		return false
	}
	fmt.Fprintf(w, "%s All repositories processed successfully!\n", styleGreen.Render("✓"))
	return true
}

// printForcePushCommands renders the force-push advisory block.
// In WhatIf mode the header makes clear no changes have been applied yet.
func printForcePushCommands(w io.Writer, repos []sync.RepoResult, name func(sync.RepoResult) string, whatIf bool) {
	if whatIf {
		fmt.Fprintf(w, "%s\n", styleYellow.Render("⚠ Would need force-push after rebase (run without --what-if first):"))
	} else {
		fmt.Fprintf(w, "%s\n", styleYellow.Render("⚠ Force-push needed:"))
	}
	for _, r := range repos {
		fmt.Fprintf(w, "  git push --force-with-lease origin %s  # in %s\n", r.CurrentBranch, name(r))
	}
	if !whatIf {
		fmt.Fprintf(w, "  %s\n", styleYellow.Render("⚠ Solo branches only — force-push overwrites shared branches"))
	}
}
