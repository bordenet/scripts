package discover

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

// Find returns canonical absolute paths of all git repos under targetDir.
// If recursive is false, searches up to 2 levels deep.
// Follows symlinks and deduplicates by canonical path.
// Respects .fetchignore in targetDir and GITSYNC_SOURCE_DIR self-exclusion.
func Find(targetDir string, recursive bool) []string {
	resolved, err := filepath.EvalSymlinks(targetDir)
	if err != nil {
		resolved = targetDir
	}
	targetDir = resolved

	ignore := loadFetchIgnore(targetDir)

	// Self-exclusion: skip the gitsync source repo
	selfDir := ""
	if s := os.Getenv("GITSYNC_SOURCE_DIR"); s != "" {
		if canon, err := filepath.EvalSymlinks(s); err == nil {
			selfDir = canon
		} else {
			selfDir = s
		}
	}

	seen := map[string]bool{}
	var results []string

	// If targetDir is itself a git repo, return it directly without descending.
	if isGitRepo(filepath.Join(targetDir, ".git")) {
		if !ignore[targetDir] && (selfDir == "" || targetDir != selfDir) {
			return []string{targetDir}
		}
		return []string{}
	}

	var walk func(dir string, depth int)
	walk = func(dir string, depth int) {
		if !recursive && depth > 2 {
			return
		}
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
				if ignore[canonical] {
					continue
				}
				if selfDir != "" && canonical == selfDir {
					continue
				}
				seen[canonical] = true
				results = append(results, canonical)
				continue // don't recurse into git repos
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
			walk(canonical, depth+1)
		}
	}

	walk(targetDir, 1)
	return results
}

// isGitRepo returns true if gitPath (.git) exists as either a directory or a regular file.
func isGitRepo(gitPath string) bool {
	info, err := os.Stat(gitPath)
	return err == nil && (info.IsDir() || info.Mode().IsRegular())
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
