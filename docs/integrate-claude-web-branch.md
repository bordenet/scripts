# integrate-claude-web-branch.sh Design Document

## Overview
Automates the integration of Claude Code web branches (remote-only) into the main branch via a complete PR workflow with safety checks and countdown timer.

## Purpose
Claude Code web creates branches remotely with names like `claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH`. This script automates the workflow of integrating these remote branches into main through a proper PR process with verification and review time.

## Key Design Decisions

### Remote-Only Branch Handling
- Claude Code web creates branches **on the remote only**
- No local branch exists initially
- Script works entirely with remote branch references
- Uses `gh pr create --head BRANCH` (not `--head origin/BRANCH`)

### 90-Second Review Window
- After PR creation and mergability verification, show PR URL
- 90-second countdown before auto-merge
- User can cancel with Ctrl+C or typing 'n'
- Allows time to review PR in browser before merging

### No Branch Deletion
- Remote branch remains intact after merge
- Use `purge-stale-claude-code-web-branches.sh` for cleanup later
- Prevents accidental deletion of branches that might be needed

## User Experience Pattern
Follows **bu.sh** UX design:
- Live timer in top-right corner (yellow on black, MM:SS format)
- Inline status updates using ANSI escape sequences
- Color-coded indicators: ✓ (success), ✗ (failure), • (already exists), ⊘ (cancelled)
- Clear screen at start for clean presentation
- Timer stops during 90-second countdown
- Summary at end with execution time
- Minimal vertical space usage

## Workflow Steps

### 1. Validation Phase
- ✓ Validate current directory is a git repository
- ✓ Check GitHub CLI (gh) is installed
- ✓ Verify GitHub CLI authentication

### 2. Discovery Phase
- ✓ Fetch latest from origin (includes remote Claude branches)
- ✓ Detect main branch name (main/master)
- ✓ Verify feature branch exists remotely (`refs/remotes/origin/BRANCH`)
- ✗ Show available claude/* branches if not found

### 3. Preparation Phase
- ✓ Switch to main branch (local)
- ✓ Pull latest main to avoid conflicts

### 4. PR Creation Phase
- ✓ Create pull request from remote branch
  - Use `gh pr create --base MAIN --head BRANCH --fill`
  - Extract PR number and URL
  - Handle case where PR already exists
- ✓ Check PR mergability
  - Use `gh pr view PR --json mergeable --jq '.mergeable'`
  - Verify status is "MERGEABLE"
  - Exit with error if conflicts or failing checks

### 5. Review Phase (90-second countdown)
- Stop timer
- Display PR URL prominently
- Show countdown: "Merging in 90s... [Cancel: Ctrl+C or type 'n']"
- Check for user input every second
- If 'n' pressed: exit with message, leave PR open
- If Ctrl+C: normal shell interrupt
- If countdown expires: continue to merge
- Restart timer for merge operations

### 6. Integration Phase
- ✓ Merge pull request
  - Use `gh pr merge PR --merge --delete-branch=false`
  - Keep branch (explicit flag)
- ✓ Pull merged changes into local main

### 7. Completion Phase
- Show summary with execution time
- Confirm branch integrated successfully
- Remind user remote branch remains intact
- Suggest using purge script for cleanup

## Command Line Interface

### Synopsis
```bash
integrate-claude-web-branch.sh [OPTIONS] <branch-name>
integrate-claude-web-branch.sh -h|--help
```

### Arguments
- `branch-name`: Claude Code web branch name (e.g., `claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH`)

### Options
- `--what-if`: Dry-run mode showing what would happen without making changes
- `-h, --help`: Display help and exit

### Examples
```bash
# Integrate a Claude Code web branch
./integrate-claude-web-branch.sh claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH

# Dry-run to see what would happen
./integrate-claude-web-branch.sh --what-if claude/review-project-plan-011r6RivoGzbqxC2cSGVMceH
```

## Error Handling

### Critical Errors (exit immediately)
- Not a git repository
- GitHub CLI not installed
- GitHub CLI not authenticated
- Cannot detect main branch
- Remote branch does not exist
- Cannot fetch from origin
- Cannot pull main branch
- PR creation failed (not already-exists case)
- PR is not mergeable (conflicts or failing checks)
- PR merge failed
- Cannot pull merged changes

### Handled Gracefully
- PR already exists → Get existing PR number and URL, continue
- User cancels during countdown → Exit cleanly, leave PR open

## Output Format

### Validation and Preparation
```
Claude Code Branch Integration: claude/feature-xyz
                                                                        00:03

✓ Git repository validated
✓ GitHub CLI available
✓ GitHub authenticated
✓ Fetched latest from origin
✓ Main branch: main
✓ Remote branch exists
✓ Switched to main
✓ Pulled latest main
```

### PR Creation and Review
```
✓ Created PR #123
✓ PR is mergeable

Pull Request Ready
https://github.com/owner/repo/pull/123

Auto-merging in 90 seconds... (Press Ctrl+C or 'n' to cancel)

Merging in 45s... [Cancel: Ctrl+C or type 'n']
```

### Integration Complete
```
✓ Merged PR #123
✓ Pulled merged changes

Summary (2m 15s)

✓ Branch 'origin/claude/feature-xyz' successfully integrated into main
✓ PR #123 merged and changes pulled

Remote branch 'origin/claude/feature-xyz' remains intact.
Use purge-stale-claude-code-web-branches.sh to clean up when ready.
```

### User Cancellation
```
Merging in 23s... [Cancel: Ctrl+C or type 'n']n

⊘ Merge cancelled by user
PR #123 remains open: https://github.com/owner/repo/pull/123
```

### Dry-Run Mode
```
Claude Code Branch Integration [DRY-RUN]: claude/feature-xyz

YELLOW ⊙ indicators for each step

Summary (12s)

DRY-RUN: No changes were made

Would have performed:
  • Fetched latest from origin
  • Verified remote branch origin/claude/feature-xyz exists
  • Pulled latest main
  • Created PR: origin/claude/feature-xyz → main
  • Checked PR mergability
  • Shown PR URL with 90-second countdown
  • Merged PR into main
  • Pulled merged changes
  • Left remote branch intact
```

## Implementation Notes

### Remote Branch Detection
```bash
# Check if remote branch exists
if ! git show-ref --quiet refs/remotes/origin/"$BRANCH_NAME"; then
    echo "Error: Branch 'origin/$BRANCH_NAME' does not exist"
    echo "Available claude/* branches:"
    git branch -r | grep "origin/claude/" || echo "  (none found)"
    exit 1
fi
```

### PR Mergability Check
```bash
MERGEABLE=$(gh pr view "$PR_NUMBER" --json mergeable --jq '.mergeable' 2>/dev/null)
if [ "$MERGEABLE" != "MERGEABLE" ]; then
    echo "Error: PR #$PR_NUMBER has conflicts or failing checks"
    exit 1
fi
```

### 90-Second Countdown with Cancellation
```bash
stop_timer  # Stop main timer during countdown

for i in {90..1}; do
    echo -ne "\rMerging in ${i}s... [Cancel: Ctrl+C or type 'n']"

    # Non-blocking read with 1-second timeout
    if read -t 1 -n 1 -r response; then
        if [[ "$response" =~ ^[Nn]$ ]]; then
            echo "\n\n⊘ Merge cancelled by user"
            echo "PR #$PR_NUMBER remains open: $PR_URL"
            exit 0
        fi
    fi
done

start_timer  # Restart timer for merge operations
```

### PR Creation from Remote Branch
```bash
# Create PR from remote branch (gh resolves 'origin/')
gh pr create --base "$MAIN_BRANCH" --head "$BRANCH_NAME" --fill
```

### PR Merge (Keep Branch)
```bash
# Explicitly keep branch after merge
gh pr merge "$PR_NUMBER" --merge --delete-branch=false
```

## Dependencies
- **git**: Version control operations
- **gh**: GitHub CLI for PR operations
- Must be run from within the target repository
- User must have merge permissions

## Safety Features

1. **Mergability Verification**: Checks PR can be merged before attempting
2. **Review Window**: 90-second countdown allows review in browser
3. **User Cancellation**: Easy abort with 'n' key or Ctrl+C
4. **No Branch Deletion**: Remote branch preserved for later cleanup
5. **Error Messages**: Clear actionable error messages with PR URLs
6. **Dry-Run Mode**: Test workflow without making changes

## Future Enhancements

- `--no-countdown`: Skip 90-second wait and merge immediately
- `--countdown N`: Custom countdown duration
- `--delete-branch`: Option to delete remote branch after merge
- `--squash` or `--rebase`: Alternative merge strategies
- Show PR description preview during countdown
- Check for required approvals before merging
- Integration with CI/CD status checks
