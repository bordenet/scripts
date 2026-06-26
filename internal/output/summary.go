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

	// printInline renders a single line: "<icon> <n> <label>: name1, name2, ..."
	// Used in compact mode so all outcomes stay on one line each with no bullet lists.
	printInline := func(style lipgloss.Style, icon, label string, group []sync.RepoResult) {
		if len(group) == 0 {
			return
		}
		names := make([]string, len(group))
		for i, r := range group {
			names[i] = displayName(r)
		}
		fmt.Fprintf(w, "%s %d %s: %s\n", style.Render(icon), len(group), label, strings.Join(names, ", "))
	}

	if flags.WhatIf {
		printGroup(styleBlue, "○", "Would update", updated)
		printGroup(styleBlue, "○", "Would rebase", rebased)
		printGroup(styleBlue, "○", "Would reset --hard", reset)
		printGroup(styleBlue, "•", "Up to date", noops)
		printGroup(styleYellow, "⊘", "Would skip", skipped)
		printGroup(styleYellow, "⚠", "Stash conflicts", stashConflict)
		printGroup(styleRed, "✗", "Rebase conflicts", rebaseConflict)
		printGroup(styleRed, "✗", "Failed", failed)
		printGroup(styleRed, "✗", "Manual intervention needed", manual)
	} else if flags.Verbose {
		printGroup(styleGreen, "✓", "Updated", updated)
		printGroup(styleGreen, "✓", "Rebased", rebased)
		printGroup(styleGreen, "✓", "Reset (unrelated history)", reset)
		printGroup(styleBlue, "•", "Up to date", noops)
		printGroup(styleYellow, "⊘", "Skipped", skipped)
		printGroup(styleYellow, "⚠", "Stash conflicts", stashConflict)
		printGroup(styleRed, "✗", "Rebase conflicts", rebaseConflict)
		printGroup(styleRed, "✗", "Failed", failed)
		printGroup(styleRed, "✗", "Manual intervention needed", manual)
	} else {
		// Compact: one line for clean outcomes; every problem category also one line.
		var parts []string
		if len(noops) > 0 {
			parts = append(parts, fmt.Sprintf("%d already current", len(noops)))
		}
		n := len(updated) + len(rebased) + len(reset)
		if n > 0 {
			syncedAll := make([]sync.RepoResult, 0, n)
			syncedAll = append(syncedAll, updated...)
			syncedAll = append(syncedAll, rebased...)
			syncedAll = append(syncedAll, reset...)
			names := make([]string, n)
			for i, r := range syncedAll {
				names[i] = displayName(r)
			}
			parts = append(parts, fmt.Sprintf("%d synced: %s", n, strings.Join(names, ", ")))
		}
		if len(parts) > 0 {
			fmt.Fprintf(w, "%s %s\n", styleGreen.Render("✓"), strings.Join(parts, ", "))
		}
		printInline(styleYellow, "⊘", "skipped", skipped)
		printInline(styleYellow, "⚠", "stash conflict", stashConflict)
		printInline(styleRed, "✗", "rebase conflict", rebaseConflict)
		printInline(styleRed, "✗", "failed", failed)
		printInline(styleRed, "✗", "manual intervention needed", manual)
	}

	if len(forcePushNeeded) > 0 {
		printForcePushCommands(w, forcePushNeeded, displayName, flags.WhatIf)
	}

	// Stash conflicts require manual user action (resolve markers, git add, git stash drop), so
	// they count as issues that should produce a non-zero exit code.
	hasIssues := len(failed)+len(rebaseConflict)+len(manual)+len(stashConflict) > 0

	// A blank line before the verdict separates indented block content (verbose/WhatIf
	// bullet lists, force-push command blocks) from the conclusion icon.
	// Compact mode uses inline format with no indented content, so no separator is needed.
	needsSeparator := flags.Verbose || flags.WhatIf || len(forcePushNeeded) > 0
	if needsSeparator {
		fmt.Fprintln(w, "")
	}

	if hasIssues {
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
