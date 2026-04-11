package output

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"gitsync/internal/sync"
)

// ShowSummary prints the end-of-run summary to stdout.
func ShowSummary(results []sync.RepoResult, elapsed time.Duration, flags sync.Flags) bool {
	var updated, rebased, noops, skipped, failed, stashConflict, rebaseConflict, manual []sync.RepoResult
	var forcePushNeeded []sync.RepoResult

	for _, r := range results {
		switch r.Status {
		case sync.StatusUpdated:
			updated = append(updated, r)
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

	// Clear progress line
	fmt.Print("\r\033[2K")

	if flags.WhatIf {
		fmt.Println("\n\033[1mDRY RUN — no changes were made\033[0m")
	}

	fmt.Printf("\n\033[1mSummary\033[0m (%.0fs)\n", elapsed.Seconds())

	printGroup := func(color, icon, label string, group []sync.RepoResult) {
		if len(group) == 0 {
			return
		}
		fmt.Printf("%s%s %s (%d):%s\n", color, icon, label, len(group), colorReset)
		for _, r := range group {
			fmt.Printf("  • %s\n", filepath.Base(r.RepoPath))
		}
	}

	printGroup(colorGreen, "✓", "Updated", updated)
	printGroup(colorGreen, "✓", "Rebased", rebased)
	printGroup(colorBlue, "•", "Up to date", noops)
	printGroup(colorYellow, "⊘", "Skipped", skipped)
	printGroup(colorYellow, "⚠", "Stash conflicts", stashConflict)
	printGroup(colorRed, "✗", "Rebase conflicts", rebaseConflict)
	printGroup(colorRed, "✗", "Failed", failed)
	printGroup(colorRed, "✗", "Manual intervention needed", manual)

	if len(forcePushNeeded) > 0 {
		fmt.Printf("%s⚠ Force-push needed:%s\n", colorYellow, colorReset)
		for _, r := range forcePushNeeded {
			fmt.Printf("  git push --force-with-lease origin %s  # in %s\n",
				r.CurrentBranch, filepath.Base(r.RepoPath))
		}
		fmt.Printf("  %s⚠ Solo branches only — force-push overwrites shared branches%s\n",
			colorYellow, colorReset)
	}

	hasIssues := len(failed)+len(rebaseConflict)+len(manual) > 0
	if hasIssues {
		fmt.Printf("\n%s⚠%s Some repositories had issues. Review above.\n", colorYellow, colorReset)
		os.Exit(1)
	}
	fmt.Printf("\n%s✓%s All repositories processed successfully!\n", colorGreen, colorReset)
	return true
}
