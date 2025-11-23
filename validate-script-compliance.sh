#!/usr/bin/env bash
################################################################################
# Script Name: validate-script-compliance.sh
################################################################################
# PURPOSE: Validate shell scripts against STYLE_GUIDE.md requirements
# USAGE: ./validate-script-compliance.sh [OPTIONS] [SCRIPT]
# PLATFORM: macOS | Linux
################################################################################

set -euo pipefail

################################################################################
# Constants
################################################################################

readonly VERSION="1.0.0"

# SC2155: Declare and assign separately to avoid masking return values
SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_NAME
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

################################################################################
# Global Variables
################################################################################

VERBOSE=false
REPORT_MODE=false
VALIDATE_ALL=false
TARGET_SCRIPT=""

# Statistics
TOTAL_SCRIPTS=0
PASSED_SCRIPTS=0
FAILED_SCRIPTS=0
TOTAL_ISSUES=0

################################################################################
# Functions
################################################################################

show_help() {
    cat << EOF
NAME
    ${SCRIPT_NAME} - Validate shell scripts against STYLE_GUIDE.md

SYNOPSIS
    ${SCRIPT_NAME} [OPTIONS] [SCRIPT]
    ${SCRIPT_NAME} --all [OPTIONS]

DESCRIPTION
    Validates shell scripts against the standards defined in STYLE_GUIDE.md.
    Checks for:
    - Script length (400 line limit)
    - Shellcheck compliance (zero warnings)
    - Syntax validation
    - Required flags (--help, --verbose)
    - Header documentation
    - Error handling patterns

OPTIONS
    -h, --help      Display this help message
    -v, --verbose   Show detailed validation output
    -a, --all       Validate all .sh files in repository
    -r, --report    Generate compliance report (JSON format)

ARGUMENTS
    SCRIPT          Path to script file to validate

EXAMPLES
    ${SCRIPT_NAME} bu.sh
    ${SCRIPT_NAME} --all
    ${SCRIPT_NAME} --all --report > compliance-report.json

EXIT STATUS
    0   All validations passed
    1   One or more validations failed
    2   Invalid arguments

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

log_warning() {
    echo -e "${YELLOW}[!]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" >&2
}

# Validate script length (400 line limit)
check_line_count() {
    local script="$1"
    local line_count
    line_count=$(wc -l < "$script")
    
    if [[ $line_count -gt 400 ]]; then
        log_error "Line count: $line_count (exceeds 400 line limit)"
        return 1
    else
        log_info "Line count: $line_count (within limit)"
        return 0
    fi
}

# Validate shellcheck compliance
check_shellcheck() {
    local script="$1"
    
    if ! command -v shellcheck &> /dev/null; then
        log_warning "shellcheck not installed - skipping lint check"
        return 0
    fi
    
    local output
    if output=$(shellcheck --severity=warning "$script" 2>&1); then
        log_info "Shellcheck: passed"
        return 0
    else
        log_error "Shellcheck: failed"
        if [[ "$VERBOSE" == true ]]; then
            echo "$output" | sed 's/^/  /'
        fi
        return 1
    fi
}

# Validate syntax
check_syntax() {
    local script="$1"
    
    if bash -n "$script" 2>/dev/null; then
        log_info "Syntax: valid"
        return 0
    else
        log_error "Syntax: invalid"
        return 1
    fi
}

# Check for required flags
check_required_flags() {
    local script="$1"
    local issues=0
    
    # Check for --help flag
    if ! grep -q '\-h\|--help' "$script"; then
        log_error "Missing --help flag implementation"
        ((issues++))
    else
        log_info "Help flag: present"
    fi
    
    # Check for --verbose flag (recommended but not always required)
    if ! grep -q '\-v\|--verbose' "$script"; then
        log_warning "Missing --verbose flag (recommended)"
    else
        log_info "Verbose flag: present"
    fi
    
    return $issues
}

# Check for header documentation
check_header_documentation() {
    local script="$1"
    local issues=0

    # Check for PURPOSE
    if ! grep -q '^# PURPOSE:' "$script"; then
        log_error "Missing PURPOSE in header"
        ((issues++))
    else
        log_info "Header: PURPOSE present"
    fi

    # Check for USAGE
    if ! grep -q '^# USAGE:' "$script"; then
        log_warning "Missing USAGE in header (recommended)"
    else
        log_info "Header: USAGE present"
    fi

    return $issues
}

# Check for error handling patterns
check_error_handling() {
    local script="$1"
    local issues=0

    # Check for set -e or set -euo pipefail
    if ! grep -q 'set -e' "$script"; then
        log_warning "Missing 'set -e' or 'set -euo pipefail' (recommended)"
    else
        log_info "Error handling: set -e present"
    fi

    return $issues
}

# Validate a single script
validate_script() {
    local script="$1"
    local script_issues=0

    echo ""
    echo -e "${BOLD}Validating:${NC} $script"
    echo "----------------------------------------"

    # Run all checks
    check_line_count "$script" || ((script_issues++))
    check_shellcheck "$script" || ((script_issues++))
    check_syntax "$script" || ((script_issues++))
    check_required_flags "$script" || ((script_issues++))
    check_header_documentation "$script" || ((script_issues++))
    check_error_handling "$script" || ((script_issues++))

    ((TOTAL_SCRIPTS++))
    TOTAL_ISSUES=$((TOTAL_ISSUES + script_issues))

    if [[ $script_issues -eq 0 ]]; then
        log_success "All checks passed"
        ((PASSED_SCRIPTS++))
        return 0
    else
        log_error "$script_issues issue(s) found"
        ((FAILED_SCRIPTS++))
        return 1
    fi
}

# Generate JSON report
generate_report() {
    cat << EOF
{
  "validation_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "validator_version": "$VERSION",
  "summary": {
    "total_scripts": $TOTAL_SCRIPTS,
    "passed": $PASSED_SCRIPTS,
    "failed": $FAILED_SCRIPTS,
    "total_issues": $TOTAL_ISSUES,
    "compliance_rate": $(awk "BEGIN {printf \"%.2f\", ($PASSED_SCRIPTS / $TOTAL_SCRIPTS) * 100}")
  },
  "standards_reference": "STYLE_GUIDE.md v1.2"
}
EOF
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
            -a|--all)
                VALIDATE_ALL=true
                shift
                ;;
            -r|--report)
                REPORT_MODE=true
                shift
                ;;
            -*)
                echo "Error: Unknown option: $1" >&2
                echo "Use --help for usage information" >&2
                exit 2
                ;;
            *)
                TARGET_SCRIPT="$1"
                shift
                ;;
        esac
    done

    # Validate arguments
    if [[ "$VALIDATE_ALL" == false && -z "$TARGET_SCRIPT" ]]; then
        echo "Error: Script path required (or use --all)" >&2
        echo "Use --help for usage information" >&2
        exit 2
    fi

    if [[ "$VALIDATE_ALL" == true && -n "$TARGET_SCRIPT" ]]; then
        echo "Error: Cannot specify both --all and a script path" >&2
        exit 2
    fi

    # Run validation
    if [[ "$VALIDATE_ALL" == true ]]; then
        echo -e "${BOLD}Validating all scripts in repository${NC}"

        # Find all .sh files, excluding certain directories
        while IFS= read -r -d '' script; do
            validate_script "$script" || true
        done < <(find "$SCRIPT_DIR" -name "*.sh" -type f \
            ! -path "*/analyze-malware-sandbox/*" \
            ! -path "*/iso/*" \
            ! -path "*/vm/*" \
            ! -path "*/shared/*" \
            -print0)
    else
        if [[ ! -f "$TARGET_SCRIPT" ]]; then
            echo "Error: File not found: $TARGET_SCRIPT" >&2
            exit 2
        fi
        validate_script "$TARGET_SCRIPT"
    fi

    # Print summary
    echo ""
    echo "========================================"
    echo -e "${BOLD}Validation Summary${NC}"
    echo "========================================"
    echo "Total scripts:  $TOTAL_SCRIPTS"
    echo -e "Passed:         ${GREEN}$PASSED_SCRIPTS${NC}"
    echo -e "Failed:         ${RED}$FAILED_SCRIPTS${NC}"
    echo "Total issues:   $TOTAL_ISSUES"

    if [[ $TOTAL_SCRIPTS -gt 0 ]]; then
        local compliance_rate
        compliance_rate=$(awk "BEGIN {printf \"%.1f\", ($PASSED_SCRIPTS / $TOTAL_SCRIPTS) * 100}")
        echo "Compliance:     ${compliance_rate}%"
    fi

    # Generate report if requested
    if [[ "$REPORT_MODE" == true ]]; then
        echo ""
        echo "========================================"
        echo "JSON Report"
        echo "========================================"
        generate_report
    fi

    # Exit with appropriate code
    if [[ $FAILED_SCRIPTS -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

main "$@"


