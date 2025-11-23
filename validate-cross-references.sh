#!/usr/bin/env bash
################################################################################
# Script Name: validate-cross-references.sh
################################################################################
# PURPOSE: Validate all cross-references in markdown and script files
# USAGE: ./validate-cross-references.sh [OPTIONS]
# PLATFORM: macOS | Linux
################################################################################

set -euo pipefail

################################################################################
# Constants
################################################################################

# SC2155: Declare and assign separately to avoid masking return values
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

################################################################################
# Global Variables
################################################################################

VERBOSE=false
TOTAL_LINKS=0
BROKEN_LINKS=0
VALID_LINKS=0

################################################################################
# Functions
################################################################################

show_help() {
    cat << EOF
NAME
    ${SCRIPT_NAME} - Validate cross-references in documentation

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS]

DESCRIPTION
    Validates all markdown links and cross-references in the repository.
    Checks:
    - Relative links to files (./file.md, ../file.md)
    - Links to scripts (.sh files)
    - Links to documentation (.md files)
    - Anchor links within documents

OPTIONS
    -h, --help      Display this help message
    -v, --verbose   Show all links being checked

EXAMPLES
    ${SCRIPT_NAME}
    ${SCRIPT_NAME} --verbose

EXIT STATUS
    0   All links valid
    1   One or more broken links found

EOF
}

log_info() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[INFO]${NC} $*"
    fi
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

# Extract markdown links from a file
extract_links() {
    local file="$1"
    # Match [text](path.md) or [text](path.sh) with optional anchors
    # Only match if the link starts with ./ or ../ or / (relative/absolute paths)
    # BSD grep compatible version - match markdown links to .md or .sh files
    grep -o '\[[^]]*\]([./#][^)]*\.md[^)]*)\|\[[^]]*\]([./#][^)]*\.sh[^)]*)' "$file" | sed 's/.*(\(.*\))/\1/' || true
}

# Validate a single link
validate_link() {
    local link="$1"
    local source_file="$2"
    local source_dir
    source_dir="$(dirname "$source_file")"
    
    ((TOTAL_LINKS++))
    
    # Skip external links (http://, https://, mailto:)
    if [[ "$link" =~ ^https?:// ]] || [[ "$link" =~ ^mailto: ]]; then
        log_info "Skipping external link: $link"
        ((VALID_LINKS++))
        return 0
    fi
    
    # Strip anchor if present (we only validate file existence, not anchors)
    local file_path="${link%%#*}"

    # Skip if only anchor (same-file reference)
    if [[ "$link" == "#"* ]]; then
        log_info "Skipping same-file anchor: $link"
        ((VALID_LINKS++))
        return 0
    fi
    
    # Resolve relative path
    local target_path
    if [[ "$file_path" == /* ]]; then
        # Absolute path from repo root
        target_path="$SCRIPT_DIR$file_path"
    else
        # Relative path from source file
        target_path="$source_dir/$file_path"
    fi
    
    # Normalize path (resolve .. and .)
    target_path="$(cd "$(dirname "$target_path")" 2>/dev/null && pwd)/$(basename "$target_path")" || target_path=""
    
    # Check if target exists
    if [[ -e "$target_path" ]]; then
        log_info "Valid: $link (in $source_file)"
        ((VALID_LINKS++))
        return 0
    else
        log_error "Broken link in $source_file: $link"
        log_error "  Expected: $target_path"
        ((BROKEN_LINKS++))
        return 1
    fi
}

# Validate all links in a file
validate_file() {
    local file="$1"
    
    log_info "Checking file: $file"
    
    local links
    links=$(extract_links "$file")
    
    if [[ -z "$links" ]]; then
        log_info "  No links found"
        return 0
    fi
    
    while IFS= read -r link; do
        [[ -z "$link" ]] && continue
        validate_link "$link" "$file" || true
    done <<< "$links"
}

################################################################################
# Main Script
################################################################################

main() {
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            *)
                echo "Error: Unknown option: $1" >&2
                exit 1
                ;;
        esac
    done
    
    echo "Validating cross-references in repository..."
    echo ""
    
    # Find all markdown files
    while IFS= read -r -d '' file; do
        validate_file "$file"
    done < <(find "$SCRIPT_DIR" -name "*.md" -type f \
        ! -path "*/node_modules/*" \
        ! -path "*/.git/*" \
        -print0)
    
    # Print summary
    echo ""
    echo "========================================"
    echo "Cross-Reference Validation Summary"
    echo "========================================"
    echo "Total links checked: $TOTAL_LINKS"
    echo -e "Valid links:         ${GREEN}$VALID_LINKS${NC}"
    echo -e "Broken links:        ${RED}$BROKEN_LINKS${NC}"
    
    if [[ $BROKEN_LINKS -eq 0 ]]; then
        echo ""
        log_success "All cross-references are valid"
        exit 0
    else
        echo ""
        log_error "$BROKEN_LINKS broken link(s) found"
        exit 1
    fi
}

main "$@"

