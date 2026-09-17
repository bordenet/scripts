package discover

import (
	"bufio"
	"bytes"
	"os"
	"path/filepath"
	"strings"
)

// Find returns canonical absolute paths of all git repos under targetDir.
// Recursively searches all subdirectories.
// Follows symlinks and deduplicates by canonical path.
// Respects .fetchignore in targetDir.
func Find(targetDir string) []string {
	resolved, err := filepath.EvalSymlinks(targetDir)
	if err != nil {
		resolved = targetDir
	}
	targetDir = resolved

	ignore := loadFetchIgnore(targetDir)

	seen := map[string]bool{}
	var results []string

	// If targetDir itself is a git repo (the user pointed gitsync directly at a
	// single repo rather than a parent directory), handle it explicitly up
	// front rather than relying on generic child-walking. This must happen
	// BEFORE walk(targetDir) below: walk() only inspects targetDir's CHILDREN,
	// so a ".worktrees" subdirectory would be discovered as if it were the
	// only repo present and targetDir's own main checkout would never be
	// added -- results would be non-empty (from the worktree) even though the
	// primary repo itself was silently dropped.
	if !ignore[targetDir] && isGitRepo(filepath.Join(targetDir, ".git")) {
		seen[targetDir] = true
		results = append(results, targetDir)
		walkWorktreesDir(targetDir, ignore, seen, &results)
		return results
	}

	var walk func(dir string)
	walk = func(dir string) {
		entries, err := os.ReadDir(dir)
		if err != nil {
			return
		}
		for _, e := range entries {
			name := e.Name()
			// Dot-directories are skipped by default (.git, .github, .vscode, ...)
			// EXCEPT ".worktrees", the standard convention (see git-worktrees
			// workflow rules) for housing `git worktree add .worktrees/<branch>`
			// checkouts alongside a repo's main checkout. Without this carve-out,
			// every worktree branch is invisible to discovery and never synced.
			if strings.HasPrefix(name, ".") && name != ".worktrees" {
				continue
			}
			fullPath := filepath.Join(dir, name)

			// Resolve symlinks to canonical path
			canonical, err := filepath.EvalSymlinks(fullPath)
			if err != nil {
				continue
			}

			// Check if this is a git repo (.git as dir or file)
			gitPath := filepath.Join(canonical, ".git")
			if isGitRepo(gitPath) {
				if seen[canonical] {
					continue
				}
				seen[canonical] = true
				if ignore[canonical] {
					continue
				}
				if hasRemote(gitPath) {
					// Leaf repo with a remote — add it for syncing. Don't recurse
					// into the rest of the working tree (tracked files aren't
					// nested repos), but DO check for a ".worktrees" directory:
					// per the git-worktrees convention, additional branch
					// checkouts live there as siblings of the main checkout and
					// each is its own independently-syncable repo.
					results = append(results, canonical)
					walkWorktreesDir(canonical, ignore, seen, &results)
					continue
				}
				// No remote: treat as an organisational container (e.g. a top-level
				// directory that was `git init`-ed but never pushed anywhere).
				walk(canonical)
				continue
			}

			// Recurse into directories (avoid re-visiting same dir via symlinks)
			info, err := os.Stat(canonical)
			if err != nil || !info.IsDir() {
				continue
			}
			if seen[canonical] {
				continue
			}
			seen[canonical] = true
			walk(canonical)
		}
	}

	walk(targetDir)

	return results
}

// walkWorktreesDir scans repoPath/.worktrees (the git-worktrees convention:
// `git worktree add .worktrees/<branch> -b <branch>`) for additional worktree
// checkouts and appends any it finds to *results. Each worktree checkout has
// its own ".git" FILE (not directory) pointing back at the main repo's
// .git/worktrees/<name> -- it is a fully independent, syncable working copy
// with its own branch and HEAD, so it must be discovered like any other repo.
//
// This does its own bounded recursive walk (branches can be nested, e.g.
// .worktrees/feat/foo) rather than reusing the outer walk closure, since a
// worktree's OWN ".worktrees" subdirectory (nested worktrees-of-worktrees) is
// intentionally not supported -- recursion here stops at the first worktree
// checkout found, mirroring how the outer walk stops recursing into a leaf
// repo's tracked files.
func walkWorktreesDir(repoPath string, ignore, seen map[string]bool, results *[]string) {
	root := filepath.Join(repoPath, ".worktrees")
	info, err := os.Stat(root)
	if err != nil || !info.IsDir() {
		return
	}

	var walk func(dir string)
	walk = func(dir string) {
		entries, err := os.ReadDir(dir)
		if err != nil {
			return
		}
		for _, e := range entries {
			fullPath := filepath.Join(dir, e.Name())
			canonical, err := filepath.EvalSymlinks(fullPath)
			if err != nil {
				continue
			}
			if seen[canonical] {
				continue
			}

			if isGitRepo(filepath.Join(canonical, ".git")) {
				seen[canonical] = true
				if !ignore[canonical] {
					*results = append(*results, canonical)
				}
				continue // worktree checkouts are leaves; don't recurse into tracked files
			}

			info, err := os.Stat(canonical)
			if err != nil || !info.IsDir() {
				continue
			}
			seen[canonical] = true
			walk(canonical) // intermediate path component, e.g. .worktrees/feat/
		}
	}
	walk(root)
}

// isGitRepo returns true if gitPath (.git) exists as either a directory or a regular file.
func isGitRepo(gitPath string) bool {
	info, err := os.Stat(gitPath)
	return err == nil && (info.IsDir() || info.Mode().IsRegular())
}

// hasRemote returns true if the git directory contains at least one configured remote.
// It reads the git config file directly to avoid spawning a subprocess.
func hasRemote(gitPath string) bool {
	realGitDir := resolveGitDir(gitPath)
	if realGitDir == "" {
		return false
	}
	// Remotes live in the config of the COMMON git dir. For a normal repo,
	// realGitDir IS the common dir. For a worktree, realGitDir is the
	// per-worktree dir (.git/worktrees/<name>) which has no [remote] entries
	// of its own -- its "commondir" file points back to the shared config.
	configDir := realGitDir
	if commondir, err := os.ReadFile(filepath.Join(realGitDir, "commondir")); err == nil {
		rel := strings.TrimSpace(string(commondir))
		if rel != "" {
			if filepath.IsAbs(rel) {
				configDir = rel
			} else {
				configDir = filepath.Join(realGitDir, rel)
			}
		}
	}
	data, err := os.ReadFile(filepath.Join(configDir, "config"))
	if err != nil {
		return false
	}
	return bytes.Contains(data, []byte("[remote "))
}

// resolveGitDir returns the real git directory for gitPath (the ".git" entry
// in a repo's working tree). If gitPath is a directory, it IS the git dir. If
// it's a file (worktree or submodule pointer, "gitdir: <path>"), the pointer
// is followed and resolved relative to gitPath's parent directory. Returns ""
// on any I/O or format error -- callers treat that as "no remote configured"
// (fail-open toward re-walking, never toward silently dropping a real repo).
func resolveGitDir(gitPath string) string {
	info, err := os.Stat(gitPath)
	if err != nil {
		return ""
	}
	if info.IsDir() {
		return gitPath
	}
	if !info.Mode().IsRegular() {
		return ""
	}
	data, err := os.ReadFile(gitPath)
	if err != nil {
		return ""
	}
	const prefix = "gitdir:"
	line := strings.TrimSpace(string(data))
	if !strings.HasPrefix(line, prefix) {
		return ""
	}
	target := strings.TrimSpace(strings.TrimPrefix(line, prefix))
	if target == "" {
		return ""
	}
	if !filepath.IsAbs(target) {
		target = filepath.Join(filepath.Dir(gitPath), target)
	}
	return target
}

// loadFetchIgnore reads .fetchignore from dir and returns a set of canonical paths to skip.
func loadFetchIgnore(dir string) map[string]bool {
	result := map[string]bool{}
	f, err := os.Open(filepath.Join(dir, ".fetchignore"))
	if err != nil {
		return result
	}
	defer f.Close()
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		target := filepath.Join(dir, line)
		canonical, err := filepath.EvalSymlinks(target)
		if err != nil {
			canonical = target // best effort if path doesn't exist yet
		}
		result[canonical] = true
	}
	return result
}
