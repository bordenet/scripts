# Claude Code Guidelines for This Repository

This document contains project-specific guidelines and lessons learned for Claude Code when working in this repository.


## Quality Standards for Code Delivery

### ALWAYS Do Before Claiming "Done":

1. **Lint the code**
   - Run shellcheck for bash scripts
   - Run appropriate linter for the language
   - Fix ALL warnings that aren't explicitly false positives
   - Don't wait to be asked

2. **Test the code**
   - Test basic functionality where possible
   - Run syntax checks at minimum
   - Don't commit broken code
   - If you can't test on the target platform, explicitly document this

3. **Handle edge cases**
   - Filenames with spaces/special characters
   - Empty inputs
   - Command failures
   - Concurrent execution (file locking where needed)

4. **Error handling**
   - Check return codes
   - Don't mask errors with `local var=$(cmd)` without checking
   - Provide actionable error messages
   - Log errors comprehensively

5. **Input validation**
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

