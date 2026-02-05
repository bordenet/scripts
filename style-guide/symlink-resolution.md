# Shell Script Style Guide: Library Sourcing & Symlink Resolution

> Part of [SHELL_SCRIPT_STYLE_GUIDE.md](../SHELL_SCRIPT_STYLE_GUIDE.md)

---

## CRITICAL: Symlink Resolution Required

Scripts that source library files **MUST** resolve symlinks to find their actual location. This allows scripts to work correctly when called via symlinks or aliases.

---

## Required Pattern

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

---

## Why This Matters

Without symlink resolution, `SCRIPT_DIR` points to the symlink's location, not the actual script location. This breaks library sourcing when scripts are:

- Symlinked from parent directories
- Aliased in shell configuration
- Called via symlinks in PATH directories
- Invoked from different working directories

---

## What This Pattern Does

1. **Follows the symlink chain**: Resolves through multiple levels of symlinks
2. **Handles relative symlinks**: Converts relative paths to absolute paths
3. **Finds the real script**: Locates the actual script file, not the symlink
4. **Sets SCRIPT_DIR correctly**: Points to the directory containing the real script

---

## Examples

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

---

## Testing Symlink Support

Always test scripts via symlinks before committing:

```bash
# Create test symlink in /tmp
cd /tmp
ln -s /path/to/actual/script.sh test-script.sh

# Test that library loading works
bash test-script.sh --help

# Should display help without "No such file or directory" errors
```

---

## Reference Implementations

- `bu.sh`
- `mu.sh`
- `fetch-github-projects.sh`
- `integrate-claude-web-branch.sh`
- `scorch-repo.sh`

