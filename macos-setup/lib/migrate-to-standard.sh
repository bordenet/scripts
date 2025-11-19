#!/usr/bin/env bash

################################################################################
# RecipeArchive Shell Script Migration Tool
################################################################################
# PURPOSE: Semi-automated migration of existing scripts to standardized format
#   - Identifies scripts not using common library
#   - Provides checklist for manual migration
#   - Validates migrated scripts
#
# USAGE:
#   ./scripts/lib/migrate-to-standard.sh --check      # List scripts needing migration
#   ./scripts/lib/migrate-to-standard.sh --validate   # Validate migrated scripts
#
# DEPENDENCIES:
#   - shellcheck (brew install shellcheck)
################################################################################

readonly SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
readonly SCRIPTS_DIR="$REPO_ROOT/scripts"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

check_scripts() {
    echo -e "${BLUE}Checking scripts for common library usage...${NC}\n"

    local total=0
    local migrated=0
    local needs_migration=0

    while IFS= read -r script; do
        total=$((total + 1))

        # Skip the common library itself
        if [[ "$script" == */lib/common.sh ]]; then
            continue
        fi

        # Check if script sources common library
        if grep -q "source.*lib/common.sh" "$script"; then
            echo -e "${GREEN}✓${NC} $(basename "$script") - Already migrated"
            migrated=$((migrated + 1))
        else
            echo -e "${YELLOW}○${NC} $(basename "$script") - Needs migration"
            needs_migration=$((needs_migration + 1))
        fi
    done < <(find "$SCRIPTS_DIR" -type f -name "*.sh")

    echo ""
    echo -e "${BLUE}Summary:${NC}"
    echo "  Total scripts: $total"
    echo "  Migrated: $migrated"
    echo "  Needs migration: $needs_migration"
}

validate_script() {
    local script="$1"
    local errors=0

    echo -e "\n${BLUE}Validating $(basename "$script")...${NC}"

    # Check 1: Has proper shebang
    if ! head -1 "$script" | grep -q "^#!/usr/bin/env bash"; then
        echo -e "  ${RED}✗${NC} Missing or incorrect shebang"
        errors=$((errors + 1))
    else
        echo -e "  ${GREEN}✓${NC} Proper shebang"
    fi

    # Check 2: Has header comment
    if ! head -30 "$script" | grep -q "^# PURPOSE:"; then
        echo -e "  ${YELLOW}○${NC} Missing PURPOSE in header"
    else
        echo -e "  ${GREEN}✓${NC} Has PURPOSE documentation"
    fi

    # Check 3: Sources common library
    if ! grep -q "source.*lib/common.sh" "$script"; then
        echo -e "  ${RED}✗${NC} Does not source common library"
        errors=$((errors + 1))
    else
        echo -e "  ${GREEN}✓${NC} Sources common library"
    fi

    # Check 4: Uses standard logging
    if grep -qE "^[^#]*echo -e.*\\\\033" "$script"; then
        echo -e "  ${YELLOW}○${NC} Uses raw color codes (should use log_* functions)"
    else
        echo -e "  ${GREEN}✓${NC} No raw color codes found"
    fi

    # Check 5: Passes shellcheck
    if command -v shellcheck &> /dev/null; then
        if shellcheck -x "$script" &> /dev/null; then
            echo -e "  ${GREEN}✓${NC} Passes shellcheck"
        else
            echo -e "  ${YELLOW}○${NC} Has shellcheck warnings"
        fi
    fi

    return $errors
}

validate_all() {
    echo -e "${BLUE}Validating all migrated scripts...${NC}"

    local total=0
    local passed=0
    local failed=0

    while IFS= read -r script; do
        # Only validate scripts that source common library
        if grep -q "source.*lib/common.sh" "$script"; then
            total=$((total + 1))

            if validate_script "$script"; then
                passed=$((passed + 1))
            else
                failed=$((failed + 1))
            fi
        fi
    done < <(find "$SCRIPTS_DIR" -type f -name "*.sh" ! -path "*/lib/*")

    echo ""
    echo -e "${BLUE}Validation Summary:${NC}"
    echo "  Scripts validated: $total"
    echo "  Passed: $passed"
    echo "  Failed: $failed"

    return $failed
}

print_migration_guide() {
    cat << 'EOF'

Migration Guide
===============

To migrate a script to the standard format:

1. Add shebang (if missing):
   #!/usr/bin/env bash

2. Add/update header comment:
   ################################################################################
   # RecipeArchive <Purpose>
   ################################################################################
   # PURPOSE: <One sentence description>
   #   - <Key responsibility 1>
   #   - <Key responsibility 2>
   #
   # USAGE:
   #   ./<script> [options]
   #
   # EXAMPLES:
   #   ./<script> --example
   ################################################################################

3. Source common library:
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../lib/common.sh" || source "$SCRIPT_DIR/lib/common.sh"
   init_script

4. Replace color definitions:
   Remove: RED='\033[0;31m' etc.
   Use: COLOR_RED, COLOR_GREEN from common library

5. Replace echo statements:
   echo "Info" → log_info "Info"
   echo -e "${GREEN}✓${NC} Success" → log_success "Success"
   echo -e "${RED}✗${NC} Error" → log_error "Error"
   echo "ERROR: Failed" >&2 → die "Failed"

6. Use standard functions:
   - require_command "flutter" "brew install flutter"
   - require_file "$CONFIG_FILE" "Copy .env.example to .env"
   - get_repo_root (instead of hardcoded ../..)

7. Test the script:
   ./scripts/<script> --help
   shellcheck scripts/<script>

8. Validate:
   ./scripts/lib/migrate-to-standard.sh --validate

See scripts/STYLE_GUIDE.md for complete documentation.
EOF
}

main() {
    case "${1:-}" in
        --check)
            check_scripts
            ;;
        --validate)
            validate_all
            ;;
        --help|-h)
            print_migration_guide
            ;;
        *)
            echo "Usage: $0 [--check|--validate|--help]"
            echo ""
            echo "Options:"
            echo "  --check      List scripts needing migration"
            echo "  --validate   Validate migrated scripts"
            echo "  --help       Show migration guide"
            exit 1
            ;;
    esac
}

main "$@"
