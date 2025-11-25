#!/usr/bin/env bash
set -euo pipefail

# CI Quality Gates - Validates all shell scripts in repository
# This script is used by GitHub Actions and can be run locally

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  CI Quality Gates: Validating All Shell Scripts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

TOTAL_SCRIPTS=0
SYNTAX_ERRORS=0
SHELLCHECK_ERRORS=0
SHELLCHECK_WARNINGS=0
WRONG_SHEBANG=0
MISSING_ERROR_HANDLING=0
OVERSIZED_SCRIPTS=0

# Find all .sh files (excluding hidden directories)
while IFS= read -r -d '' script; do
  ((TOTAL_SCRIPTS++))
  echo "Checking: $script"
  
  # 1. Syntax validation
  if ! bash -n "$script" 2>/dev/null; then
    echo "  ✗ Syntax error"
    ((SYNTAX_ERRORS++))
  fi
  
  # 2. ShellCheck errors (if available)
  if command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -S error "$script" 2>&1 | grep -q "^In "; then
      echo "  ✗ ShellCheck errors found"
      ((SHELLCHECK_ERRORS++))
    fi
    
    # 3. ShellCheck warnings
    if shellcheck -S warning "$script" 2>&1 | grep -q "^In "; then
      echo "  ✗ ShellCheck warnings found"
      ((SHELLCHECK_WARNINGS++))
    fi
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

