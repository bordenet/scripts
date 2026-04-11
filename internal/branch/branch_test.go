package branch_test

import (
	"fmt"
	"testing"

	"gitsync/internal/branch"
	"gitsync/internal/types"
)

func TestClassify(t *testing.T) {
	tests := []struct {
		current  string
		dflt     string
		expected types.BranchType
	}{
		{"main", "main", types.BranchTypeDefault},
		{"master", "master", types.BranchTypeDefault},
		{"release/1.0", "main", types.BranchTypeAmbiguous},
		{"hotfix/urgent", "main", types.BranchTypeAmbiguous},
		{"staging", "main", types.BranchTypeAmbiguous},
		{"develop", "main", types.BranchTypeAmbiguous},
		{"development", "main", types.BranchTypeAmbiguous},
		{"feature/my-thing", "main", types.BranchTypeFeature},
		{"fix/bug-123", "main", types.BranchTypeFeature},
		{"my-branch", "main", types.BranchTypeFeature},
		{"", "main", types.BranchTypeFeature}, // empty treated as feature; detached caught earlier
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
