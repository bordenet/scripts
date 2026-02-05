# Shell Script Style Guide: Testing, Security & Platform Compatibility

> Part of [SHELL_SCRIPT_STYLE_GUIDE.md](../SHELL_SCRIPT_STYLE_GUIDE.md)

---

## Testing, Linting, and Pre-Commit Discipline

Every change goes through the same predictable pipeline:

1. **Syntax:** `bash -n script.sh`
2. **Lint:** `shellcheck --severity=warning script.sh` with zero warnings
3. **Functional testing:**
   - With representative "happy path" inputs
   - With edge cases (empty inputs, weird filenames, missing resources, network failures)
   - On target platforms (macOS vs Linux), particularly for sed/awk/grep

Have a repeatable `validate-script-compliance.sh` helper that can validate a single script, all scripts, and emit a compliance report.

**Only commit after all checks pass.** Scripts that do not lint, validate, and test cleanly are not eligible for code review.

---

## Platform Compatibility

Default to portability, then layer platform-specific behavior where necessary.

- Always use `is_macos` and `is_linux` helpers before branching into platform-specific code
- Handle BSD vs GNU tooling explicitly, particularly `sed -i`, `date`, and regex support
- Assume Apple Silicon macOS for Homebrew paths (`/opt/homebrew`) and document any x86-only caveats

When in doubt, test the exact sed/awk/grep incantation in isolation on the target platform.

---

## Security Expectations

Security is a first-class concern, not an afterthought.

- Never use `eval` with user-controlled data
- Use `mktemp` for temporary files and directories, and ensure cleanup via trap
- Avoid brittle constructs like `for file in $(find ...)` that break with spaces
- Quote variables by default and only deviate when absolutely necessary

The goal is to make it very hard to introduce command injection, data leaks, or privilege escalation.

---

## Code Organization and Libraries

Organize code for reuse and clarity:

- Group related functions with section headers (validation, IO, domain logic, etc.)
- Keep helpers and utilities at the top, orchestration at the bottom
- Extract reusable behavior (logging, timers, platform detection, input validation) into `lib/common.sh` or domain-specific libraries

This lets new scripts come together quickly by composing existing, well-tested helpers.

---

## Enforcement and AI Assistant Instructions

For humans and AI assistants:

1. Read this entire guide once, then refer to it often
2. Follow all rules without exception unless the guide itself is updated
3. Treat ShellCheck, bash -n, and the compliance script as non-negotiable gates
4. Ask questions when platform or security behavior is unclear
5. When in doubt, choose the safer, more explicit, and more testable option

---

## Reference Sources

1. [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
2. [ShellCheck – shell script analysis tool](https://www.shellcheck.net)
3. [ShellCheck GitHub](https://github.com/koalaman/shellcheck)
4. [ANSI escape code standards - Julia Evans](https://jvns.ca/blog/2025/03/07/escape-code-standards/)
5. [Build your own Command Line with ANSI escape codes](https://www.lihaoyi.com/post/BuildyourownCommandLinewithANSIescapecodes.html)
6. [Terminal escape codes - Orel Fichman](https://orelfichman.com/blog/terminal-escape-codes-are-awesome)
7. [GoatBytes Shell Style Guide](https://styles.goatbytes.io/lang/shell/)
8. [GitLab Shell Scripting Guide](https://docs.gitlab.com/development/shell_scripting_guide/)

---

## Patterns and Learning by Copying

Favor a small number of "golden" scripts as exemplars and keep them meticulously aligned with this guide:

- `bu.sh`
- `scorch-repo.sh`
- `purge-identity.sh`

Contributors and AI tools should copy patterns from those scripts rather than improvising.

