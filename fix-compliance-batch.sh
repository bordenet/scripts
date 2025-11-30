#!/usr/bin/env bash
################################################################################
# Script Name: fix-compliance-batch.sh
# Description: Batch fix compliance issues across all scripts
# Platform: macOS
################################################################################

set -euo pipefail

# Arguments
VERBOSE=false

# Display help information
show_help() {
    cat << EOF
NAME
    fix-compliance-batch.sh - Batch fix compliance issues across all scripts

SYNOPSIS
    fix-compliance-batch.sh [OPTIONS]

DESCRIPTION
    Automatically fixes common compliance issues across all shell scripts in
    the repository. Updates shebangs to #!/usr/bin/env bash and adds error
    handling (set -euo pipefail) where missing.

OPTIONS
    -v, --verbose
        Enable verbose output showing detailed fix operations

    -h, --help
        Display this help message and exit

EXIT STATUS
    0   Success
    1   Error

FIXES APPLIED
    1. Updates shebangs to #!/usr/bin/env bash
    2. Adds set -euo pipefail after shebang (where missing)
    3. Skips bu.sh and mu.sh (intentionally no error handling)
    4. Skips lib/ directory files

PLATFORM
    macOS (uses sed -i '' syntax)

EOF
    exit 0
}

# Logging function for verbose output
log_verbose() {
    if [ "$VERBOSE" = true ]; then
        echo "[VERBOSE] $*" >&2
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo "=== Fixing Script Compliance Issues ==="
echo

# Fix shebang lines
echo "1. Fixing shebang lines..."
log_verbose "Searching for scripts with incorrect shebangs"
find . -type f -name "*.sh" ! -path "*/.*" -exec sed -i '' '1s|^#!/bin/bash$|#!/usr/bin/env bash|' {} \;
log_verbose "Completed shebang updates"
echo "   ✓ Updated shebangs to #!/usr/bin/env bash"

# Add set -euo pipefail where missing (after shebang, before any other code)
echo "2. Adding error handling (set -euo pipefail)..."
log_verbose "Scanning scripts for missing error handling"
while IFS= read -r -d '' script; do
    log_verbose "Checking script: $script"

    # Skip if already has error handling
    if grep -q "set -euo pipefail\|set -eo pipefail" "$script" 2>/dev/null; then
        log_verbose "Skipping $script (already has error handling)"
        continue
    fi

    # Skip if it's bu.sh or mu.sh (they intentionally don't exit on error)
    if [[ "$script" =~ (bu|mu)\.sh$ ]]; then
        log_verbose "Skipping $script (intentionally no error handling)"
        continue
    fi
    
    # Find first non-comment, non-shebang line and add set -euo pipefail before it
    awk '
        BEGIN { added = 0 }
        /^#!/ { print; next }
        /^[[:space:]]*#/ && added == 0 { print; next }
        /^[[:space:]]*$/ && added == 0 { print; next }
        added == 0 {
            print ""
            print "set -euo pipefail"
            print ""
            added = 1
        }
        { print }
    ' "$script" > "$script.tmp" && mv "$script.tmp" "$script"

    log_verbose "Added error handling to $script"
    echo "   ✓ Added to $(basename "$script")"
done < <(find . -type f -name "*.sh" ! -path "*/.*" ! -path "*/lib/*" -print0)

log_verbose "Compliance fixes completed"
echo
echo "=== Compliance fixes applied ==="
echo "Next steps:"
echo "1. Review changes with: git diff"
echo "2. Test scripts: bash -n script.sh"
echo "3. Run shellcheck on modified scripts"
echo "4. Commit changes"

