package branch

import (
	"math"
	"strings"

	"gitsync/internal/sync"
)

// ParentCandidates is the fixed ordered list of candidate parent branch names.
var ParentCandidates = []string{"main", "master", "dev", "develop", "staging"}

// Classify returns the BranchType for current relative to the repo's default branch.
// Guard order: default → ambiguous → feature.
func Classify(current, defaultBranch string) sync.BranchType {
	if current == defaultBranch {
		return sync.BranchTypeDefault
	}
	switch {
	case strings.HasPrefix(current, "release/"),
		strings.HasPrefix(current, "hotfix/"),
		current == "staging",
		current == "develop",
		current == "development":
		return sync.BranchTypeAmbiguous
	}
	return sync.BranchTypeFeature
}

// DetectParent returns the parent branch name by finding the candidate with the
// fewest commits behind HEAD (i.e., the closest merge base).
// commitsBehind maps candidate name → number of commits HEAD is behind that candidate.
// Only candidates that exist as remote tracking refs should be in the map.
// Returns "main" as fallback if the map is empty.
func DetectParent(commitsBehind map[string]int) string {
	if len(commitsBehind) == 0 {
		return "main"
	}
	best := ""
	bestCount := math.MaxInt
	// Iterate in ParentCandidates order for deterministic tiebreaking
	for _, candidate := range ParentCandidates {
		count, ok := commitsBehind[candidate]
		if !ok {
			continue
		}
		if count < bestCount {
			bestCount = count
			best = candidate
		}
	}
	if best == "" {
		return "main"
	}
	return best
}
