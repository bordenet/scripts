#!/usr/bin/env bash
set -euo pipefail

# CI Quality Gates - Validates all shell scripts in repository
# This script is used by GitHub Actions and can be run locally

# Arguments
VERBOSE=false

# Display help information
show_help() {
    cat << EOF
NAME
    ci-quality-gates.sh - Validate all shell scripts against quality standards

SYNOPSIS
    ci-quality-gates.sh [OPTIONS]

DESCRIPTION
    Validates all shell scripts in the repository against coding standards.
    Checks syntax, ShellCheck warnings/errors, shebang correctness, error
    handling, and line count limits. Used by GitHub Actions CI/CD pipeline.

OPTIONS
    -v, --verbose
        Enable verbose output showing detailed validation steps

    -h, --help
        Display this help message and exit

EXIT STATUS
    0   All quality gates passed
    1   One or more quality gates failed

CHECKS PERFORMED
    1. Syntax validation (bash -n)
    2. ShellCheck errors
    3. ShellCheck warnings
    4. Shebang correctness (#!/usr/bin/env bash)
    5. Error handling (set -euo pipefail)
    6. Line count limit (400 lines maximum)

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

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CI Quality Gates: Validating All Shell Scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
log_verbose "Starting quality gate validation"

TOTAL_SCRIPTS=0
SYNTAX_ERRORS=0
SHELLCHECK_ERRORS=0
SHELLCHECK_WARNINGS=0
WRONG_SHEBANG=0
MISSING_ERROR_HANDLING=0
OVERSIZED_SCRIPTS=0

# Find all .sh files (excluding hidden directories)
log_verbose "Searching for shell scripts (excluding hidden directories)"
while IFS= read -r -d '' script; do
  ((TOTAL_SCRIPTS++))
  echo "Checking: $script"
  log_verbose "Validating script: $script"

  # 1. Syntax validation
  log_verbose "Running syntax check (bash -n)"
  if ! bash -n "$script" 2>/dev/null; then
    echo "  ✗ Syntax error"
    ((SYNTAX_ERRORS++))
  fi
  
  # 2. ShellCheck errors (if available)
  if command -v shellcheck >/dev/null 2>&1; then
    log_verbose "Running ShellCheck for errors"
    if shellcheck -S error "$script" 2>&1 | grep -q "^In "; then
      echo "  ✗ ShellCheck errors found"
      ((SHELLCHECK_ERRORS++))
    fi

    # 3. ShellCheck warnings
    log_verbose "Running ShellCheck for warnings"
    if shellcheck -S warning "$script" 2>&1 | grep -q "^In "; then
      echo "  ✗ ShellCheck warnings found"
      ((SHELLCHECK_WARNINGS++))
    fi
  else
    log_verbose "ShellCheck not available, skipping lint checks"
  fi
  
  # 4. Check shebang
  if ! head -1 "$script" | grep -q "^#!/usr/bin/env bash"; then
    echo "  ✗ Wrong shebang (expected: #!/usr/bin/env bash)"
    ((WRONG_SHEBANG++))
  fi
  
  # 5. Check error handling (skip bu.sh, mu.sh, and lib files)
  if [[ ! "$script" =~ (bu\.sh|mu\.sh|/lib/) ]]; then
    if ! grep -q "^set -euo pipefail" "$script"; then
      echo "  ✗ Missing error handling (set -euo pipefail)"
      ((MISSING_ERROR_HANDLING++))
    fi
  fi
  
  # 6. Check line count
  LINE_COUNT=$(wc -l < "$script")
  if [ "$LINE_COUNT" -gt 400 ]; then
    echo "  ✗ Script exceeds 400 lines ($LINE_COUNT lines)"
    ((OVERSIZED_SCRIPTS++))
  fi
  
done < <(find . -type f -name "*.sh" ! -path "*/.*" -print0)

log_verbose "Completed validation of all $TOTAL_SCRIPTS scripts"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Quality Gates Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Total Scripts:              $TOTAL_SCRIPTS"
echo "Syntax Errors:              $SYNTAX_ERRORS"
echo "ShellCheck Errors:          $SHELLCHECK_ERRORS"
echo "ShellCheck Warnings:        $SHELLCHECK_WARNINGS"
echo "Wrong Shebang:              $WRONG_SHEBANG"
echo "Missing Error Handling:     $MISSING_ERROR_HANDLING"
echo "Oversized Scripts (>400):   $OVERSIZED_SCRIPTS"
echo ""

TOTAL_ISSUES=$((SYNTAX_ERRORS + SHELLCHECK_ERRORS + SHELLCHECK_WARNINGS + WRONG_SHEBANG + MISSING_ERROR_HANDLING + OVERSIZED_SCRIPTS))

if [ $TOTAL_ISSUES -eq 0 ]; then
  echo "✅ All quality gates passed! ($TOTAL_SCRIPTS scripts validated)"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
else
  echo "❌ Quality gates failed with $TOTAL_ISSUES issue(s)"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi

