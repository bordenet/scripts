package main

import (
	"context"
	"flag"
	"fmt"
	"math"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"

	"gitsync/internal/discover"
	"gitsync/internal/output"
	gosync "gitsync/internal/sync"
)

func main() {
	flags, targetDirs := parseFlags()
	if flags.Concurrency < 1 {
		fmt.Fprintln(os.Stderr, "error: --concurrency must be >= 1")
		os.Exit(1)
	}

	// Check if the shell wrapper already updated itself (GITSYNC_SELF_UPDATED).
	// Resolve to canonical path so we can match against discovered repos.
	selfUpdatedDir := ""
	selfUpdatedBranch := "main"
	if env := os.Getenv("GITSYNC_SELF_UPDATED"); env != "" {
		if abs, err := filepath.EvalSymlinks(env); err == nil {
			selfUpdatedDir = abs
		} else if abs, err := filepath.Abs(env); err == nil {
			selfUpdatedDir = abs
		}
		if b := os.Getenv("GITSYNC_SELF_UPDATED_BRANCH"); b != "" {
			selfUpdatedBranch = b
		}
	}

	// Scan all target directories, deduplicating by canonical path.
	seen := map[string]bool{}
	var repos []string
	for _, root := range targetDirs {
		for _, r := range discover.Find(root) {
			if !seen[r] {
				seen[r] = true
				repos = append(repos, r)
			}
		}
	}
	if len(repos) == 0 {
		fmt.Fprintf(os.Stderr, "No git repositories found in %s\n", strings.Join(targetDirs, ", "))
		os.Exit(0)
	}

	// Separate out the self-updated repo so it gets a synthetic "Updated" result
	// instead of a misleading "up to date".
	var selfUpdatedRepo string
	if selfUpdatedDir != "" {
		var filtered []string
		for _, r := range repos {
			canon := r
			if resolved, err := filepath.EvalSymlinks(r); err == nil {
				canon = resolved
			}
			if canon == selfUpdatedDir {
				selfUpdatedRepo = r
			} else {
				filtered = append(filtered, r)
			}
		}
		if selfUpdatedRepo != "" {
			repos = filtered
		}
	}

	// If not --all and no positional arg (interactive), show menu
	if !flags.All && len(repos) > 1 {
		repos = showMenu(repos)
		if len(repos) == 0 {
			os.Exit(0)
		}
	}

	// Build display names: path relative to the common ancestor of all scan roots.
	// Single root ~/GitHub → "Personal/superpowers-plus"
	// Multi-root ~/git + ~/GitHub → "git/Personal/superpowers-plus" vs "GitHub/Personal/superpowers-plus"
	displayRoot := commonAncestor(targetDirs)
	displayNames := make(map[string]string, len(repos))
	// Include self-updated repo in previewResults for maxNameLen calculation (non-interactive only).
	allReposForPreview := repos
	if selfUpdatedRepo != "" && flags.All {
		allReposForPreview = append([]string{selfUpdatedRepo}, repos...)
	}
	previewResults := make([]gosync.RepoResult, len(allReposForPreview))
	for i, repoPath := range allReposForPreview {
		rel, err := filepath.Rel(displayRoot, repoPath)
		if err != nil {
			rel = filepath.Base(repoPath)
		}
		displayNames[repoPath] = rel
		previewResults[i] = gosync.RepoResult{RepoPath: repoPath, DisplayName: rel}
	}
	maxNameLen := output.ComputeMaxNameLen(previewResults, 20, 48)

	totalRepos := len(repos)
	if selfUpdatedRepo != "" && flags.All {
		totalRepos++ // include self-updated repo in total count (non-interactive only)
	}

	// Root context with cancellation
	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	registry := &gosync.StashRegistry{}
	results := make(chan gosync.RepoResult, int(math.Max(float64(len(repos)), 1)))
	sem := make(chan struct{}, flags.Concurrency)

	// Launch goroutines
	for _, repo := range repos {
		go func(repoPath string) {
			// Context-aware semaphore: don't block forever if cancelled.
			select {
			case sem <- struct{}{}:
			case <-rootCtx.Done():
				results <- gosync.RepoResult{
					RepoPath:    repoPath,
					DisplayName: displayNames[repoPath],
					Status:      gosync.StatusSkipped,
					SkipReason:  gosync.SkipCancelled,
				}
				return
			}
			defer func() { <-sem }()
			r := gosync.Run(rootCtx, repoPath, flags, registry, gosync.DefaultSyncer{})
			r.DisplayName = displayNames[repoPath]
			results <- r
		}(repo)
	}

	// Print header
	fmt.Printf("%s: %s\n",
		lipgloss.NewStyle().Bold(true).Render("Git Repository Updates"),
		strings.Join(targetDirs, ", "))

	formatter := output.NewFormatter(flags.Verbose, maxNameLen)
	start := time.Now()
	var allResults []gosync.RepoResult // written by drain goroutine, read after p.Run()
	var interruptExitCode int          // non-zero on SIGINT/SIGTERM

	prog := tea.NewProgram(
		output.NewProgressModel(totalRepos, flags.Verbose),
		tea.WithOutput(os.Stdout),
		tea.WithInput(nil), // headless runner — disable keyboard to prevent accidental q/ctrl-c races
	)

	// Drain goroutine: collects results and drives the TUI via p.Send.
	// Writes to allResults and interruptExitCode before sending MsgDone,
	// establishing the happens-before boundary that makes the post-Run reads safe.
	go func() {
		send := func(r gosync.RepoResult) {
			formatted := ""
			if flags.Verbose || gosync.IsNoteworthyResult(r) {
				formatted = formatter.Format(r)
			}
			prog.Send(output.MsgResult{Result: r, Formatted: formatted})
		}

		// Inject synthetic result for the self-updated repo (shell already pulled it).
		// Synthetic results have no WhatIfAction; gate on flags.WhatIf explicitly.
		if selfUpdatedRepo != "" && flags.All {
			selfResult := gosync.RepoResult{
				RepoPath:      selfUpdatedRepo,
				DisplayName:   displayNames[selfUpdatedRepo],
				Status:        gosync.StatusUpdated,
				ParentBranch:  selfUpdatedBranch,
				CurrentBranch: selfUpdatedBranch,
			}
			allResults = append(allResults, selfResult)
			formatted := ""
			if flags.Verbose || flags.WhatIf || gosync.IsNoteworthyResult(selfResult) {
				formatted = formatter.Format(selfResult)
			}
			prog.Send(output.MsgResult{Result: selfResult, Formatted: formatted})
		}

		remaining := len(repos)
		for remaining > 0 {
			select {
			case r := <-results:
				allResults = append(allResults, r)
				send(r)
				remaining--
			case sig := <-sigChan:
				cancel()
				prog.Send(output.MsgPrint{Line: "\nInterrupted — waiting for in-flight repos to clean up..."})
				drainCtx, drainCancel := context.WithTimeout(context.Background(), 10*time.Second)
			drainLoop:
				for remaining > 0 {
					select {
					case r := <-results:
						allResults = append(allResults, r)
						send(r)
						remaining--
					case <-drainCtx.Done():
						break drainLoop
					}
				}
				drainCancel()
				// Safe stash pop for orphaned stashes.
				cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), 5*time.Second)
				for _, entry := range registry.List() {
					top := gosync.TopStashMessage(cleanupCtx, entry.RepoPath)
					if top == entry.StashMessage {
						if err := gosync.PopStash(cleanupCtx, entry.RepoPath); err != nil {
							prog.Send(output.MsgPrint{Line: fmt.Sprintf("⚠ Stash pop failed in %s — run: git stash pop",
								filepath.Base(entry.RepoPath))})
						} else {
							registry.Remove(entry.RepoPath)
						}
					} else {
						prog.Send(output.MsgPrint{Line: fmt.Sprintf("⚠ Could not safely pop stash in %s — run: git stash list",
							filepath.Base(entry.RepoPath))})
					}
				}
				cleanupCancel()
				interruptExitCode = 130 // SIGINT
				if sig == syscall.SIGTERM {
					interruptExitCode = 143 // SIGTERM (128+15)
				}
				prog.Send(output.MsgDone{})
				return
			}
		}
		prog.Send(output.MsgDone{})
	}()

	if _, err := prog.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	if interruptExitCode != 0 {
		output.ShowSummary(os.Stdout, allResults, time.Since(start), flags)
		os.Exit(interruptExitCode)
	}
	if !output.ShowSummary(os.Stdout, allResults, time.Since(start), flags) {
		os.Exit(1)
	}
}

func parseFlags() (gosync.Flags, []string) {
	var (
		interactive   = flag.Bool("interactive", false, "pick repos from a menu instead of syncing all")
		verbose       = flag.Bool("verbose", false, "show per-repo detail")
		whatIf        = flag.Bool("what-if", false, "dry run: show what would happen without changing anything")
		noRebase      = flag.Bool("no-rebase", false, "skip diverged branches instead of rebasing")
		noStash       = flag.Bool("no-stash", false, "skip repos with local changes instead of stashing")
		forceRebase   = flag.Bool("force-rebase", false, "rebase pushed branches (solo repos only)")
		concurrency   = flag.Int("concurrency", int(math.Min(float64(runtime.NumCPU()), 8)), "max parallel repos")
		fetchTimeout  = flag.Int("fetch-timeout", 30, "per-repo fetch timeout in seconds")
		rebaseTimeout = flag.Int("rebase-timeout", 120, "per-repo rebase timeout in seconds")
		// Deprecated/compat flags — accepted silently, have no effect.
		_ = flag.Bool("all", false, "")
		_ = flag.Bool("merge", false, "")
		_ = flag.String("dir", ".", "")
	)
	flag.Usage = func() {
		fmt.Fprintf(os.Stderr, "Usage: gitsync [flags] [DIR...]\n\n")
		fmt.Fprintf(os.Stderr, "Syncs all git repos found under DIR (default: current directory).\n")
		fmt.Fprintf(os.Stderr, "Multiple directories may be specified; results are deduplicated.\n\n")
		fmt.Fprintf(os.Stderr, "Flags:\n")
		flag.VisitAll(func(f *flag.Flag) {
			if f.Usage == "" {
				return // skip deprecated/compat flags
			}
			fmt.Fprintf(os.Stderr, "  --%-20s %s\n", f.Name, f.Usage)
		})
	}
	flag.Parse()

	// Positional args specify root directories to scan.
	var targetDirs []string
	if flag.NArg() > 0 {
		for _, arg := range flag.Args() {
			abs, err := filepath.Abs(arg)
			if err != nil {
				abs = arg
			}
			targetDirs = append(targetDirs, abs)
		}
	} else {
		abs, err := filepath.Abs(".")
		if err != nil {
			abs = "."
		}
		targetDirs = []string{abs}
	}

	f := gosync.Flags{
		All:           !*interactive, // sync-all is the default; --interactive opts out
		Verbose:       *verbose,
		WhatIf:        *whatIf,
		NoRebase:      *noRebase,
		NoStash:       *noStash,
		ForceRebase:   *forceRebase,
		Concurrency:   *concurrency,
		FetchTimeout:  *fetchTimeout,
		RebaseTimeout: *rebaseTimeout,
	}
	return f, targetDirs
}

func showMenu(repos []string) []string {
	fmt.Println("Select a repository to update:")
	for i, r := range repos {
		fmt.Printf("  %3d) %s\n", i+1, filepath.Base(r))
	}
	fmt.Println()
	var choice string
	fmt.Print("Enter number (or 'all'): ")
	fmt.Scanln(&choice)
	fmt.Println()

	if choice == "all" {
		return repos
	}
	var n int
	if _, err := fmt.Sscanf(choice, "%d", &n); err != nil || n < 1 || n > len(repos) {
		fmt.Fprintln(os.Stderr, "Invalid selection.")
		return nil
	}
	return repos[n-1 : n]
}

// commonAncestor returns the longest common directory prefix of dirs.
// For ["/Users/matt/git", "/Users/matt/GitHub"] → "/Users/matt"
// For ["/Users/matt/GitHub"] → "/Users/matt/GitHub"
func commonAncestor(dirs []string) string {
	if len(dirs) == 0 {
		return "."
	}
	if len(dirs) == 1 {
		return dirs[0]
	}
	split := func(d string) []string {
		return strings.Split(filepath.Clean(d), string(filepath.Separator))
	}
	parts := split(dirs[0])
	for _, d := range dirs[1:] {
		dp := split(d)
		common := 0
		for common < len(parts) && common < len(dp) && parts[common] == dp[common] {
			common++
		}
		parts = parts[:common]
	}
	if len(parts) == 0 {
		return string(filepath.Separator)
	}
	result := strings.Join(parts, string(filepath.Separator))
	if result == "" {
		return string(filepath.Separator)
	}
	return result
}
