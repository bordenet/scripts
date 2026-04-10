package branch_test

import (
	"fmt"
	"testing"

	"gitsync/internal/branch"
	"gitsync/internal/sync"
)

func TestClassify(t *testing.T) {
	tests := []struct {
		current  string
		dflt     string
		expected sync.BranchType
	}{
		{"main", "main", sync.BranchTypeDefault},
		{"master", "master", sync.BranchTypeDefault},
		{"release/1.0", "main", sync.BranchTypeAmbiguous},
		{"hotfix/urgent", "main", sync.BranchTypeAmbiguous},
		{"staging", "main", sync.BranchTypeAmbiguous},
		{"develop", "main", sync.BranchTypeAmbiguous},
		{"development", "main", sync.BranchTypeAmbiguous},
		{"feature/my-thing", "main", sync.BranchTypeFeature},
		{"fix/bug-123", "main", sync.BranchTypeFeature},
		{"my-branch", "main", sync.BranchTypeFeature},
		{"", "main", sync.BranchTypeFeature}, // empty treated as feature; detached caught earlier
	}
	for _, tt := range tests {
		t.Run(tt.current+"_vs_"+tt.dflt, func(t *testing.T) {
			got := branch.Classify(tt.current, tt.dflt)
			if got != tt.expected {
				t.Errorf("Classify(%q, %q) = %v, want %v", tt.current, tt.dflt, got, tt.expected)
			}
		})
	}
}

func TestDetectParent(t *testing.T) {
	tests := []struct {
		name          string
		commitsBehind map[string]int
		expected      string
	}{
		{
			name:          "main exists with 2 behind",
			commitsBehind: map[string]int{"main": 2},
			expected:      "main",
		},
		{
			name:          "master closer than main",
			commitsBehind: map[string]int{"main": 10, "master": 2},
			expected:      "master",
		},
		{
			name:          "all missing, fallback to main",
			commitsBehind: map[string]int{},
			expected:      "main",
		},
		{
			name:          "dev is closest",
			commitsBehind: map[string]int{"main": 5, "dev": 1},
			expected:      "dev",
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := branch.DetectParent(tt.commitsBehind)
			if got != tt.expected {
				t.Errorf("DetectParent(%v) = %q, want %q", tt.commitsBehind, got, tt.expected)
			}
		})
	}
}

// ensure fmt is used (used in original plan template)
var _ = fmt.Sprintf
