# Shell Script Style Guide: Quick Reference

> Part of [SHELL_SCRIPT_STYLE_GUIDE.md](../SHELL_SCRIPT_STYLE_GUIDE.md)

---

## 8 Rules to Memorize

1. **400-line limit** - Refactor at ~350 lines into libraries under `lib/`
2. **Zero ShellCheck noise** - Pass with zero warnings at severity warning+
3. **Required flags** - `-h/--help` and `-v/--verbose` in every script
4. **Smart console output** - Compact in non-verbose, rich logs in verbose
5. **Defensive error handling** - `set -euo pipefail` and trap-based cleanup
6. **Relentless input validation** - Never trust user input
7. **Platform-aware** - Handle BSD vs GNU differences explicitly
8. **Always test** - shellcheck + bash -n + functional testing before commit

---

## Common Mistakes to Avoid

- ❌ Don't combine declaration and command substitution: `local x=$(cmd)`
- ❌ Don't loop over `$(find ...)`; use `-print0` and `while read -r -d ''`
- ❌ Never pass user input to `eval`
- ❌ Don't use raw `echo` for status; use logging helpers
- ❌ Avoid hardcoded paths; use `SCRIPT_DIR` and repo-root helpers
- ❌ Don't set `SCRIPT_DIR` without symlink resolution
- ❌ Never silence errors with `|| true` without documented reason

---

## Required Script Header

```bash
#!/usr/bin/env bash
set -euo pipefail

VERSION="1.0.0"
SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
```

---

## Recommended Script Layout

1. Shebang and strict mode
2. Metadata constants (VERSION, SCRIPT_NAME)
3. Symlink resolution and library sourcing
4. Logging, UX, and timer helpers
5. Validation helpers
6. Core domain functions
7. Argument parsing and CLI wiring
8. `main()` as the orchestrator at the bottom

---

## Recommended Project Structure

```
main-script.sh    # Entry point, <400 lines
lib/              # Shared logic
scripts/          # Phase and utility scripts
tests/            # Automated and manual test harnesses
```

---

## Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | lowercase-hyphen-separated.sh | `deploy-web.sh` |
| Constants/Globals | SCREAMING_SNAKE_CASE | `readonly MAX_RETRIES=3` |
| Local variables | snake_case | `local file_count=0` |
| Functions | snake_case with verb prefix | `get_`, `set_`, `is_`, `validate_` |
| Environment vars | SCREAMING_SNAKE_CASE + export | `export API_KEY="..."` |

