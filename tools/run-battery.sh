#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Script: run-battery.sh
# PURPOSE: Run the automated quality suite for bordenet/scripts and write
#          .code-review-cleared. This is the ONLY permitted way to write the
#          sentinel file.
# USAGE:   tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]
#            N = quality threshold, 1.0–10.0 (default 9.2)
# EXIT:    0 = all checks pass, sentinel written
#          1 = failure, sentinel NOT written
# -----------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"
cd "$REPO_ROOT"

# --- Parse flags ---
VERDICT="PASS"
MIN_SCORE="9.2"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            cat << 'EOF'
Usage: tools/run-battery.sh [--verdict PASS|PASS_WITH_NITS] [--min-score N]

Run the automated quality suite and write .code-review-cleared.

Options:
  --verdict     PASS or PASS_WITH_NITS (default: PASS)
  --min-score   Quality threshold 1.0–10.0 (default: 9.2)
  -h, --help    Show this help
EOF
            exit 0
            ;;
        --verdict)  VERDICT="${2:?--verdict requires a value}"; shift 2 ;;
        --verdict=*) VERDICT="${1#--verdict=}"; shift ;;
        --min-score) MIN_SCORE="${2:?--min-score requires a value}"; shift 2 ;;
        --min-score=*) MIN_SCORE="${1#--min-score=}"; shift ;;
        *) echo "Unknown flag: $1" >&2; exit 1 ;;
    esac
done

if [[ "$VERDICT" != "PASS" && "$VERDICT" != "PASS_WITH_NITS" ]]; then
    echo "❌ Invalid verdict '$VERDICT'. Must be PASS or PASS_WITH_NITS." >&2; exit 1
fi

if ! [[ "$MIN_SCORE" =~ ^[0-9]+(\.[0-9]+)?$ ]] || \
   ! awk -v s="$MIN_SCORE" 'BEGIN { exit !(s >= 1.0 && s <= 10.0) }'; then
    echo "❌ Invalid --min-score '$MIN_SCORE'. Must be 1.0–10.0." >&2; exit 1
fi

echo "═══════════════════════════════════════════════════════════"
echo "  run-battery.sh — bordenet/scripts quality suite"
echo "═══════════════════════════════════════════════════════════"

if ! git diff --quiet -- ':!.code-review-cleared' 2>/dev/null; then
    echo "❌ Unstaged modifications detected. Stage or stash before running battery." >&2
    exit 1
fi

ERRORS=0

echo "─── Step 1/3: shellcheck ───"
SH_FILES=$(git ls-files '*.sh' | grep -v '^\.git/' || true)
if [[ -n "$SH_FILES" ]]; then
    if echo "$SH_FILES" | xargs shellcheck -e SC1091,SC2034,SC2129,SC2155,SC2162 2>&1; then
        echo "✓ shellcheck passed"
    else
        echo "❌ shellcheck FAILED"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  (no .sh files to check)"
fi
echo ""

echo "─── Step 2/3: bash -n syntax check ───"
SYNTAX_ERRORS=0
while IFS= read -r f; do
    [[ -f "$f" ]] || continue
    head_line=$(head -1 "$f" 2>/dev/null || true)
    [[ "$head_line" =~ zsh ]] && continue
    if ! bash -n "$f" 2>&1; then
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done <<< "$(git ls-files '*.sh' | grep -v '^\.' || true)"
if [[ $SYNTAX_ERRORS -eq 0 ]]; then
    echo "✓ bash -n syntax check passed"
else
    echo "❌ bash -n found $SYNTAX_ERRORS syntax error(s)"
    ERRORS=$((ERRORS + 1))
fi
echo ""

echo "─── Step 3/3: go test ───"
if [[ -f "$REPO_ROOT/go.mod" ]]; then
    if go test ./... 2>&1; then
        echo "✓ go test passed"
    else
        echo "❌ go test FAILED"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "  (no go.mod — skipping)"
fi
echo ""

if [[ $ERRORS -gt 0 ]]; then
    echo "═══════════════════════════════════════════════════════════"
    echo "  ❌ BATTERY FAILED — ${ERRORS} check(s) did not pass."
    echo "  Sentinel NOT written. Fix failures and re-run."
    echo "═══════════════════════════════════════════════════════════"
    exit 1
fi

SHA=$(git rev-parse HEAD)
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "v1|${SHA}|${VERDICT}|${TIMESTAMP}|min-score=${MIN_SCORE}" > "$REPO_ROOT/.code-review-cleared"

echo "═══════════════════════════════════════════════════════════"
echo "  ✅ BATTERY PASSED — sentinel written."
echo "  Verdict: ${VERDICT}  Min-score: ${MIN_SCORE}"
echo "  Commit:  ${SHA:0:8}  Timestamp: ${TIMESTAMP}"
echo "═══════════════════════════════════════════════════════════"
