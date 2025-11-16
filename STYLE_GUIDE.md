# Shell Script Style Guide

**Version:** 1.0
**Last Updated:** 2025-11-16
**Target Audience:** Claude Code, Google Gemini, Human Developers

This is the authoritative style guide for all shell scripts in this repository. These standards are **non-negotiable** and must be followed without exception.

---

## Table of Contents

1. [Script Length Limits](#script-length-limits)
2. [File Structure](#file-structure)
3. [Shell Configuration](#shell-configuration)
4. [Documentation](#documentation)
5. [Naming Conventions](#naming-conventions)
6. [Error Handling](#error-handling)
7. [Input Validation](#input-validation)
8. [Code Organization](#code-organization)
9. [Logging and Output](#logging-and-output)
10. [Testing and Linting](#testing-and-linting)
11. [Platform Compatibility](#platform-compatibility)
12. [Security](#security)
13. [Command-Line Interface](#command-line-interface)
14. [Common Patterns](#common-patterns)
15. [Code Examples](#code-examples)

---

## Script Length Limits

### Maximum Script Length: 400 Lines

**ABSOLUTE RULE:** No single script file shall exceed **400 lines** of code.

**Rationale:**
- Maintainability: Shorter scripts are easier to understand and modify
- Reusability: Forces extraction of common functionality into libraries
- Testing: Smaller units are easier to test
- Debugging: Reduces cognitive load when troubleshooting

**Enforcement:**
- Count includes comments, blank lines, and all content
- If a script approaches 350 lines, refactor immediately
- Extract common functions to `lib/` directories
- Break complex workflows into multiple coordinated scripts

**How to Refactor Oversized Scripts:**
1. Extract common functions to `lib/common.sh` or domain-specific libraries
2. Break workflows into logical phases (setup, execute, cleanup)
3. Create separate scripts for each phase
4. Use a main orchestrator script to coordinate phases
5. Move complex help/usage functions to separate files if needed

---

## File Structure

### Standard Script Template

```bash
#!/usr/bin/env bash
################################################################################
# Script Name: script-name.sh
################################################################################
# PURPOSE: Brief one-line description of what this script does
# USAGE: ./script-name.sh [OPTIONS] <ARGUMENTS>
# PLATFORM: macOS | Linux | Cross-platform
################################################################################

# Strict error handling
set -euo pipefail

# Source common library (if applicable)
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# source "$SCRIPT_DIR/lib/common.sh"

################################################################################
# Constants
################################################################################

readonly VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"

################################################################################
# Functions
################################################################################

# Function: show_help
# Description: Display help information
show_help() {
    cat << EOF
NAME
    ${SCRIPT_NAME} - Brief description

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS] <ARGUMENTS>

DESCRIPTION
    Detailed description of what the script does.

OPTIONS
    -h, --help      Display this help message
    -v, --verbose   Enable verbose output

EXAMPLES
    ${SCRIPT_NAME} example-arg

SEE ALSO
    related-script.sh

EOF
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse arguments
    # Validate inputs
    # Execute logic
    # Handle cleanup
    :
}

# Execute main function
main "$@"
```

### Directory Structure for Complex Scripts

```
script-project/
├── README.md                 # Documentation
├── main-script.sh           # Entry point (< 400 lines)
├── lib/                     # Shared libraries
│   ├── common.sh           # Common functions
│   └── domain-specific.sh  # Domain logic
├── scripts/                 # Sub-scripts
│   ├── phase1-setup.sh
│   ├── phase2-execute.sh
│   └── phase3-cleanup.sh
└── tests/                   # Test files
    └── test-main.sh
```

---

## Shell Configuration

### Required Settings

Every script **MUST** include:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**Explanation:**
- `set -e`: Exit immediately if any command exits with non-zero status
- `set -u`: Treat unset variables as errors
- `set -o pipefail`: Return failure if any command in pipeline fails

### Optional Settings (Use When Appropriate)

```bash
set -x          # Debug mode (print commands before execution)
shopt -s nullglob  # Globs that match nothing expand to nothing
```

---

## Documentation

### Header Requirements

Every script **MUST** have a header block containing:

1. **Purpose**: What the script does (one line)
2. **Usage**: How to invoke it
3. **Platform**: Target operating system(s)
4. **Dependencies**: External commands/tools required
5. **Author** (optional): Creator/maintainer
6. **Last Updated**: Date of last significant change

### Inline Comments

- **DO**: Explain *why* code exists, not *what* it does
- **DO**: Document non-obvious behavior or edge cases
- **DO**: Add TODO/FIXME comments with context
- **DON'T**: State the obvious (`i++  # increment i`)
- **DON'T**: Leave commented-out code in production

**Good Example:**
```bash
# macOS uses BSD sed, which requires backup extension for -i flag
if is_macos; then
    sed -i '' 's/pattern/replacement/' "$file"
else
    sed -i 's/pattern/replacement/' "$file"
fi
```

**Bad Example:**
```bash
# Set variable to 10
count=10
```

### Function Documentation

Document functions with:
- Purpose
- Parameters
- Return value/exit code
- Side effects (if any)

```bash
# Function: validate_email
# Description: Validates email address format and sanitizes input
# Parameters:
#   $1 - Email address to validate
# Returns:
#   0 - Valid email
#   1 - Invalid format
# Side effects: Writes error to stderr on failure
validate_email() {
    local email="$1"
    [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]
}
```

---

## Naming Conventions

### Files

- Use **lowercase** with **hyphens** for word separation
- Use `.sh` extension for shell scripts
- Be descriptive but concise

**Good:**
- `setup-environment.sh`
- `backup-database.sh`
- `analyze-logs.sh`

**Bad:**
- `SetupEnvironment.sh`
- `setup_environment.sh`
- `script1.sh`

### Variables

```bash
# Global constants: SCREAMING_SNAKE_CASE
readonly MAX_RETRIES=3
readonly CONFIG_DIR="/etc/myapp"

# Global variables: SCREAMING_SNAKE_CASE (avoid when possible)
GLOBAL_STATE="initialized"

# Local variables: snake_case
local retry_count=0
local config_file="config.ini"

# Environment variables: SCREAMING_SNAKE_CASE
export DATABASE_URL="postgresql://localhost/mydb"
```

### Functions

- Use **snake_case** for function names
- Use verb prefixes: `get_`, `set_`, `is_`, `has_`, `validate_`, `check_`
- Be descriptive

**Good:**
```bash
get_user_input()
validate_configuration()
is_file_writable()
log_error()
```

**Bad:**
```bash
GetUserInput()     # Wrong case
validate()         # Too vague
check()            # Too vague
func1()            # Non-descriptive
```

---

## Error Handling

### Required Practices

1. **Always check return codes for critical operations**
2. **Provide actionable error messages**
3. **Clean up resources before exit**
4. **Use trap for cleanup handlers**

### SC2155 - Declare and Assign Separately

**NEVER** combine variable declaration with command substitution:

```bash
# WRONG - Masks command exit code
local result=$(dangerous_command)

# CORRECT - Preserves exit code
local result
result=$(dangerous_command) || {
    log_error "dangerous_command failed"
    return 1
}
```

### Error Message Quality

**Bad:**
```bash
echo "Error" >&2
```

**Good:**
```bash
log_error "Failed to connect to database at ${DB_HOST}:${DB_PORT}"
log_error "Please check: 1) Database is running 2) Credentials are correct 3) Network is accessible"
```

### Cleanup Handlers

```bash
# Set up cleanup trap
cleanup() {
    log_info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    # Restore original state
    # Close open connections
}
trap cleanup EXIT

# For error-specific cleanup
error_cleanup() {
    log_error "Script failed at line $LINENO"
    cleanup
}
trap error_cleanup ERR
```

---

## Input Validation

### Always Validate and Sanitize User Input

**NEVER** trust user input. **ALWAYS** validate format and sanitize for security.

### Required Validations

1. **Check argument count**
2. **Validate format** (emails, URLs, paths, numbers)
3. **Sanitize for command injection**
4. **Check file/directory existence**
5. **Verify permissions**

### Example: Email Validation

```bash
validate_email() {
    local email="$1"

    # Validate format
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log_error "Invalid email format: $email"
        return 1
    fi

    # Sanitize dangerous characters
    email="${email//[;<>\`\$\(\)]/}"

    echo "$email"
    return 0
}
```

### Example: Path Validation

```bash
validate_path() {
    local path="$1"

    # Check if exists
    if [[ ! -e "$path" ]]; then
        log_error "Path does not exist: $path"
        return 1
    fi

    # Check if writable (if needed)
    if [[ ! -w "$path" ]]; then
        log_error "Path is not writable: $path"
        return 1
    fi

    return 0
}
```

### Command Injection Prevention

```bash
# DANGEROUS - Command injection vulnerability
user_input="$1"
eval "$user_input"  # NEVER DO THIS

# SAFE - Use array and proper quoting
files=()
while IFS= read -r -d '' file; do
    files+=("$file")
done < <(find . -type f -print0)

for file in "${files[@]}"; do
    process_file "$file"
done
```

---

## Code Organization

### Function Ordering

1. **Helper/utility functions** (top)
2. **Validation functions**
3. **Core logic functions**
4. **Main/orchestration function** (bottom)

### Group Related Functions

```bash
################################################################################
# Validation Functions
################################################################################

validate_email() { ... }
validate_path() { ... }
validate_url() { ... }

################################################################################
# Database Functions
################################################################################

connect_database() { ... }
query_database() { ... }
close_database() { ... }

################################################################################
# Main Logic
################################################################################

main() { ... }
```

---

## Logging and Output

### Use Consistent Logging Functions

Prefer using standardized logging functions from `lib/common.sh`:

```bash
log_info "Starting backup process..."
log_success "Backup completed successfully"
log_warning "Disk space is running low"
log_error "Failed to connect to remote server"
log_debug "Variable value: $important_var"
```

### Color Usage

- **Use colors for terminal output**
- **Detect if output is to a terminal** (disable colors for pipes/redirects)
- **Use standard color codes from common.sh**

```bash
# Check if output is a terminal
if [[ -t 1 ]]; then
    # Colors enabled
    readonly COLOR_RED='\033[0;31m'
    readonly COLOR_RESET='\033[0m'
else
    # Colors disabled (output is redirected)
    readonly COLOR_RED=''
    readonly COLOR_RESET=''
fi
```

### Log Levels

- `INFO`: General information
- `SUCCESS`: Successful operations
- `WARNING`: Non-fatal issues
- `ERROR`: Fatal errors (write to stderr)
- `DEBUG`: Detailed debugging (only when `DEBUG=1`)

---

## Testing and Linting

### ⚠️ MANDATORY PRE-COMMIT REQUIREMENTS ⚠️

**YOU MUST TEST, VALIDATE, AND LINT ALL CODE CHANGES BEFORE COMMITTING**

This is **NON-NEGOTIABLE**. Do not skip these steps. Do not wait to be asked.

### Required Pre-Commit Steps

Every script change **MUST** complete these steps before commit:

1. ✅ **LINT** - Run shellcheck, fix ALL warnings
2. ✅ **VALIDATE** - Check syntax with `bash -n`
3. ✅ **TEST** - Run with sample data, test edge cases
4. ✅ **VERIFY** - Confirm functionality works as expected

**Zero exceptions. No shortcuts.**

### MANDATORY: Lint Before Commit

**EVERY** script **MUST** pass `shellcheck` with zero warnings before being committed.

```bash
# Lint a single script
shellcheck script-name.sh

# Lint all scripts in repository
find . -type f -name "*.sh" -exec shellcheck {} +

# Lint with specific severity level
shellcheck --severity=warning script-name.sh
```

**Enforcement:**
- **Zero linting errors/warnings allowed before commit**
- Fix all warnings unless explicitly documented
- Do not commit code that doesn't pass linting

### Addressing ShellCheck Warnings

- **Fix ALL warnings** unless you have a documented reason to disable
- **Use inline directives sparingly** and document why:

```bash
# shellcheck disable=SC2034  # Variable used in sourced script
EXPORTED_VAR="value"
```

### MANDATORY: Validate Before Commit

**EVERY** script **MUST** pass syntax validation:

```bash
# Validate syntax
bash -n script-name.sh

# Validate all scripts
find . -type f -name "*.sh" -exec bash -n {} \; -print
```

**What to validate:**
- Syntax correctness (`bash -n`)
- All sourced files exist and are accessible
- All required commands/dependencies documented
- Edge cases handled (empty inputs, special characters)

### MANDATORY: Test Before Commit

Before claiming a script is "done":

1. ✅ **Run the script** with sample/test data
2. ✅ **Test error cases** (invalid inputs, missing files, network failures)
3. ✅ **Test on target platform** (macOS/Linux as appropriate)
4. ✅ **Verify cleanup** (temp files removed, state restored)
5. ✅ **Test edge cases** (filenames with spaces, empty inputs, etc.)
6. ✅ **Verify all functions** work as expected

**Testing Workflow:**

```bash
# 1. Syntax check
bash -n my-script.sh

# 2. Lint
shellcheck my-script.sh

# 3. Test with sample data
echo "test input" | ./my-script.sh --dry-run

# 4. Test error handling
./my-script.sh /nonexistent/path  # Should fail gracefully

# 5. Test on target platform
if is_macos; then
    # Test BSD-specific commands
    echo "sample data" | sed -i '' 's/old/new/' /tmp/test.txt
fi
```

### Platform-Specific Testing

**macOS uses BSD tools, NOT GNU tools**. Always test platform-specific commands:

```bash
# Test awk/sed/grep commands in isolation BEFORE committing
echo "sample data" | awk '{print $1}'
echo "sample data" | sed 's/sample/test/'

# macOS uses BSD tools - test before committing
if is_macos; then
    # BSD sed requires backup extension for -i flag
    sed -i '' 's/pattern/replacement/' "$file"
else
    # GNU sed
    sed -i 's/pattern/replacement/' "$file"
fi

# ALWAYS test awk/sed/grep with sample data first:
echo "test123" | grep -o '[0-9]\+' # Test before using in script
```

**Testing Checklist:**

- [ ] Script passes `shellcheck` with zero warnings
- [ ] Script passes `bash -n` syntax check
- [ ] Tested with valid sample data
- [ ] Tested with invalid/edge case inputs
- [ ] Tested on target platform (macOS/Linux)
- [ ] Verified cleanup (no temp files left behind)
- [ ] Documented any platform-specific behavior
- [ ] All sourced files exist and are valid

**DO NOT commit until ALL items are checked.**

---

## Platform Compatibility

### Apple Silicon (ARM64) Considerations

This repository targets **Apple Silicon** (ARM64) hardware:

- Homebrew path: `/opt/homebrew/` (NOT `/usr/local/`)
- Verify architecture: `uname -m` returns `arm64`

### macOS vs Linux Differences

#### macOS Uses BSD Tools, NOT GNU

**Critical:** macOS ships with BSD versions of common tools that have different syntax than GNU versions.

**Common Gotchas:**

```bash
# awk: BSD awk does NOT support match() with array capture
# BAD (GNU-only)
echo "test" | awk 'match($0, /t(e)st/, arr) {print arr[1]}'

# GOOD (Portable)
echo "test" | grep -o 'e' | head -1

# sed: BSD sed requires backup extension for in-place edit
# macOS
sed -i '' 's/old/new/' file.txt

# Linux
sed -i 's/old/new/' file.txt

# Portable solution
if is_macos; then
    sed -i '' 's/old/new/' "$file"
else
    sed -i 's/old/new/' "$file"
fi
```

### Use Platform Detection Functions

```bash
is_macos() {
    [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
    [[ "$(uname -s)" == "Linux" ]]
}

# Use in code
if is_macos; then
    # macOS-specific code
elif is_linux; then
    # Linux-specific code
fi
```

---

## Security

### Input Sanitization

**ALWAYS** sanitize user input before using in commands:

```bash
# Remove dangerous shell metacharacters
sanitize_input() {
    local input="$1"
    # Remove: ; < > ` $ ( ) | & space
    echo "${input//[;<>\`\$\(\)\|&[:space:]]/}"
}

user_input=$(sanitize_input "$1")
```

### Avoid eval

**NEVER** use `eval` with user input:

```bash
# DANGEROUS
eval "$user_input"

# SAFE - Use functions or case statements
case "$user_input" in
    start) start_service ;;
    stop)  stop_service ;;
    *)     log_error "Invalid command" ;;
esac
```

### File Handling

```bash
# Handle filenames with spaces/special characters
while IFS= read -r -d '' file; do
    process_file "$file"
done < <(find . -type f -print0)

# NOT THIS (breaks on spaces)
for file in $(find . -type f); do
    process_file "$file"  # BREAKS
done
```

### Temporary Files

```bash
# Use mktemp for temporary files
TEMP_FILE=$(mktemp) || die "Failed to create temp file"
trap 'rm -f "$TEMP_FILE"' EXIT

# Use mktemp -d for temporary directories
TEMP_DIR=$(mktemp -d) || die "Failed to create temp directory"
trap 'rm -rf "$TEMP_DIR"' EXIT
```

---

## Command-Line Interface

### MANDATORY: Help Flag Support

**ABSOLUTE RULE:** Every script **MUST** implement `-h` and `--help` flags.

**Requirements:**
1. Both `-h` and `--help` must be supported
2. Help output must follow man-page style format
3. Help must be accessible without requiring other arguments
4. Help flag must exit with status code 0
5. Help must be comprehensive and include all options

**Man-Page Style Format (MANDATORY):**

```bash
show_help() {
    cat << EOF
NAME
    $(basename "$0") - Brief one-line description

SYNOPSIS
    $(basename "$0") [OPTIONS] <ARGUMENTS>

DESCRIPTION
    Detailed description of what the script does.
    Can span multiple paragraphs if needed.

OPTIONS
    -h, --help
        Display this help message and exit

    -v, --verbose
        Enable verbose output

    -o, --output FILE
        Specify output file (default: stdout)

ARGUMENTS
    INPUT_FILE
        Path to input file (required)

EXAMPLES
    $(basename "$0") file.txt
        Process file.txt with default options

    $(basename "$0") --verbose --output result.txt input.txt
        Process input.txt with verbose output to result.txt

EXIT STATUS
    0   Success
    1   General error
    2   Invalid arguments

ENVIRONMENT
    DEBUG=1
        Enable debug output

SEE ALSO
    related-script.sh(1), documentation-url

AUTHOR
    Your Name or Organization

EOF
}
```

**Minimal Acceptable Format:**

At minimum, help output must include:
- NAME: Script name and brief description
- SYNOPSIS: Usage syntax
- DESCRIPTION: What the script does
- OPTIONS: List of all options with descriptions
- EXAMPLES: At least one usage example

**Argument Parsing with Help:**

```bash
# Parse arguments - help must come first
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done
```

**Testing Help Output:**

```bash
# Verify help is accessible
./script.sh --help
./script.sh -h

# Should exit with 0
echo $?  # Should be 0

# Should not require other arguments
./script.sh --help  # Works even without required args
```

**Enforcement:**
- Scripts without help flags will be rejected in code review
- Help output must be tested before committing
- Use `show_help()` function for consistency
- Keep help text up-to-date with script changes

---

## Common Patterns

### Argument Parsing

```bash
show_help() {
    echo "Usage: $0 [OPTIONS] <arg>"
    echo "Options:"
    echo "  -h, --help     Show help"
    echo "  -v, --verbose  Verbose output"
}

# Parse options
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -*)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
        *)
            # Positional argument
            ARG="$1"
            shift
            ;;
    esac
done
```

### Progress Indicators

```bash
# Simple counter
total=100
for i in $(seq 1 $total); do
    echo -ne "Processing: $i/$total\r"
    # do work
done
echo ""  # New line after progress

# Percentage
current=0
total=100
while [[ $current -lt $total ]]; do
    percentage=$((current * 100 / total))
    echo -ne "Progress: ${percentage}%\r"
    # do work
    ((current++))
done
echo ""
```

### Retry Logic

```bash
retry_command() {
    local max_attempts=3
    local timeout=2
    local attempt=1
    local exit_code=0

    while [[ $attempt -le $max_attempts ]]; do
        if command_to_retry; then
            return 0
        else
            exit_code=$?
            log_warning "Attempt $attempt failed, retrying in ${timeout}s..."
            sleep $timeout
            ((attempt++))
            timeout=$((timeout * 2))  # Exponential backoff
        fi
    done

    log_error "Command failed after $max_attempts attempts"
    return $exit_code
}
```

### Configuration File Loading

```bash
load_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Config file not found: $config_file"
        return 1
    fi

    # Source config with validation
    # shellcheck source=/dev/null
    source "$config_file" || {
        log_error "Failed to load config: $config_file"
        return 1
    }

    # Validate required variables
    require_var "DATABASE_URL" || return 1
    require_var "API_KEY" || return 1

    return 0
}

require_var() {
    local var_name="$1"
    if [[ -z "${!var_name:-}" ]]; then
        log_error "Required variable not set: $var_name"
        return 1
    fi
}
```

---

## Code Examples

### Complete Script Example

See [`examples/template-script.sh`](examples/template-script.sh) for a complete, production-ready script template.

### Library Usage Example

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

main() {
    log_header "Starting Application Setup"

    # Validate prerequisites
    require_command "git" "brew install git"
    require_command "node" "brew install node"

    # Check platform
    if is_macos; then
        log_info "Running on macOS"
    else
        die "This script requires macOS"
    fi

    # Execute with error handling
    if ask_yes_no "Install dependencies?" "y"; then
        log_section "Installing Dependencies"
        npm install || die "npm install failed"
        log_success "Dependencies installed"
    fi

    log_success "Setup complete!"
}

main "$@"
```

---

## Enforcement

### Pre-Commit Checklist

Before creating a pull request, verify:

- [ ] All scripts pass `shellcheck` with zero warnings
- [ ] No script exceeds 400 lines
- [ ] All functions have documentation
- [ ] Error handling is comprehensive
- [ ] Input validation is present
- [ ] Code has been tested on target platform
- [ ] Temporary files/resources are cleaned up
- [ ] Commit messages are descriptive

### AI Assistant Instructions

**Claude Code / Google Gemini:**

When writing or modifying shell scripts in this repository:

1. Read and internalize this entire style guide
2. Follow ALL rules without exception
3. Lint your code with shellcheck before claiming completion
4. Test your code with sample data where possible
5. If a script approaches 350 lines, refactor immediately
6. Never commit code that doesn't pass linting
7. Ask questions if platform-specific behavior is unclear

**If you violate these standards, your code will be rejected.**

---

## Version History

| Version | Date       | Changes                          |
|---------|------------|----------------------------------|
| 1.0     | 2025-11-16 | Initial style guide creation     |

---

## References

- [ShellCheck](https://www.shellcheck.net/) - Shell script linting tool
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [Bash Reference Manual](https://www.gnu.org/software/bash/manual/)
- [BSD vs GNU Tools](https://ponderthebits.com/2017/01/know-your-tools-linux-gnu-vs-mac-bsd-command-line-utilities-grep-strings-sed-and-find/)

---

## Questions or Clarifications

If you encounter edge cases not covered in this guide, please:

1. Consult with the repository maintainer
2. Document the decision in this guide
3. Add examples for future reference

**This is a living document. Keep it updated as new patterns emerge.**
