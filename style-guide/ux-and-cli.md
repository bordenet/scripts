# Shell Script Style Guide: UX, Logging & CLI Interface

> Part of [SHELL_SCRIPT_STYLE_GUIDE.md](../SHELL_SCRIPT_STYLE_GUIDE.md)

---

## Documentation and Discoverability

Every script is self-documenting and friendly for both humans and AI assistants.

**Header must include:**
- **PURPOSE:** one crisp sentence
- **USAGE:** how to run the script
- **PLATFORM:** macOS, Linux, or both
- **DEPENDENCIES:** external tools (brew, git, jq, etc.)
- **AUTHOR** (optional) and Last Updated

**Inline comments:**
- Focus on WHY and trade-offs, not obvious "what"
- Document non-obvious platform differences (e.g., BSD sed vs GNU sed)
- Use TODO/FIXME with enough context for another contributor

**Functions:**
- Brief comment block for purpose, parameters, exit codes, and side effects

---

## Logging, Output, and Terminal UX

Console output is opinionated and user-centric.

**Default mode:**
- Minimal, compact lines updated in place using ANSI escape codes
- Ideal for CI logs and repeated runs

**Verbose mode (-v/--verbose):**
- Rich INFO-level logs, details about decisions, and multi-line context
- Great for debugging and AI-assisted troubleshooting

**Core UX requirements:**
- Use shared logging helpers: `log_info`, `log_success`, `log_warning`, `log_error`, `log_debug`, `log_section`
- Detect whether output is a TTY; disable color when piping or redirecting
- Use ANSI escape codes for in-place progress updates

**Long-running scripts must:**
- Start a wall-clock timer process at script start
- Display it as `[HH:MM:SS]` in yellow-on-black in the top-right corner
- Stop it cleanly via trap, then print total execution time at exit

---

## Command-Line Interface Contract

Every script behaves like a well-behaved CLI tool.

**-h and --help must:**
- Be available without any other arguments
- Exit 0 and never modify state
- Provide man-style sections: NAME, SYNOPSIS, DESCRIPTION, OPTIONS, ARGUMENTS, EXAMPLES, EXIT STATUS, ENVIRONMENT, SEE ALSO, AUTHOR

**-v and --verbose must:**
- Control INFO and DEBUG visibility
- Enable detailed logs without changing semantics

**Unknown options must:**
- Produce a clear error message
- Point the user to `--help`
- Exit with a non-zero status

---

## Input Validation and Security

Treat all input as hostile until proven otherwise.

- Validate argument count early; fail fast with helpful usage hints
- Validate formats for emails, URLs, paths, and numeric values
- Sanitize input when used in shell commands to avoid injection
- Never use `eval` on user input or untrusted data
- Always handle filenames and paths safely using null-terminated lists

Use helpers like `validate_email`, `validate_path`, and `sanitize_input` to keep core logic focused and readable.

