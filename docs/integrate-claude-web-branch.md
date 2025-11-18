# integrate-claude-web-branch.sh Design Document

## Overview
Automates the integration of Claude Code web branches into the main branch via a complete PR workflow.

## Purpose
Claude Code web creates branches with names like `claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH`. This script automates the repetitive workflow of integrating these branches into main through the proper PR process.

## User Experience Pattern
Follows **bu.sh** UX design:
- Live timer in top-right corner (yellow on black, MM:SS format)
- Inline status updates using ANSI escape sequences
- Color-coded indicators: ✓ (success), ✗ (failure), • (already exists), ⊘ (skipped)
- Clear screen at start for clean presentation
- Summary at end with execution time
- Minimal vertical space usage

## Workflow Steps

### 1. Validation Phase
- ✓ Validate current directory is a git repository
- ✓ Check GitHub CLI (gh) is installed
- ✓ Verify GitHub CLI authentication
- ✓ Detect main branch name (main/master)
- ✓ Verify feature branch exists locally

### 2. Preparation Phase
- ✓ Fetch latest from origin
- ✓ Switch to main branch
- ✓ Pull latest main to avoid conflicts
- ✓ Switch back to feature branch
- ✓ Push feature branch to origin (ensure it exists remotely)

### 3. Integration Phase
- ✓ Create pull request against main
  - Use `gh pr create --base main --head <branch> --fill`
  - Handle case where PR already exists
- ✓ Merge pull request
  - Use `gh pr merge <number> --merge`
  - Keep branch initially (don't auto-delete)
- ✓ Switch back to main
- ✓ Pull merged changes

### 4. Cleanup Phase (Optional)
- Ask user if they want to delete local branch
- If yes, delete with `git branch -D <branch>`
- Remote branch can be deleted manually later

## Error Handling

### Critical Errors (exit immediately)
- Not a git repository
- GitHub CLI not installed
- GitHub CLI not authenticated
- Cannot detect main branch
- Branch doesn't exist locally
- Failed to fetch from origin
- Failed to checkout branches
- Failed to pull main
- Failed to create PR
- Failed to merge PR

### Non-Critical Errors (warn and continue)
- Could not delete local branch (after merge is complete)

## Command Line Interface

### Synopsis
```bash
integrate-claude-web-branch.sh <branch-name>
integrate-claude-web-branch.sh -h|--help
```

### Arguments
- `branch-name` (required): The Claude Code web branch to integrate

### Options
- `-h, --help`: Display help and exit

### Examples
```bash
# Integrate a Claude Code web branch
./integrate-claude-web-branch.sh claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH
```

## Dependencies
- **git**: Version control operations
- **gh**: GitHub CLI for PR creation and merging
  - Must be installed: `brew install gh`
  - Must be authenticated: `gh auth login`

## Output Format

### Success Flow
```
Claude Code Branch Integration: claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH
                                                                        00:15

✓ Git repository validated
✓ GitHub CLI available
✓ GitHub authenticated
✓ Main branch: main
✓ Branch exists locally
✓ Fetched latest from origin
✓ Switched to main
✓ Pulled latest main
✓ Switched to claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH
✓ Pushed branch to origin
✓ Created PR #42
✓ Merged PR #42
✓ Switched to main
✓ Pulled merged changes

Delete local branch 'claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH'? [y/N]: y
✓ Deleted local branch

Summary (15s)

✓ Branch 'claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH' successfully integrated into main
✓ PR #42 merged and changes pulled
```

### Error Flow Example
```
Claude Code Branch Integration: claude/nonexistent-branch
                                                                        00:02

✓ Git repository validated
✓ GitHub CLI available
✓ GitHub authenticated
✓ Main branch: main
✗ Branch not found locally

Error: Branch 'claude/nonexistent-branch' does not exist locally
```

## Implementation Notes

### Timer Management
- Background process updates timer every second
- Automatically stopped on exit via trap
- Timer line cleared before summary

### Status Updates
- `update_status()`: Inline update (no newline)
- `complete_status()`: Finalize line with newline
- All status lines erased and rewritten in place

### Branch Detection
1. Try `git remote show origin` to get HEAD branch
2. Fallback to checking refs/heads/main
3. Fallback to checking refs/heads/master
4. Error if none found

### PR Operations
- Use `--fill` to auto-populate PR title/body from commits
- Capture PR number from output for merge operation
- Handle "PR already exists" gracefully
- Use `--delete-branch=false` to keep remote branch initially

## Future Enhancements
- Support for `--auto-delete` flag to skip cleanup prompt
- Support for `--no-merge` to create PR but not merge
- Support for batch processing multiple branches
- Integration with purge-stale-claude-code-web-branches.sh
