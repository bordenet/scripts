#!/usr/bin/env bash
# Description: IP audit stub for bordenet/scripts (personal repo — no proprietary IP).
#              Called by pre-commit (--staged-only) and pre-push (--range <SHA>..<SHA>).
#              Always exits 0: this repo contains no CallBox or other proprietary IP.
# Usage: public-repo-ip-check.sh [--staged-only] [--range <range>] [-v|--verbose] [-h|--help]
set -euo pipefail

VERBOSE=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [options]

IP audit check for this repository. This is a personal public repo with no
proprietary IP — the check always passes.

Options:
  --staged-only    Check only staged files (pre-commit mode)
  --range <range>  Check a specific commit range (pre-push mode)
  -v, --verbose    Enable verbose output
  -h, --help       Show this help message
EOF
}

main() {
    local _staged_only=false
    local _range=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --staged-only) _staged_only=true; shift ;;
            --range)       _range="${2:-}"; shift 2 ;;
            -v|--verbose)  VERBOSE=true; shift ;;
            -h|--help)     usage; exit 0 ;;
            *)             echo "Unknown option: $1" >&2; usage; exit 1 ;;
        esac
    done

    if [[ "$VERBOSE" == "true" ]]; then
        echo "  IP audit: personal repo — no proprietary IP (staged_only=${_staged_only} range=${_range})"
    fi

    # This is bordenet/scripts — a personal project with no CallBox or other
    # proprietary IP. The audit unconditionally passes.
    exit 0
}

main "$@"
