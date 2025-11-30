#!/usr/bin/env bash
# Add help to all scripts missing it

set -euo pipefail

# Arguments
VERBOSE=false

# Display help information
show_help() {
    cat << EOF
NAME
    add-help-batch.sh - Add help function to scripts missing it

SYNOPSIS
    add-help-batch.sh [OPTIONS]

DESCRIPTION
    Batch adds help functions to scripts that don't have them. Extracts
    descriptions from existing comments and generates man-page style help text.

OPTIONS
    -v, --verbose
        Enable verbose output showing detailed processing information

    -h, --help
        Display this help message and exit

EXIT STATUS
    0   Success
    1   Error

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
            break
            ;;
    esac
done

SCRIPTS=(
    "analyze-malware-sandbox/check-alpine-version.sh"
    "analyze-malware-sandbox/create-vm-alternate.sh"
    "analyze-malware-sandbox/create-vm.sh"
    "analyze-malware-sandbox/inspect.sh"
    "analyze-malware-sandbox/provision-vm.sh"
    "analyze-malware-sandbox/setup-alpine.sh"
    "analyze-malware-sandbox/setup-sandbox.sh"
    "analyze-malware-sandbox/status.sh"
    "xcode/inspect-xcode.sh"
)

for script in "${SCRIPTS[@]}"; do
    log_verbose "Processing script: $script"

    if [ ! -f "$script" ]; then
        echo "Skipping $script (not found)"
        log_verbose "File not found at path: $script"
        continue
    fi

    # Check if already has help
    if grep -q "show_help()" "$script" 2>/dev/null; then
        echo "Skipping $script (already has help)"
        log_verbose "Script already contains show_help() function"
        continue
    fi

    echo "Adding help to $script..."
    log_verbose "Extracting description from comments"

    # Extract description from existing comments
    desc=$(grep -m1 "^# Description:" "$script" | sed 's/^# Description: This script //' | sed 's/^# Description: //' || echo "Script functionality")
    log_verbose "Extracted description: $desc"
    
    # Create temp file with help function
    awk -v desc="$desc" '
    BEGIN { added = 0 }
    /^#!/ { print; next }
    /^# -+$/ { skip = 1; next }
    skip && /^# -+$/ { skip = 0; next }
    skip { next }
    /^set -euo pipefail/ {
        print
        print ""
        print "# Display help information"
        print "show_help() {"
        print "    cat << EOF"
        print "NAME"
        print "    $(basename \"$0\") - " desc
        print ""
        print "SYNOPSIS"
        print "    $(basename \"$0\") [OPTIONS]"
        print ""
        print "DESCRIPTION"
        print "    " desc
        print ""
        print "OPTIONS"
        print "    -h, --help"
        print "        Display this help message and exit"
        print ""
        print "EXIT STATUS"
        print "    0   Success"
        print "    1   Error"
        print ""
        print "EOF"
        print "    exit 0"
        print "}"
        print ""
        print "# Parse arguments"
        print "while [[ $# -gt 0 ]]; do"
        print "    case \"$1\" in"
        print "        -h|--help)"
        print "            show_help"
        print "            ;;"
        print "        *)"
        print "            break"
        print "            ;;"
        print "    esac"
        print "done"
        print ""
        added = 1
        next
    }
    { print }
    ' "$script" > "$script.tmp" && mv "$script.tmp" "$script"

    log_verbose "Successfully added help function to $script"
    echo "  ✓ Added help to $script"
done

log_verbose "Batch help addition completed"
echo ""
echo "✓ All scripts updated"
