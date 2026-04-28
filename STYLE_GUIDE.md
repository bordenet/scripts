# Shell Script Style Guide

**Version:** 2.3 | **Last Updated:** 2026-02-05

> This is the **canonical source** for shell scripting standards across all bordenet projects.

---

## Quick Navigation

> **For AI Agents**: Load only the section you need to minimize context usage.

| Section | Contents |
|---------|----------|
| [Quick Reference](./style-guide/quick-reference.md) | 8 rules to memorize, common mistakes, naming conventions |
| [Symlink Resolution](./style-guide/symlink-resolution.md) | **CRITICAL** - Library sourcing patterns |
| [Error Handling](./style-guide/error-handling.md) | set -euo pipefail, surviving strict mode |
| [UX & CLI](./style-guide/ux-and-cli.md) | Documentation, logging, CLI interface contract |
| [Testing & Security](./style-guide/testing-and-security.md) | Linting, platform compatibility, security |

---

## Summary

This style guide defines **universal shell scripting standards** for all bordenet projects. Goals:

- **Safe**: Defensive error handling, validated inputs
- **Readable**: Clear structure, boring naming
- **Predictable**: Consistent patterns across all scripts
- **Portable**: Platform-aware (macOS/Linux), handles BSD/GNU differences

## Key Rules

1. **400-line limit** - Refactor into `lib/` modules
2. **Zero ShellCheck warnings** - `shellcheck --severity=warning`
3. **Required flags** - All scripts implement `-h/--help` and `-v/--verbose`
4. **Error handling** - `set -euo pipefail` with proper trap cleanup

---

**Reference:** [GitLab Shell Scripting Guide](https://docs.gitlab.com/development/shell_scripting_guide/)
