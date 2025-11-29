# Claude Code Guidelines for This Repository

This document contains project-specific guidelines and lessons learned for Claude Code when working in this repository.

**CRITICAL**: This document supplements [STYLE_GUIDE.md](./STYLE_GUIDE.md). Read both documents before making any changes.

## Repository Status

**All 80+ scripts in this repository are 100% compliant with our coding standards.**

### Current Compliance Metrics

- ✅ **Zero ShellCheck warnings** - All scripts pass `shellcheck -S warning`
- ✅ **Zero syntax errors** - All scripts validated with `bash -n`
- ✅ **Correct shebang** - All scripts use `#!/usr/bin/env bash`
- ✅ **Error handling** - All scripts use `set -euo pipefail` (except bu.sh/mu.sh)
- ✅ **Line limits** - No script exceeds 400 lines
- ✅ **Help documentation** - All scripts implement `-h/--help` with man-page style output
- ✅ **Dry-run support** - All destructive scripts implement `--what-if` flag
- ✅ **Pre-commit hook** - Automated quality gate installed and enforced

**Last validated:** 2025-11-25

---

## Quick Start for AI Assistants

Before making any changes:

1. ✅ Read [STYLE_GUIDE.md](./STYLE_GUIDE.md) - Authoritative coding standards
2. ✅ Read this document (CLAUDE.md) - Platform-specific gotchas and workflows
3. ✅ Check [docs/](./docs/) - Script-specific documentation

**Golden Rule**: When in doubt, consult STYLE_GUIDE.md. It is the source of truth.

**Maintain 100% Compliance**: All new scripts and changes must meet the standards above. The pre-commit hook will enforce this automatically.

---

## User Environment

- **All hardware is Apple Silicon** (ARM64 architecture)
- Homebrew paths: `/opt/homebrew/` (not `/usr/local/`)
- When suggesting paths, always use Apple Silicon defaults first
- **macOS uses BSD tools, not GNU** - always test awk/sed/grep syntax
  - BSD awk does NOT support `match()` with array capture
  - Use `grep | sed` pipelines instead of complex awk
  - Test all regex/text processing commands before committing
  - See [STYLE_GUIDE.md § Platform Compatibility](./STYLE_GUIDE.md#platform-compatibility) for details

## Quality Standards for Code Delivery

### Pre-Commit Requirements

All code changes should be tested, validated, and linted before committing.

### Standard Pre-Commit Checklist

1. **Lint the code**
   - Run shellcheck for bash scripts
   - Run appropriate linter for the language
   - Fix all warnings that aren't explicitly false positives
   - Target: zero linting errors/warnings before commit

2. **Test the code**
   - Test commands with sample data before committing
   - Test basic functionality where possible
   - Run syntax checks at minimum
   - Test awk/sed/grep commands in isolation with `echo "sample" | command`
   - If you can't test on the target platform, explicitly document this
   - Verify all functions work as expected

3. **Validate the code**
   - Check syntax: `bash -n script.sh`
   - Verify all sourced files exist
   - Confirm all required commands/dependencies are available
   - Test with edge cases (empty inputs, special characters, etc.)

4. **Handle edge cases**
   - Filenames with spaces/special characters
   - Empty inputs
   - Command failures
   - Concurrent execution (file locking where needed)

5. **Error handling**
   - Check return codes
   - Don't mask errors with `local var=$(cmd)` without checking
   - Provide actionable error messages
   - Log errors comprehensively

6. **Input validation**
   - Sanitize user input
   - Validate formats (emails, paths, etc.)
   - Prevent command injection

### Common Bash Pitfalls to Avoid

1. **SC2155**: Declare and assign separately

   ```bash
   # Bad
   local var=$(command)
   
   # Good
   local var
   var=$(command) || handle_error
   ```

2. **Filename handling**: Use null delimiters

   ```bash
   # Bad
   find . -type f | while read file; do

   # Good
   while IFS= read -r -d '' file; do
       ...
   done < <(find . -type f -print0)
   ```

3. **Unused variables**: Remove them or document why they're there

4. **Input sanitization**: Always validate and sanitize user input

   ```bash
   # Validate format
   [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]] || return_error

   # Sanitize metacharacters
   email="${email//[;<>\`\$\(\)]/}"
   ```

### Before Creating a PR

Use the comprehensive checklist from [STYLE_GUIDE.md § Enforcement](./STYLE_GUIDE.md#enforcement):

1. ✅ All linter warnings addressed (zero warnings)
2. ✅ Syntax validated (`bash -n script.sh`)
3. ✅ Edge cases considered and documented
4. ✅ Error handling tested where possible
5. ✅ Code follows project conventions
6. ✅ Commit messages are descriptive
7. ✅ All scripts < 400 lines
8. ✅ Help text is comprehensive (man-page style)
9. ✅ Timer and display requirements met
10. ✅ Platform-specific code tested

**See [STYLE_GUIDE.md § Comprehensive Pre-Commit Validation Checklist](./STYLE_GUIDE.md#comprehensive-pre-commit-validation-checklist) for complete list.**

### Creating Pull Requests

Always provide a PR URL at the end of every work session that involves code changes.

When in Web mode (where `gh` CLI is unavailable):

1. Provide the direct GitHub compare URL for PR creation
2. Format: `https://github.com/OWNER/REPO/compare/BASE...BRANCH?expand=1`
3. Include pre-written title and description for user to paste
4. Provide this URL before the session ends

**Example:**

```text
https://github.com/bordenet/scripts/compare/main...claude/feature-branch?expand=1
```

---

## Critical Workflow: Impact Analysis Before ANY Change

**MANDATORY**: Before making ANY change (especially deletions), perform complete impact analysis.

### When Deleting or Renaming Files

**ALWAYS follow this exact sequence:**

1. **Search for ALL references FIRST** (before any changes):
   ```bash
   # Search across all files
   grep -r "FILENAME" --include="*.md" --include="*.sh" .

   # Check for broken links that will result
   ./validate-cross-references.sh
   ```

2. **Identify ALL affected files**:
   - Documentation files (README.md, CLAUDE.md, STYLE_GUIDE.md, docs/*)
   - Scripts that source or reference the file
   - Configuration files
   - CI/CD workflows

3. **Plan atomic commit**:
   - List ALL files that need updates
   - Ensure all changes happen in ONE commit
   - Never commit a deletion without updating all references

4. **Make ALL changes together**:
   - Delete/rename the target file
   - Update ALL referencing files
   - Fix ALL broken links
   - Update related documentation

5. **Validate BEFORE committing**:
   ```bash
   # Verify file is gone (if deleting)
   test -f FILENAME && echo "ERROR: Still exists" || echo "OK: Deleted"

   # Verify no references remain
   grep -r "FILENAME" --include="*.md" --include="*.sh" . || echo "OK: No references"

   # Run validation scripts
   ./validate-cross-references.sh
   ./validate-script-compliance.sh
   ```

6. **Only then commit**

### When Updating Documentation

**ALWAYS verify completeness:**

1. **Before editing README.md**, check what's missing:
   ```bash
   # List all root-level scripts
   ls -1 *.sh 2>/dev/null | sort

   # Compare against README.md
   grep "\.sh" README.md | grep -o '[a-z0-9-]*\.sh' | sort
   ```

2. **Identify gaps**:
   - Scripts not documented
   - Outdated descriptions
   - Broken links
   - Missing categories

3. **Fix everything in one commit**:
   - Add missing scripts
   - Update descriptions
   - Fix broken links
   - Ensure alphabetical ordering within categories

### Validation Tools in This Repository

**USE THESE BEFORE EVERY COMMIT:**

- `./validate-cross-references.sh` - Validates all markdown links and cross-references
- `./validate-script-compliance.sh` - Validates scripts against STYLE_GUIDE.md
- `./ci-quality-gates.sh` - Runs all CI checks locally

**Example pre-commit workflow:**

```bash
# 1. Make your changes
# 2. Validate everything
./validate-cross-references.sh
./validate-script-compliance.sh

# 3. Check for broken references to files you changed
grep -r "CHANGED_FILENAME" --include="*.md" --include="*.sh" .

# 4. Only then commit
git add -A
git commit -m "Description"
```

### Lessons Learned: Real Failures

**Failure Case 1: Incomplete deletion (2025-11-25)**
- **What happened**: Deleted TECHNICAL_DEBT.md without checking references
- **Impact**: Left broken links in README.md and CLAUDE.md
- **Root cause**: Didn't search for references before deletion
- **Prevention**: ALWAYS `grep -r "FILENAME"` before deleting

**Failure Case 2: Incomplete documentation (2025-11-25)**
- **What happened**: Updated README.md without checking completeness
- **Impact**: 5 user-facing scripts undocumented
- **Root cause**: Didn't compare `ls *.sh` against README.md
- **Prevention**: ALWAYS audit completeness when editing documentation

**Failure Case 3: `set -euo pipefail` abort (2025-11-29)**
- **What happened**: `fetch-github-projects.sh --all` aborted immediately after showing "Updating CallBox..."
- **Impact**: Script terminated with non-zero exit code, user's workflow broken
- **Root cause**: The pipeline `git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}'` failed silently when the network command failed. With `pipefail`, the entire script aborted.
- **Similar issues found in**: 6 scripts with `stop_timer()` functions using bare `kill`/`wait` commands
- **Prevention**:
  - ALWAYS add `|| true` to network-dependent pipelines that shouldn't abort the script
  - ALWAYS add `|| true` to `kill` and `wait` commands in cleanup functions
  - ALWAYS test scripts with simulated network failures
  - See [STYLE_GUIDE.md § Surviving `set -euo pipefail`](./STYLE_GUIDE.md#surviving-set--euo-pipefail) for patterns

### The Golden Rule of Changes

**NEVER make a change in isolation. ALWAYS:**

1. ✅ Search for ALL impacts FIRST
2. ✅ Plan ALL related changes
3. ✅ Make ALL changes atomically
4. ✅ Validate BEFORE committing
5. ✅ Run validation scripts

**If you skip any step, you WILL create broken references, incomplete documentation, or inconsistent state.**

---

## Comprehensive Pre-Push Audit Checklist

**MANDATORY**: Run this complete audit before pushing to `origin/main` or creating any pull request. This is a SCRIPTS repository - quality gates must be 100% clean.

### When to Run This Audit

- Before pushing to `origin/main`
- After completing a major feature or refactor
- After making changes that affect multiple scripts
- When preparing for a release
- **Periodically** (at least monthly) to catch drift

### The Complete Audit Process

```bash
# 1. SYNTAX VALIDATION - Every script must parse correctly
find . -type f -name "*.sh" -exec bash -n {} \; 2>&1
# Expected: None (silence means success)
# Fix syntax errors immediately if found

# 2. SHELLCHECK VALIDATION - Zero warnings at -S warning level
for script in $(find . -type f -name "*.sh"); do
  shellcheck -S warning "$script" 2>&1 | grep -q "^In " && echo "FAIL: $script"
done
# Expected: None
# Fix all shellcheck warnings if found

# 3. CROSS-REFERENCE VALIDATION - All markdown links must be valid
./validate-cross-references.sh
# Expected: "All cross-references are valid"
# Fix broken links atomically with changes

# 4. LINE COUNT VALIDATION - No script > 400 lines
find . -type f -name "*.sh" -exec wc -l {} + | awk '$1 > 400 {print "FAIL:", $2, "("$1" lines)"}'
# Expected: None
# Refactor oversized scripts into lib/ modules

# 5. PIPEFAIL PATTERN VALIDATION - Network commands need || true
grep -r "git remote show origin\|curl.*|" --include="*.sh" . | grep -v "|| true" | grep "set -euo pipefail"
# Expected: None
# Add || true to network-dependent pipelines

# 6. KILL/WAIT VALIDATION - Cleanup functions need || true
for script in $(grep -l "set -euo pipefail" *.sh **/*.sh 2>/dev/null); do
  grep -H "kill \|wait " "$script" | grep -v "|| true" && echo "CHECK: $script"
done
# Expected: Only scripts without pipefail (mu.sh, lib files)
# Add || true to kill/wait in pipefail scripts

# 7. EXIT CODE CAPTURE VALIDATION - $? captured immediately
grep -rn "exit_code=\$?" --include="*.sh" .
# Manually verify: must be first statement after command
# Fix if suspicious context

# 8. SOURCED FILE VALIDATION - All libraries exist
for script in $(find . -type f -name "*.sh"); do
  grep "^source \|^\. " "$script" 2>/dev/null | while read -r line; do
    file=$(echo "$line" | awk '{print $2}' | tr -d '"')
    [ -f "$file" ] || echo "MISSING: $file (in $script)"
  done
done
# Expected: None
# Fix source paths or create libraries

# 9. DOCUMENTATION COMPLETENESS - User scripts in README
comm -23 <(ls -1 *.sh 2>/dev/null | sort) <(grep "\.sh" README.md | grep -o '[a-z0-9-]*\.sh' | sort)
# Expected: Only lib/internal scripts
# Add user-facing scripts to README.md

# 10. TODO/FIXME AUDIT - All TODOs documented
grep -rn "TODO\|FIXME" --include="*.sh" . | grep -v "git-rebase-todo"
# Review each: explained? ticket? can fix now?
```

### What to Do When Checks Fail

**DO NOT commit until ALL checks pass.** This is non-negotiable.

1. **Fix the issue** - Don't work around it
2. **Understand root cause** - Why did this happen?
3. **Update checklist if needed** - Missing a pattern?
4. **Re-run full audit** - Fixes can introduce new issues

### Quick Validation During Development

```bash
# Fast check before each commit
bash -n script.sh && shellcheck -S warning script.sh
```

### Recording Audit Results

```bash
# After successful audit, create timestamp
date "+%Y-%m-%d %H:%M:%S" > .last-audit
git add .last-audit
git commit -m "chore: Complete pre-push audit - all gates pass"
```

---
