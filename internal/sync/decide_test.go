package sync_test

import (
	"errors"
	"testing"

	syncp "gitsync/internal/sync"
)

// sha values used in tests — just need to be distinct
const (
	shaA = "aaaa"
	shaB = "bbbb"
	shaC = "cccc"
)

func defaultFlags() syncp.Flags {
	return syncp.Flags{FetchTimeout: 30, RebaseTimeout: 120, Concurrency: 8}
}

func TestDecide_AllScenarios(t *testing.T) {
	tests := []struct {
		name           string
		state          syncp.RepoState
		flags          syncp.Flags
		wantAction     syncp.ActionType
		wantSkipReason syncp.SkipReason
	}{
		{
			name:           "1_empty_repo",
			state:          syncp.RepoState{IsEmpty: true},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipEmptyRepo,
		},
		{
			name:           "2_no_remote",
			state:          syncp.RepoState{HasOrigin: false},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipNoRemote,
		},
		{
			name:           "3_detached_head",
			state:          syncp.RepoState{HasOrigin: true, CurrentBranch: ""},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipDetachedHEAD,
		},
		{
			name:           "4_conflict_in_progress",
			state:          syncp.RepoState{HasOrigin: true, CurrentBranch: "main", HasUnmerged: true},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipUnresolvedConflict,
		},
		{
			name:           "5_rebase_in_progress",
			state:          syncp.RepoState{HasOrigin: true, CurrentBranch: "main", HasRebaseHead: true},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipRebaseInProgress,
		},
		{
			name: "6_up_to_date",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA:   shaA, RemoteSHA: shaA, BaseSHA: shaA,
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionNoOp,
		},
		{
			name: "7_ff_available",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA:   shaA, RemoteSHA: shaB, BaseSHA: shaA, // local==base → ff available
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionFastForward,
		},
		{
			name: "8_local_ahead",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA:   shaB, RemoteSHA: shaA, BaseSHA: shaA, // remote==base → local ahead
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionNoOp,
		},
		{
			name: "9_diverged_no_rebase",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType:   syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA:     shaB, RemoteSHA: shaC, BaseSHA: shaA, // all different → diverged
			},
			flags:          syncp.Flags{NoRebase: true, FetchTimeout: 30, RebaseTimeout: 120},
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipDivergedNoRebase,
		},
		{
			name: "10_diverged_rebase_not_pushed",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType:   syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA:     shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsPushed:     false,
			},
			flags:      defaultFlags(),
			wantAction: syncp.ActionRebase,
		},
		{
			name: "11_diverged_pushed_no_force",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType:   syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA:     shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsPushed:     true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipPushedNeedForce,
		},
		{
			name: "12_diverged_force_rebase",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType:   syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA:     shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsPushed:     true,
			},
			flags:      syncp.Flags{ForceRebase: true, FetchTimeout: 30, RebaseTimeout: 120},
			wantAction: syncp.ActionRebase,
		},
		{
			name: "13_shallow_diverged",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType:   syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA:     shaB, RemoteSHA: shaC, BaseSHA: shaA,
				IsShallow:    true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipShallowClone,
		},
		{
			name: "14_submodules_diverged",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "feature/x", DefaultBranch: "main",
				BranchType:    syncp.BranchTypeFeature, ParentBranch: "main",
				LocalSHA:      shaB, RemoteSHA: shaC, BaseSHA: shaA,
				HasSubmodules: true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipHasSubmodules,
		},
		{
			name: "15_fetch_timeout",
			state: syncp.RepoState{
				HasOrigin:    true,
				CurrentBranch: "main",
				FetchTimeout: true,
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipFetchTimeout,
		},
		{
			name: "16_diverged_default_branch",
			state: syncp.RepoState{
				HasOrigin: true, CurrentBranch: "main", DefaultBranch: "main",
				BranchType: syncp.BranchTypeDefault,
				LocalSHA:   shaB, RemoteSHA: shaC, BaseSHA: shaA, // diverged
			},
			flags:          defaultFlags(),
			wantAction:     syncp.ActionSkip,
			wantSkipReason: syncp.SkipDefaultDiverged,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			action := syncp.Decide(tt.state, tt.flags)
			if action.Type != tt.wantAction {
				t.Errorf("Decide() action = %v, want %v", action.Type, tt.wantAction)
			}
			if tt.wantSkipReason != "" && action.SkipReason != tt.wantSkipReason {
				t.Errorf("Decide() skipReason = %q, want %q", action.SkipReason, tt.wantSkipReason)
			}
			// Verify RequiresCleanWorktree truth table
			switch action.Type {
			case syncp.ActionFastForward, syncp.ActionRebase:
				if !action.RequiresCleanWorktree {
					t.Error("FF and Rebase actions must have RequiresCleanWorktree=true")
				}
			case syncp.ActionNoOp, syncp.ActionSkip, syncp.ActionFail:
				if action.RequiresCleanWorktree {
					t.Error("NoOp/Skip/Fail actions must have RequiresCleanWorktree=false")
				}
			}
		})
	}
}

// TestDecide_FetchError verifies FetchErr → ActionFail
func TestDecide_FetchError(t *testing.T) {
	state := syncp.RepoState{
		HasOrigin:     true,
		CurrentBranch: "main",
		FetchErr:      errors.New("connection refused"),
	}
	action := syncp.Decide(state, defaultFlags())
	if action.Type != syncp.ActionFail {
		t.Errorf("expected ActionFail for FetchErr, got %v", action.Type)
	}
}
