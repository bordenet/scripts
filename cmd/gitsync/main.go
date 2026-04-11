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

	// Scan all target directories, deduplicating by canonical path.
	seen := map[string]bool{}
	var repos []string
	for _, root := range targetDirs {
		for _, r := range discover.Find(root, flags.Recursive) {
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

	// If not --all and no positional arg (interactive), show menu
	if !flags.All && len(repos) > 1 {
		repos = showMenu(repos)
		if len(repos) == 0 {
			os.Exit(0)
		}
	}

	// Root context with cancellation
	rootCtx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	registry := &gosync.StashRegistry{}
	results := make(chan gosync.RepoResult, int(math.Max(float64(len(repos)), 1)))
	tick := make(chan struct{}, 1)
	sem := make(chan struct{}, flags.Concurrency)

	// Launch goroutines
	for _, repo := range repos {
		go func(repoPath string) {
			// Context-aware semaphore: don't block forever if cancelled.
			select {
			case sem <- struct{}{}:
			case <-rootCtx.Done():
				results <- gosync.RepoResult{
					RepoPath:   repoPath,
					Status:     gosync.StatusSkipped,
					SkipReason: gosync.SkipCancelled,
				}
				return
			}
			defer func() { <-sem }()
			results <- gosync.Run(rootCtx, repoPath, flags, registry)
		}(repo)
	}

	// Ticker goroutine
	go func() {
		ticker := time.NewTicker(250 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				select {
				case tick <- struct{}{}:
				default:
				}
			case <-rootCtx.Done():
				return
			}
		}
	}()

	// Print header
	fmt.Printf("\033[1mGit Repository Updates\033[0m: %s\n\n", strings.Join(targetDirs, ", "))

	formatter := output.NewFormatter(flags.Verbose)
	writer := output.NewProgressWriter(os.Stdout, len(repos))
	start := time.Now()
	completed := 0
	var allResults []gosync.RepoResult

loop:
	for {
		select {
		case r := <-results:
			allResults = append(allResults, r)
			writer.PrintResult(formatter.Format(r))
			completed++
			writer.UpdateProgress(completed, len(repos), time.Since(start))
			if completed == len(repos) {
				break loop
			}
		case <-tick:
			writer.UpdateProgress(completed, len(repos), time.Since(start))
		case sig := <-sigChan:
			cancel()
			fmt.Fprintln(os.Stdout, "\nInterrupted — waiting for in-flight repos to clean up...")
			drainCtx, drainCancel := context.WithTimeout(context.Background(), 10*time.Second)
			for completed < len(repos) {
				select {
				case r := <-results:
					allResults = append(allResults, r)
					writer.PrintResult(formatter.Format(r))
					completed++
				case <-drainCtx.Done():
					drainCancel()
					goto afterLoop
				}
			}
			drainCancel()
		afterLoop:
			// Attempt safe stash pop for each orphaned stash.
			// Use a bounded timeout so a hung git command can't freeze the process indefinitely.
			cleanupCtx, cleanupCancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cleanupCancel()
			for _, entry := range registry.List() {
				top := gosync.TopStashMessage(cleanupCtx, entry.RepoPath)
				if top == entry.StashMessage {
					if err := gosync.PopStash(cleanupCtx, entry.RepoPath); err != nil {
						fmt.Printf("⚠ Stash pop failed in %s — run: git stash pop\n",
							filepath.Base(entry.RepoPath))
					} else {
						registry.Remove(entry.RepoPath)
					}
				} else {
					fmt.Printf("⚠ Could not safely pop stash in %s — stash order changed; run: git stash list\n",
						filepath.Base(entry.RepoPath))
				}
			}
			exitCode := 130 // SIGINT
			if sig == syscall.SIGTERM {
				exitCode = 143 // SIGTERM (128+15)
			}
			os.Exit(exitCode)
		}
	}

	output.ShowSummary(allResults, time.Since(start), flags)
}

func parseFlags() (gosync.Flags, []string) {
	var (
		all           = flag.Bool("all", false, "process all repos non-interactively")
		recursive     = flag.Bool("recursive", false, "search all subdirectories")
		verbose       = flag.Bool("verbose", false, "show per-repo detail")
		whatIf        = flag.Bool("what-if", false, "dry run")
		noRebase      = flag.Bool("no-rebase", false, "skip diverged branches instead of rebasing")
		noStash       = flag.Bool("no-stash", false, "skip repos with local changes")
		forceRebase   = flag.Bool("force-rebase", false, "rebase pushed branches (solo only)")
		_merge        = flag.Bool("merge", false, "no-op alias for backwards compatibility")
		concurrency   = flag.Int("concurrency", int(math.Min(float64(runtime.NumCPU()), 8)), "max parallel repos")
		fetchTimeout  = flag.Int("fetch-timeout", 30, "per-repo fetch timeout in seconds")
		rebaseTimeout = flag.Int("rebase-timeout", 120, "per-repo rebase timeout in seconds")
		dir           = flag.String("dir", ".", "target directory (default: current directory)")
	)
	flag.Parse()
	_ = _merge // --merge is a no-op alias

	// Positional args are additional root directories; any positional arg implies --all.
	var targetDirs []string
	if flag.NArg() > 0 {
		*all = true
		for _, arg := range flag.Args() {
			abs, err := filepath.Abs(arg)
			if err != nil {
				abs = arg
			}
			targetDirs = append(targetDirs, abs)
		}
	} else {
		abs, err := filepath.Abs(*dir)
		if err != nil {
			abs = *dir
		}
		targetDirs = []string{abs}
	}

	f := gosync.Flags{
		All:           *all,
		Recursive:     *recursive,
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
