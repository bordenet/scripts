package sync

import (
	"sort"
	gosync "sync"

	inttypes "gitsync/internal/types"
)

// Status represents the outcome of processing a single repo.
type Status int

const (
	StatusUpdated              Status = iota // fast-forward succeeded
	StatusRebased                            // rebase succeeded
	StatusNoOp                               // already up to date or local ahead
	StatusSkipped                            // deliberate skip (see SkipReason)
	StatusFailed                             // unrecoverable error
	StatusRebaseConflict                     // rebase attempted, conflict, rolled back
	StatusStashConflict                      // stash pop conflicted after successful op
	StatusManualInterventionRequired         // git state corrupt, human must fix
)

// SkipReason describes why a repo was skipped.
type SkipReason string

const (
	SkipEmptyRepo          SkipReason = "empty repo (no commits)"
	SkipNoRemote           SkipReason = "no origin remote"
	SkipDetachedHEAD       SkipReason = "detached HEAD"
	SkipUnresolvedConflict SkipReason = "unresolved conflicts"
	SkipRebaseInProgress   SkipReason = "rebase in progress (REBASE_HEAD present)"
	SkipMergeInProgress    SkipReason = "merge in progress (MERGE_HEAD present)"
	SkipFetchTimeout       SkipReason = "fetch timed out"
	SkipCancelled          SkipReason = "cancelled by signal"
	SkipNoCommonAncestor   SkipReason = "no common ancestor with parent branch"
	SkipNoRemoteTracking   SkipReason = "remote tracking ref missing after fetch"
	SkipAmbiguousBranch    SkipReason = "ambiguous branch pattern"
	SkipDivergedNoRebase   SkipReason = "diverged (use default behavior to rebase)"
	SkipPushedNeedForce    SkipReason = "branch pushed to origin; use --force-rebase"
	SkipShallowClone       SkipReason = "shallow clone, rebase unsafe"
	SkipHasSubmodules      SkipReason = "submodules present, rebase unsafe"
	SkipNoStash            SkipReason = "local changes present and --no-stash set"
	SkipWhatIf             SkipReason = "dry run (--what-if)"
	SkipDefaultDiverged    SkipReason = "default branch diverged (manual intervention needed)"
	SkipRemoteGone         SkipReason = "remote repository no longer exists"
)

// ActionType is the category of action Decide returns.
type ActionType int

const (
	ActionNoOp        ActionType = iota
	ActionFastForward
	ActionRebase
	ActionSkip
	ActionFail
)

// Action is the output of Decide — what should happen for this repo.
type Action struct {
	Type                  ActionType
	SkipReason            SkipReason
	FailReason            string
	ForceRebase           bool // true when rebasing a pushed branch (--force-rebase)
	WhatIf                bool // true when --what-if flag is set
	RequiresCleanWorktree bool // true for FastForward and Rebase; false for all others
}

// BranchType classifies a branch relative to the repo's default branch.
// Re-exported from internal/types to avoid import cycles; internal/branch uses internal/types directly.
type BranchType = inttypes.BranchType

const (
	BranchTypeDefault   = inttypes.BranchTypeDefault
	BranchTypeFeature   = inttypes.BranchTypeFeature
	BranchTypeAmbiguous = inttypes.BranchTypeAmbiguous
)

// RepoState holds all observed facts about a repo — populated before Decide is called.
// Guard order in Decide is load-bearing and must match the order fields are populated
// in CollectState.
type RepoState struct {
	RepoPath        string
	IsEmpty         bool       // true if no HEAD (git rev-parse HEAD fails)
	CurrentBranch   string     // "" if detached HEAD
	DefaultBranch   string     // detected via git symbolic-ref (local, no network)
	ParentBranch    string     // for feature branches; set by DetectParent
	BranchType      BranchType
	LocalSHA        string
	RemoteSHA       string // origin/<parent> AFTER fetch; "" if not found
	BaseSHA         string // merge-base HEAD origin/<parent>; "" if no common ancestor
	HasLocalChanges bool
	HasUnmerged     bool // true if git ls-files --unmerged has output
	HasRebaseHead   bool // true if .git/REBASE_HEAD exists
	HasMergeHead    bool // true if .git/MERGE_HEAD exists
	IsShallow       bool
	HasSubmodules   bool // .gitmodules file exists in repo root
	IsPushed        bool // refs/remotes/origin/<CurrentBranch> exists locally (Feature only)
	HasOrigin       bool
	FetchErr        error
	FetchTimeout    bool
	FetchCancelled  bool // true when fetch was cancelled by parent context (SIGINT), not a timeout
	RemoteGone      bool // true when fetch fails because the remote repo was deleted or moved
}

// RepoResult is sent on the results channel after a repo is processed.
type RepoResult struct {
	RepoPath      string
	DisplayName   string   // relative path for output (set by main after discovery)
	Status        Status
	SkipReason    SkipReason
	FailReason    string
	CurrentBranch string
	ParentBranch  string
	BranchType    BranchType
	ForceRebase   bool     // triggers force-push warning in summary
	WhatIfAction  string   // non-empty when --what-if
	ElapsedMs     int64
	ManualSteps   []string // actionable recovery instructions
}

// Flags holds all parsed CLI flags.
type Flags struct {
	NoRebase      bool
	NoStash       bool
	ForceRebase   bool
	WhatIf        bool
	Concurrency   int
	FetchTimeout  int // seconds
	RebaseTimeout int // seconds
	Recursive     bool
	Verbose       bool
	All           bool
}

// StashEntry records a single active auto-stash.
type StashEntry struct {
	RepoPath     string
	StashMessage string // used to confirm identity before popping
}

// StashRegistry is a goroutine-safe registry of repos with active auto-stashes.
type StashRegistry struct {
	mu      gosync.Mutex
	entries map[string]StashEntry
}

// Add records that repoPath has an active stash with the given message.
func (r *StashRegistry) Add(entry StashEntry) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.entries == nil {
		r.entries = make(map[string]StashEntry)
	}
	r.entries[entry.RepoPath] = entry
}

// Remove deletes the stash record for repoPath.
func (r *StashRegistry) Remove(repoPath string) {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.entries, repoPath)
}

// List returns a sorted copy of all active stash entries.
func (r *StashRegistry) List() []StashEntry {
	r.mu.Lock()
	defer r.mu.Unlock()
	out := make([]StashEntry, 0, len(r.entries))
	for _, e := range r.entries {
		out = append(out, e)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].RepoPath < out[j].RepoPath })
	return out
}
