# Claude Code Guidelines for This Repository

This document contains project-specific guidelines and lessons learned for Claude Code when working in this repository.

**CRITICAL**: This document supplements [STYLE_GUIDE.md](./STYLE_GUIDE.md). Read both documents before making any changes.

## Quick Start for AI Assistants

Before making any changes:

1. ✅ Read [STYLE_GUIDE.md](./STYLE_GUIDE.md) - Authoritative coding standards
2. ✅ Read this document (CLAUDE.md) - Platform-specific gotchas and workflows
3. ✅ Review [TECHNICAL_DEBT.md](./TECHNICAL_DEBT.md) - Known issues and refactoring status
4. ✅ Check [docs/](./docs/) - Script-specific documentation

**Golden Rule**: When in doubt, consult STYLE_GUIDE.md. It is the source of truth.

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

### Standard Pre-Commit Checklist:

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

### Common Bash Pitfalls to Avoid:

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

### Before Creating a PR:

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

### Creating Pull Requests:

Always provide a PR URL at the end of every work session that involves code changes.

When in Web mode (where `gh` CLI is unavailable):
1. Provide the direct GitHub compare URL for PR creation
2. Format: `https://github.com/OWNER/REPO/compare/BASE...BRANCH?expand=1`
3. Include pre-written title and description for user to paste
4. Provide this URL before the session ends

**Example:**
```
https://github.com/bordenet/scripts/compare/main...claude/feature-branch?expand=1
```

