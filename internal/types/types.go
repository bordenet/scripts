// Package types holds shared primitive types used across multiple packages
// to avoid import cycles. Only types with no dependencies on other internal
// packages belong here.
package types

// BranchType classifies a branch relative to the repo's default branch.
type BranchType int

const (
	BranchTypeDefault   BranchType = iota
	BranchTypeFeature
	BranchTypeAmbiguous
)
