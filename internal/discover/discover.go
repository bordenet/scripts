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

	var walk func(dir string)
	walk = func(dir string) {
		entries, err := os.ReadDir(dir)
		if err != nil {
			return
		}
		for _, e := range entries {
			name := e.Name()
			if strings.HasPrefix(name, ".") {
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
					// Leaf repo with a remote — add it for syncing; don't recurse.
					results = append(results, canonical)
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

	// Fallback: if no child repos were found, check whether targetDir itself is a
	// git repo. This handles the case where the user points gitsync directly at a
	// single repo rather than a parent directory.
	//
	// Self-exclusion is intentionally NOT applied here — when the user explicitly
	// targets the source directory (e.g. running from inside the scripts repo),
	// they want to sync it, not get an empty result.
	if len(results) == 0 && !ignore[targetDir] && isGitRepo(filepath.Join(targetDir, ".git")) {
		return []string{targetDir}
	}

	return results
}

// isGitRepo returns true if gitPath (.git) exists as either a directory or a regular file.
func isGitRepo(gitPath string) bool {
	info, err := os.Stat(gitPath)
	return err == nil && (info.IsDir() || info.Mode().IsRegular())
}

// hasRemote returns true if the git directory contains at least one configured remote.
// It reads the git config file directly to avoid spawning a subprocess.
func hasRemote(gitPath string) bool {
	// gitPath is the .git entry; config lives inside it when it's a directory,
	// or inside the path referenced by the .git file when it's a worktree pointer.
	configPath := filepath.Join(gitPath, "config")
	data, err := os.ReadFile(configPath)
	if err != nil {
		return false
	}
	return bytes.Contains(data, []byte("[remote "))
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
