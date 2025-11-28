## Shell Script Style Guide

Version: 2.1
Last Updated: 2025-11-28
Audience: AI coding assistants (Claude Code, Gemini, ChatGPT) and human developers
Source: https://github.com/bordenet/scripts/blob/main/STYLE_GUIDE.md

This style guide is the single source of truth for all shell scripts in this repository. The goal is simple: every script should be safe, readable, predictable, and a pleasure to use and extend. These standards are mandatory for all contributors.

***

## Quick Reference

Memorize these rules before writing anything:

1. 400-line limit  
   - Any script approaching 350 lines must be refactored into libraries under lib/.  
   - Short, focused scripts are easier to debug, test, and reuse.

2. Zero ShellCheck noise  
   - All scripts must pass ShellCheck with zero warnings at severity warning and above. [1][2][3]
   - If a warning is intentionally suppressed, document why with a ShellCheck directive.

3. Required flags (-h/--help, -v/--verbose)  
   - Every script implements both -h/--help and -v/--verbose.  
   - Help is man-page style, comprehensive, and callable without any other arguments.

4. UX: Smart console output and timer  
   - Non-verbose mode is compact and overwrites in place using ANSI escape codes. [4][5][6][7]
   - Verbose mode shows rich INFO-level logs and detailed progress.  
   - Scripts expected to run >10 seconds or with deferred actions must show a yellow-on-black wall clock timer in the top-right corner plus total execution time at exit.

5. Defensive error handling  
   - All scripts start with:  
     - `#!/usr/bin/env bash`  
     - `set -euo pipefail` [1][8][9]
   - Critical operations must check return codes and use trap-based cleanup for temporary state.

6. Relentless input validation  
   - Validate argument count, types, formats, paths, and permissions.  
   - Never trust user input; sanitize to prevent command injection.

7. Platform-aware, portable by default  
   - Use is_macos/is_linux helpers and handle BSD vs GNU differences explicitly (e.g., sed -i behavior). [1][8][10][9]
   - Default to Apple Silicon macOS but keep Linux paths and differences well-documented.

8. Always test before commit  
   - shellcheck (zero warnings), bash -n, and functional testing with sample and edge-case data. [1][2][3]
   - Scripts that are not tested are not considered “done.”

Common mistakes to avoid:

- Do not combine declaration and command substitution for locals (e.g., `local x=$(cmd)`).
- Do not loop over `$(find ...)`; use `-print0` and `while read -r -d ''` instead.
- Never pass user input to eval.
- Do not use raw echo for user-facing status; use logging helpers.
- Avoid hardcoded paths; use SCRIPT_DIR and repo-root helpers.
- **Do not set SCRIPT_DIR without symlink resolution** if your script sources libraries (see "Library Sourcing and Symlink Resolution" section).
- Never silence errors with `|| true` unless there is a documented, explicit reason.

***

## Script Size and Structure

Goal: Every script should read like a clear story, not a tangle.

- Hard cap: 400 lines including comments and blank lines.  
- At ~350 lines, refactor immediately into:  
  - lib/common.sh for shared utilities.  
  - lib/<domain>.sh for domain-specific helpers.  
  - Small, focused sub-scripts for distinct workflow phases.

Recommended layout for a “real” script:

1. Shebang and strict mode (`#!/usr/bin/env bash`, `set -euo pipefail`).
2. Metadata constants (VERSION, SCRIPT_NAME).
3. Symlink resolution and library sourcing (SCRIPT_DIR with symlink resolution + lib/…).
4. Logging, UX, and timer helpers.
5. Validation helpers.
6. Core domain functions.
7. Argument parsing and CLI wiring.
8. main() as the orchestrator at the bottom.

Use a project structure like:

- main-script.sh (entry point, <400 lines)  
- lib/ (shared logic)  
- scripts/ (phase and utility scripts)  
- tests/ (automated and manual test harnesses)

This structure aligns with other professional shell style guides and makes it easy to onboard new contributors. [1][8][9]

***

## Shell Configuration and Safety Defaults

Every script must start with:

- `#!/usr/bin/env bash`  
- `set -euo pipefail`

These defaults:

- Fail fast on errors.  
- Treat unset variables as bugs instead of silently continuing.  
- Propagate errors through pipelines.

Optional but encouraged:

- `set -x` when debugging locally (never committed enabled).  
- `shopt -s nullglob` when globbing on possibly-empty patterns is expected.

For scripts that intentionally relax strictness, document the rationale in comments near the configuration line.

***

## Library Sourcing and Symlink Resolution

**CRITICAL**: Scripts that source library files MUST resolve symlinks to find their actual location. This allows scripts to work correctly when called via symlinks or aliases from anywhere in the filesystem.

### Required Pattern

All scripts that source libraries must use this pattern **before** any `source` statements:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Source library functions
# Resolve symlinks to get actual script location
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

# Now source libraries using resolved SCRIPT_DIR
# shellcheck source=lib/my-lib.sh
source "$SCRIPT_DIR/lib/my-lib.sh"
```

### Why This Matters

Without symlink resolution, `SCRIPT_DIR` points to the symlink's location, not the actual script location. This breaks library sourcing when scripts are:

- Symlinked from parent directories (common pattern for organizing nested repos)
- Aliased in shell configuration
- Called via symlinks in PATH directories
- Invoked from different working directories

### What This Pattern Does

1. **Follows the symlink chain**: Resolves through multiple levels of symlinks
2. **Handles relative symlinks**: Converts relative paths to absolute paths
3. **Finds the real script**: Locates the actual script file, not the symlink
4. **Sets SCRIPT_DIR correctly**: Points to the directory containing the real script

### Examples

```bash
# ✅ CORRECT - Resolves symlinks before sourcing
SCRIPT_PATH="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_PATH" ]; do
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    SCRIPT_PATH="$(readlink "$SCRIPT_PATH")"
    [[ "$SCRIPT_PATH" != /* ]] && SCRIPT_PATH="$SCRIPT_DIR/$SCRIPT_PATH"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ❌ WRONG - Breaks when script is called via symlink
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
```

### Testing Symlink Support

Always test scripts via symlinks before committing:

```bash
# Create test symlink in /tmp
cd /tmp
ln -s /path/to/actual/script.sh test-script.sh

# Test that library loading works
bash test-script.sh --help

# Should display help without "No such file or directory" errors
```

### Reference Implementation

See these scripts for working examples:
- `bu.sh`
- `mu.sh`
- `fetch-github-projects.sh`
- `integrate-claude-web-branch.sh`
- `scorch-repo.sh`

***

## Documentation and Discoverability

Every script is self-documenting and friendly for both humans and AI assistants.

Header must include:

- PURPOSE: one crisp sentence.  
- USAGE: how to run the script.  
- PLATFORM: macOS, Linux, or both.  
- DEPENDENCIES: external tools (brew, git, jq, etc.).  
- AUTHOR (optional) and Last Updated.

Inline comments:

- Focus on WHY and trade-offs, not obvious “what.”  
- Document non-obvious platform differences (e.g., BSD sed vs GNU sed). [1][8][10]
- Use TODO/FIXME with enough context for another contributor (or AI) to finish the work confidently.

Functions:

- Brief comment block for purpose, parameters, exit codes, and side effects.  
- Make it easy for a reader to decide whether to call, modify, or extract the function.

***

## Naming and Conventions

Names should be boring, predictable, and descriptive.

- Files: lowercase-hyphen-separated, .sh extension.  
- Constants and globals: SCREAMING_SNAKE_CASE with readonly where possible.  
- Local variables and functions: snake_case.  
- Environment variables: SCREAMING_SNAKE_CASE and exported explicitly.

Prefer verb-based prefixes for functions: get_, set_, is_, has_, validate_, log_, require_, etc. This matches guidance from other shell style guides and reduces cognitive load when scanning. [1][8]

***

## Error Handling and Cleanup

Error handling is explicit, intentional, and actionable.

- Always check exit codes for critical operations.  
- use trap-based cleanup (EXIT, ERR) for temporary files, directories, and state.  
- Error messages must tell the user what went wrong and how to fix it, not just “Error.”

Do not:

- Hide exit codes by combining declaration + assignment from a command.  
- Rely on `|| true` without very clear justification.  
- Leave temporary files or partial state behind after failure.

Where appropriate, differentiate between “recoverable warnings” and “hard failures,” and reflect that in both log levels and exit status.

***

## Input Validation and Security

Treat all input as hostile until proven otherwise.

- Validate argument count early; fail fast with helpful usage hints.  
- Validate formats for emails, URLs, paths, and numeric values with regex or dedicated helpers.  
- Sanitize input when used in shell commands to avoid injection.  
- Never use eval on user input or untrusted data.  
- Always handle filenames and paths safely using null-terminated lists and proper quoting.

Use helpers like validate_email, validate_path, and sanitize_input to keep core logic focused and readable.

***

## Code Organization and Libraries

Organize code for reuse and clarity:

- Group related functions with section headers (validation, IO, domain logic, etc.).  
- Keep helpers and utilities at the top, orchestration at the bottom.  
- Extract reusable behavior (logging, timers, platform detection, input validation) into lib/common.sh or domain-specific libraries.

This lets new scripts come together quickly by composing existing, well-tested helpers.

***

## Logging, Output, and Terminal UX

Console output is opinionated and user-centric.

- Default mode:
  - Minimal, compact lines updated in place using ANSI escape codes. [4][5][6][7]
  - Ideal for CI logs and repeated runs.  
- Verbose mode (-v/--verbose):
  - Rich INFO-level logs, details about decisions, and multi-line context.  
  - Great for debugging, understanding flow, and AI-assisted troubleshooting.

Core UX requirements:

- Use shared logging helpers: log_info, log_success, log_warning, log_error, log_debug, log_section, etc.  
- Detect whether output is a TTY; disable color when piping or redirecting. [1][8][4]
- Use ANSI escape codes for:
  - In-place progress updates.  
  - Compact “dashboard-like” displays.  
  - A top-right wall-clock timer for long-running or deferred scripts.

All long-running scripts must:

- Start a wall-clock timer process at script start.  
- Display it as [HH:MM:SS] in yellow-on-black in the top-right corner.  
- Stop it cleanly via trap, then print total execution time at exit.

Choose ANSI sequences that are widely supported and avoid terminal-specific tricks where possible; rely on tools like tput where it improves portability. [4][5][6][7][11]

***

## Testing, Linting, and Pre-Commit Discipline

Every change goes through the same predictable pipeline:

1. Syntax: `bash -n script.sh`.  
2. Lint: `shellcheck --severity=warning script.sh` with zero warnings. [1][2][3]
3. Functional testing:
   - With representative “happy path” inputs.  
   - With edge cases (empty inputs, weird filenames, missing resources, network failures).  
   - On target platforms (macOS vs Linux), particularly for sed/awk/grep. [1][8][10][9]

Have a repeatable `validate-script-compliance.sh` helper that can validate a single script, all scripts, and emit a compliance report. Align its checks with this guide and with established shell standards. [1][8][9]

Only commit after all checks pass. Scripts that do not lint, validate, and test cleanly are not eligible for code review.

***

## Platform Compatibility

Default to portability, then layer platform-specific behavior where necessary.

- Always use is_macos and is_linux helpers before branching into platform-specific code.  
- Handle BSD vs GNU tooling explicitly, particularly sed -i, date, and regex support. [1][8][10][9]
- Assume Apple Silicon macOS for Homebrew paths (/opt/homebrew) and document any x86-only or Rosetta caveats.

When in doubt, test the exact sed/awk/grep incantation in isolation on the target platform before baking it into a script.

***

## Security Expectations

Security is a first-class concern, not an afterthought.

- Never use eval with user-controlled data.  
- Use mktemp for temporary files and directories, and ensure cleanup via trap.  
- Avoid brittle constructs like `for file in $(find ...)` that break with spaces and special characters.  
- Quote variables by default and only deviate when absolutely necessary and documented. [1][8][12]

The goal is to make it very hard to introduce command injection, data leaks, or privilege escalation via these scripts.

***

## Command-Line Interface Contract

Every script behaves like a well-behaved CLI tool.

- -h and --help must:
  - Be available without any other arguments.  
  - Exit 0 and never modify state.  
  - Provide man-style sections: NAME, SYNOPSIS, DESCRIPTION, OPTIONS, ARGUMENTS, EXAMPLES, EXIT STATUS, ENVIRONMENT, SEE ALSO, AUTHOR.  
- -v and --verbose must:
  - Control INFO and DEBUG visibility.  
  - Enable detailed logs without changing semantics.

Unknown options must:

- Produce a clear error message.  
- Point the user to --help.  
- Exit with a non-zero status.

This gives humans and AI assistants a consistent, discoverable interface across the entire script library.

***

## Patterns, Examples, and Learning by Copying

Favor a small number of “golden” scripts as exemplars (bu.sh, scorch-repo.sh, purge-identity.sh, etc.) and keep them meticulously aligned with this guide. Contributors and AI tools should copy patterns from those scripts rather than improvising.

Where appropriate, cross-link external references for deeper reading (e.g., Google Shell Style Guide, ShellCheck docs, and BSD vs GNU tool differences). [1][8][10][2][9]

***

## Enforcement and AI Assistant Instructions

For humans and AI assistants:

- Read this entire guide once, then refer to it often.  
- Follow all rules without exception unless the guide itself is updated.  
- Treat ShellCheck, bash -n, and the compliance script as non-negotiable gates. [1][2][3]
- Ask questions (via issues, comments, or prompts) when platform or security behavior is unclear.  
- When in doubt, choose the safer, more explicit, and more testable option.

This repository is designed so that anyone can clone, run, and extend these scripts with confidence. The style guide is the contract that makes that possible.

Sources
[1] Shell Style Guide - Google https://google.github.io/styleguide/shellguide.html
[2] ShellCheck – shell script analysis tool https://www.shellcheck.net
[3] ShellCheck, a static analysis tool for shell scripts - GitHub https://github.com/koalaman/shellcheck
[4] Standards for ANSI escape codes - Julia Evans https://jvns.ca/blog/2025/03/07/escape-code-standards/
[5] Build your own Command Line with ANSI escape codes https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html
[6] Terminal escape codes are awesome, here's why - Orel Fichman https://orelfichman.com/blog/terminal-escape-codes-are-awesome
[7] ANSI Escape Codes - BIT-101 [2017-2023] https://www.bit-101.com/2017/2022/11/ansi-escape-codes/
[8] Shell Style Guide - GoatStyles https://styles.goatbytes.io/lang/shell/
[9] Shell scripting standards and style guidelines - GitLab Docs https://docs.gitlab.com/development/shell_scripting_guide/
[10] 4. Google Shell Style Guide — IFS Shell Standard documentation https://sites.ecmwf.int/docs/ifs-arpege-coding-standards/shell/guidelines/google.html
[11] ANSI escape code - Wikipedia https://en.wikipedia.org/wiki/ANSI_escape_code
[12] SC2034 – foo appears unused. Verify it or export it. - ShellCheck https://www.shellcheck.net/wiki/SC2034
[13] Tutorial style guide | Cloud Shell - Google Cloud Documentation https://docs.cloud.google.com/shell/docs/cloud-shell-tutorials/style-guide
[14] Google's bash style guide : r/programming - Reddit https://www.reddit.com/r/programming/comments/8jm85w/googles_bash_style_guide/
[15] Bash Script BEST Practices You Need to Know, According to Google https://www.youtube.com/watch?v=Y_erZnIhgKg
[16] How to suppress irrelevant ShellCheck messages? - Stack Overflow https://stackoverflow.com/questions/52659038/how-to-suppress-irrelevant-shellcheck-messages
[17] Google Style Guides | styleguide https://google.github.io/styleguide/
[18] When do you disagree with ShellCheck? : r/bash - Reddit https://www.reddit.com/r/bash/comments/w66500/when_do_you_disagree_with_shellcheck/
[19] Everything you never wanted to know about ANSI escape codes https://www.reddit.com/r/programming/comments/lbmbnm/everything_you_never_wanted_to_know_about_ansi/
[20] Personal Bash coding style guide - foo.zone https://foo.zone/gemfeed/2021-05-16-personal-bash-coding-style-guide.html
