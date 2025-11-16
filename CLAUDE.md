# Claude Code Guidelines for This Repository

This document contains project-specific guidelines and lessons learned for Claude Code when working in this repository.

## User Environment

- **All hardware is Apple Silicon** (ARM64 architecture)
- Homebrew paths: `/opt/homebrew/` (not `/usr/local/`)
- When suggesting paths, always use Apple Silicon defaults first
- **macOS uses BSD tools, not GNU** - always test awk/sed/grep syntax
  - BSD awk does NOT support `match()` with array capture
  - Use `grep | sed` pipelines instead of complex awk
  - Test all regex/text processing commands before committing


## Quality Standards for Code Delivery

### ⚠️ MANDATORY PRE-COMMIT REQUIREMENTS ⚠️

**YOU MUST TEST, VALIDATE, AND LINT ALL CODE CHANGES BEFORE COMMITTING**

This is **NON-NEGOTIABLE**. Do not skip these steps. Do not wait to be asked.

### ALWAYS Do Before Claiming "Done":

1. **Lint the code** ✅ **MANDATORY**
   - Run shellcheck for bash scripts
   - Run appropriate linter for the language
   - Fix ALL warnings that aren't explicitly false positives
   - Don't wait to be asked
   - **Zero linting errors/warnings allowed before commit**

2. **Test the code** ✅ **MANDATORY**
   - **ALWAYS test commands with sample data before committing**
   - Test basic functionality where possible
   - Run syntax checks at minimum
   - Don't commit broken code
   - Test awk/sed/grep commands in isolation with `echo "sample" | command`
   - If you can't test on the target platform, explicitly document this
   - **Verify all functions work as expected**

3. **Validate the code** ✅ **MANDATORY**
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

1. All linter warnings addressed
2. Syntax validated
3. Edge cases considered and documented
4. Error handling tested where possible
5. Code follows project conventions
6. Commit messages are descriptive

**Don't make the user ask for basic quality practices.**

### Creating Pull Requests:

**⚠️ CRITICAL - MANDATORY IN EVERY SESSION ⚠️**

**YOU MUST ALWAYS PROVIDE A PR URL AT THE END OF EVERY WORK SESSION**

This is **NON-NEGOTIABLE**. Do not wait to be asked. Do not forget this step.

When in Web mode (where `gh` CLI is unavailable):
1. **ALWAYS** provide the direct GitHub compare URL for PR creation
2. Format: `https://github.com/OWNER/REPO/compare/BASE...BRANCH?expand=1`
3. Include pre-written title and description for user to paste
4. Provide this URL **BEFORE** the session ends
5. Don't leave the user hunting for how to create the PR

**Example:**
```
https://github.com/bordenet/scripts/compare/main...claude/feature-branch?expand=1
```

**This must be the LAST thing you do in every session that involves code changes.**

If you forget to provide the PR URL, you have failed to complete the task.

