# purge-stale-claude-code-web-branches.sh Design Document

## Overview
Interactive tool to identify and delete stale Claude Code web branches with safety confirmations and human-readable timestamps.

## Purpose
Claude Code web creates many branches over time. This script helps maintain repository hygiene by providing a safe, interactive way to delete branches that are no longer needed.

## User Experience Pattern
Follows **fetch-github-projects.sh** UX design:
- Menu-driven interface (numbered selection)
- `--all` flag for batch processing
- Live timer in top-right corner during operations
- Interactive confirmation before each deletion
- Human-readable timestamps (e.g., "3d ago", "2w ago", "1y ago")
- Color-coded indicators throughout
- Summary at end showing deleted branches

## Workflow Steps

### 1. Discovery Phase
- Scan for all `claude/*` branches (both local and remote)
- Get last commit timestamp for each branch
- Calculate age in human-readable format (m/h/d/w/y)
- Sort by age (oldest first)

### 2. Menu Phase (Interactive Mode)
- Display numbered list of Claude branches
- Show: number, branch name, last commit time, age
- Options:
  - Enter number to delete specific branch
  - Enter 'all' to process all branches
  - Ctrl+C to exit

### 3. Confirmation Phase (Per Branch)
- Show branch details:
  - Full branch name
  - Last commit date (human-readable)
  - Last commit author
  - Last commit message (first line)
- Ask: "Delete this branch? [y/N]"
- Default to NO for safety

### 4. Deletion Phase
- Delete local branch: `git branch -D <branch>`
- Delete remote branch: `git push origin --delete <branch>`
- Track: deleted, skipped, failed

### 5. Summary Phase
- Show total time
- List deleted branches
- List skipped branches
- List failed branches

## Command Line Interface

### Synopsis
```bash
purge-stale-claude-code-web-branches.sh [OPTIONS]
purge-stale-claude-code-web-branches.sh --all
```

### Options
- `--all`: Process all branches automatically (still requires per-branch confirmation)
- `-h, --help`: Display help and exit

### Examples
```bash
# Interactive menu mode (default)
./purge-stale-claude-code-web-branches.sh

# Process all branches with confirmations
./purge-stale-claude-code-web-branches.sh --all
```

## Age Calculation

### Format
- Less than 60 minutes: `15m ago`
- Less than 24 hours: `3h ago`
- Less than 7 days: `5d ago`
- Less than 52 weeks: `2w ago`
- 52+ weeks: `1y ago`

### Implementation
```bash
calculate_age() {
    local commit_timestamp=$1
    local now=$(date +%s)
    local diff=$((now - commit_timestamp))

    local minutes=$((diff / 60))
    local hours=$((diff / 3600))
    local days=$((diff / 86400))
    local weeks=$((diff / 604800))
    local years=$((diff / 31536000))

    if [ $minutes -lt 60 ]; then
        echo "${minutes}m ago"
    elif [ $hours -lt 24 ]; then
        echo "${hours}h ago"
    elif [ $days -lt 7 ]; then
        echo "${days}d ago"
    elif [ $weeks -lt 52 ]; then
        echo "${weeks}w ago"
    else
        echo "${years}y ago"
    fi
}
```

## Branch Discovery

### Local Branches
```bash
git for-each-ref --format='%(refname:short)|%(committerdate:unix)|%(authorname)|%(subject)' refs/heads/claude/
```

### Remote Branches
```bash
git for-each-ref --format='%(refname:short)|%(committerdate:unix)|%(authorname)|%(subject)' refs/remotes/origin/claude/
```

### Merge Strategy
- Include branches that exist locally OR remotely OR both
- Mark location: (local), (remote), (both)
- Deletion strategy varies based on location

## Safety Features

### 1. Confirmation Before Deletion
Always ask user to confirm each deletion with branch details shown.

### 2. Main Branch Protection
Never list or attempt to delete main/master branches.

### 3. Current Branch Protection
Never delete the currently checked out branch.

### 4. Detailed Information
Show commit details before asking for confirmation:
- Last commit date
- Last commit author
- Last commit message
- Branch location (local/remote/both)

### 5. Dry Run Summary
Before any deletions in --all mode, show count and ask for confirmation.

## Error Handling

### Critical Errors (exit immediately)
- Not a git repository
- No remote 'origin' configured
- Cannot fetch from origin

### Non-Critical Errors (track and report)
- Failed to delete local branch
- Failed to delete remote branch
- Cannot parse commit data

## Output Format

### Menu Mode
```
Claude Code Branch Cleanup
                                                                        00:02

Found 5 Claude Code branches

Select a branch to review for deletion:
  1) claude/fix-bug-123          (2d ago)  [both]
  2) claude/feature-abc          (1w ago)  [local]
  3) claude/review-plan-xyz      (3w ago)  [remote]
  4) claude/old-experiment       (2m ago)  [both]
  5) claude/ancient-test         (1y ago)  [both]

Enter number (or 'all'): 1

Branch: claude/fix-bug-123
Last commit: 2 days ago (2025-01-16 14:30:00)
Author: Claude
Message: fix: Resolve issue with user authentication
Location: local and remote

Delete this branch? [y/N]: y
  Deleting local branch...
✓ Deleted local branch
  Deleting remote branch...
✓ Deleted remote branch

Select a branch to review for deletion:
  1) claude/feature-abc          (1w ago)  [local]
  2) claude/review-plan-xyz      (3w ago)  [remote]
  3) claude/old-experiment       (2m ago)  [both]
  4) claude/ancient-test         (1y ago)  [both]

Enter number (or 'all'): ^C
```

### --all Mode
```
Claude Code Branch Cleanup
                                                                        00:35

Found 5 Claude Code branches

Processing all branches with confirmation...

[1/5] claude/fix-bug-123 (2d ago)
Last commit: 2 days ago (2025-01-16 14:30:00)
Author: Claude
Message: fix: Resolve issue with user authentication
Location: local and remote

Delete this branch? [y/N]: y
✓ Deleted local and remote branch

[2/5] claude/feature-abc (1w ago)
Last commit: 1 week ago (2025-01-11 09:15:00)
Author: Claude
Message: feat: Add new feature component
Location: local only

Delete this branch? [y/N]: n
⊘ Skipped claude/feature-abc

[3/5] claude/review-plan-xyz (3w ago)
...

Summary (35s)

✓ Deleted (2):
  • claude/fix-bug-123 (2d ago)
  • claude/ancient-test (1y ago)

⊘ Skipped (2):
  • claude/feature-abc (1w ago)
  • claude/old-experiment (2m ago)

✗ Failed (1):
  • claude/review-plan-xyz: remote deletion failed
```

## Implementation Notes

### Branch Listing
- Use `git for-each-ref` for reliable parsing
- Filter for `refs/heads/claude/*` and `refs/remotes/origin/claude/*`
- Parse format: `refname|timestamp|author|subject`
- Combine local and remote into unified list

### Date Formatting
- Use `%(committerdate:unix)` for timestamp
- Convert to human-readable with custom function
- Show both relative ("2d ago") and absolute date in confirmation

### Deletion Process
```bash
# Local deletion
git branch -D <branch>

# Remote deletion
git push origin --delete <branch>
```

### Menu Management
- After each deletion/skip, update the menu
- Remove deleted branches from list
- Re-display remaining branches
- Exit when list is empty or user cancels

## Dependencies
- **git**: Version control operations
- No additional dependencies (pure git + bash)

## Future Enhancements
- `--dry-run` flag to show what would be deleted without confirmation
- `--older-than <duration>` to filter by age
- `--force` to skip all confirmations (dangerous!)
- `--pattern <regex>` to filter by branch name pattern
- Batch mode: confirm once, delete all selected
