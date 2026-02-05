# Shell Script Style Guide: Error Handling & set -euo pipefail

> Part of [SHELL_SCRIPT_STYLE_GUIDE.md](../SHELL_SCRIPT_STYLE_GUIDE.md)

---

## Shell Configuration and Safety Defaults

Every script must start with:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

These defaults:
- **Fail fast** on errors
- **Treat unset variables** as bugs instead of silently continuing
- **Propagate errors** through pipelines

Optional but encouraged:
- `set -x` when debugging locally (never committed enabled)
- `shopt -s nullglob` when globbing on possibly-empty patterns

---

## Error Handling Rules

- Always check exit codes for critical operations
- Use trap-based cleanup (EXIT, ERR) for temporary files, directories, and state
- Error messages must tell the user what went wrong and how to fix it

**Do NOT:**
- Hide exit codes by combining declaration + assignment from a command
- Rely on `|| true` without very clear justification
- Leave temporary files or partial state behind after failure

---

## Surviving `set -euo pipefail`

### Network-dependent commands will kill your script:

```bash
# ❌ DANGEROUS - network failure aborts script
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}')

# ✅ SAFE - graceful degradation
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}' || true)
[ -z "$DEFAULT_BRANCH" ] && DEFAULT_BRANCH="main"

# ✅ ALSO SAFE - explicit error handling
if ! DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | awk '/HEAD branch/ {print $NF}'); then
    DEFAULT_BRANCH="main"
fi
```

### Timer and process cleanup must be bulletproof:

```bash
# ❌ DANGEROUS - already-exited process causes abort
stop_timer() {
    if [ -n "$TIMER_PID" ] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null
    fi
    TIMER_PID=""
}

# ✅ SAFE - cleanup never aborts script
stop_timer() {
    if [ -n "$TIMER_PID" ] && kill -0 "$TIMER_PID" 2>/dev/null; then
        kill "$TIMER_PID" 2>/dev/null || true
        wait "$TIMER_PID" 2>/dev/null || true
    fi
    TIMER_PID=""
}
```

### Exit code capture must happen immediately:

```bash
# ❌ WRONG - exit code is lost after intervening commands
if timeout 600 some_command; then
    complete_status "success"
else
    complete_status "failed"  # ← This clobbers $?
    exit_code=$?  # ← Captures wrong exit code!
fi

# ✅ CORRECT - capture exit code immediately
if timeout 600 some_command; then
    complete_status "success"
else
    exit_code=$?  # ← Must be first statement in else block
    if [ $exit_code -eq 124 ]; then
        complete_status "timeout"
    fi
fi
```

### Commands that may legitimately fail need `|| true`:

- `git fetch origin` (network issues)
- `git remote show origin` (network issues)
- `curl` and `wget` (network issues)
- `kill` and `wait` (process may have exited)
- `grep` in pipelines (no matches is not an error)
- `brew doctor` (warnings are informational, not fatal)

