#!/usr/bin/env bash
# detect-readme-slop.sh - Detect AI slop in README files
# Can be used standalone or as a pre-commit hook
#
# Usage:
#   ./detect-readme-slop.sh [OPTIONS] [FILE...]
#
# Options:
#   -t, --threshold NUM  Fail if slop score exceeds NUM (default: 40)
#   -v, --verbose        Show detailed pattern breakdown
#   -q, --quiet          Only output on failure
#   --staged             Check git staged README files (for pre-commit)
#   -h, --help           Show this help message
#
# Exit codes:
#   0 - All files pass threshold
#   1 - One or more files exceed threshold
#   2 - Error (invalid args, missing files)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/slop-detection-lib.sh"

# Defaults
THRESHOLD=40
VERBOSE=false
QUIET=false
STAGED=false

show_help() {
    sed -n '2,18p' "$0" | sed 's/^# //' | sed 's/^#//'
}

die() {
    echo "ERROR: $*" >&2
    exit 2
}

# Parse arguments
FILES=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
            shift
            ;;
        --staged)
            STAGED=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            die "Unknown option: $1"
            ;;
        *)
            FILES+=("$1")
            shift
            ;;
    esac
done

# Get files to check
if [[ "$STAGED" == "true" ]]; then
    # Get staged README files
    mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACM 2>/dev/null | grep -i "readme\.md$" || true)
fi

if [[ ${#FILES[@]} -eq 0 ]]; then
    if [[ "$STAGED" == "true" ]]; then
        # No README files staged - pass silently
        exit 0
    else
        die "No files specified. Use --staged for pre-commit or provide file paths."
    fi
fi

# Check each file
FAILED=0
for file in "${FILES[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "SKIP: $file (not found)"
        continue
    fi
    
    score=$(calculate_slop_score "$file")
    verdict=$(get_verdict "$score")
    
    if score_passes "$score" "$THRESHOLD"; then
        if [[ "$QUIET" == "false" ]]; then
            echo "PASS: $file (score: $score/100, $verdict)"
        fi
    else
        echo "FAIL: $file (score: $score/100, $verdict, threshold: $THRESHOLD)"
        FAILED=1
        
        if [[ "$VERBOSE" == "true" ]]; then
            get_pattern_details "$file"
            echo ""
        fi
    fi
done

if [[ $FAILED -eq 1 ]]; then
    echo ""
    echo "README files with high AI slop detected."
    echo "Run with --verbose to see specific patterns."
    echo "Reduce slop or increase threshold with --threshold"
    exit 1
fi

exit 0

