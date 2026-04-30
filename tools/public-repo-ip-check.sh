#!/usr/bin/env bash
# IP audit for bordenet/scripts (personal public GitHub repo).
# Scans staged changes or a commit range for internal employer names and
# proprietary terms. Called by pre-commit (--staged-only) and pre-push
# (--range <SHA>..<SHA>).
# Exit 0 = clean. Exit 1 = match found (push blocked).
set -euo pipefail

# ---------------------------------------------------------------------------
# Patterns that must NEVER appear in this public repo.
# Update this list when new internal tooling is adopted.
# ---------------------------------------------------------------------------
readonly PATTERNS=(
    # Employer name (case-insensitive match via character class)
    "[Cc]all[Bb]ox"
    # Internal domains
    "callbox\\.net"
    "callbox\\.int"
    "gitlab\\.int"
    # Internal product overlays
    "superpowers-[removed]"
    "superpowers-[removed]"
    ***REMOVED***
    "[removed-service]"
    "[removed-shared]"
    # Work email pattern
    "mbordenet@callbox"
)

PATTERN=$(printf "%s|" "${PATTERNS[@]}"); PATTERN="${PATTERN%|}"

VERBOSE=false
STAGED_ONLY=false
COMMIT_RANGE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --staged-only) STAGED_ONLY=true; shift ;;
        --range)       COMMIT_RANGE="${2:-}"; shift 2 ;;
        -v|--verbose)  VERBOSE=true; shift ;;
        -h|--help)
            echo "Usage: $(basename "$0") [--staged-only] [--range SHA..SHA] [-v]"
            exit 0 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

HITS=0
show_match() { echo "❌ IP match in $1:$2: $3"; }

if [[ "$STAGED_ONLY" == "true" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^\+\+\+ ]] && { current_file="${line#+++ b/}"; continue; }
        # Skip the scanner's own file — pattern definitions will always self-match
        [[ "${current_file:-}" == "tools/public-repo-ip-check.sh" ]] && continue
        [[ "$line" =~ ^\+ ]] || continue
        content="${line:1}"
        if echo "$content" | grep -qE "$PATTERN"; then
            show_match "${current_file:-<unknown>}" "staged" "$content"
            HITS=$((HITS + 1))
        fi
    done < <(git diff --cached --unified=0 2>/dev/null)

elif [[ -n "$COMMIT_RANGE" ]]; then
    while IFS= read -r line; do
        [[ "$line" =~ ^diff\ --git ]] && { current_file="${line##* b/}"; continue; }
        [[ "$line" =~ ^\+\+\+ ]] && { current_file="${line#+++ b/}"; continue; }
        # Skip the scanner's own file — pattern definitions will always self-match
        [[ "${current_file:-}" == "tools/public-repo-ip-check.sh" ]] && continue
        [[ "$line" =~ ^\+ ]] || continue
        content="${line:1}"
        if echo "$content" | grep -qE "$PATTERN"; then
            show_match "${current_file:-<unknown>}" "commit" "$content"
            HITS=$((HITS + 1))
        fi
    done < <(git log -p "$COMMIT_RANGE" 2>/dev/null)

else
    # Full working-tree scan (advisory)
    while IFS= read -r f; do
        [[ -f "$f" ]] || continue
        while IFS= read -r hit; do
            show_match "$f" "" "$hit"
            HITS=$((HITS + 1))
        done < <(grep -nE "$PATTERN" "$f" 2>/dev/null || true)
    done < <(git ls-files)
fi

if [[ $HITS -gt 0 ]]; then
    echo ""
    echo "IP audit FAILED: $HITS match(es). Remove internal terms before committing."
    exit 1
fi

[[ "$VERBOSE" == "true" ]] && echo "  IP audit: clean"
exit 0
