# Shell Script Standards & Common Library

**Purpose**: Standardized conventions for all shell scripts to ensure consistency, maintainability, and reliability.

**Core Principle**: All shell scripts should appear written by the same engineer.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [File Structure](#file-structure)
3. [Common Library](#common-library)
4. [Logging Standards](#logging-standards)
5. [Error Handling](#error-handling)
6. [Variable Naming](#variable-naming)
7. [Argument Parsing](#argument-parsing)
8. [Testing](#testing)
9. [Examples](#examples)

---

## Quick Start

**Minimum Viable Script**:

```bash
#!/usr/bin/env bash

################################################################################
# your-project <Script Purpose>
################################################################################
# PURPOSE: <One sentence description>
#   - <Key responsibility 1>
#   - <Key responsibility 2>
#
# USAGE:
#   ./<script-name> [options]
#
# EXAMPLES:
#   ./<script-name> --example-flag
#
# DEPENDENCIES:
#   - Tool 1
#   - Tool 2
################################################################################

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh" || source "$SCRIPT_DIR/../lib/common.sh"
init_script

# Script-specific variables
readonly SCRIPT_NAME="$(basename "$0")"
readonly REPO_ROOT="$(get_repo_root)"

# Main function
main() {
    log_header "Script Name"

    log_section "Step 1: Description"
    # Do work
    log_success "Step 1 complete"

    log_success "All operations completed successfully"
}

main "$@"
```

---

## File Structure

### Header Template

**Every script must start with this structure**:

```bash
#!/usr/bin/env bash

################################################################################
# your-project <Script Purpose>
################################################################################
# PURPOSE: <One sentence description>
#   - <Key responsibility 1>
#   - <Key responsibility 2>
#
# USAGE:
#   ./<script-name> [options]
#   ./<script-name> --help
#
# EXAMPLES:
#   ./<script-name> --dev --run
#   ./<script-name> --prod --release
#
# DEPENDENCIES:
#   - flutter (brew install flutter)
#   - aws-cli (brew install awscli)
################################################################################

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh" || die "Cannot load common library"

# Initialize script (sets up error handling, traps)
init_script

# Script-specific variables
readonly SCRIPT_NAME="$(basename "$0")"
readonly REPO_ROOT="$(get_repo_root)"
```

### Main Script Body

```bash
# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                print_usage
                exit 0
                ;;
            --option)
                OPTION_VALUE="$2"
                shift 2
                ;;
            *)
                die "Unknown option: $1 (use --help for usage)"
                ;;
        esac
    done
}

# Print usage information
print_usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Description:
    <Script description>

Options:
    -h, --help         Show this help message
    --option VALUE     Description of option

Examples:
    $SCRIPT_NAME --option value
EOF
}

# Main function
main() {
    log_header "Script Name"

    log_section "Step 1: Description"
    # Do work
    log_success "Step 1 complete"

    log_section "Step 2: Description"
    # Do work
    log_success "Step 2 complete"

    log_success "All operations completed successfully"
}

# Run main function
parse_arguments "$@"
main
```

---

## Common Library

### Installation

**Create `scripts/lib/common.sh`** (copy from starter-kit):

```bash
mkdir -p scripts/lib
cp starter-kit/common.sh scripts/lib/common.sh
chmod +x scripts/lib/common.sh
```

### Available Functions

#### Logging

| Function | Use Case | Example |
|----------|----------|---------|
| `log_info` | Standard information | `log_info "Starting deployment..."` |
| `log_success` | Operation completed | `log_success "Build complete"` |
| `log_warning` | Non-fatal issues | `log_warning "Cache disabled"` |
| `log_error` | Errors (continues) | `log_error "Failed to upload file.txt"` |
| `die` | Fatal errors (exits) | `die "AWS credentials not found"` |
| `log_debug` | Debug info (DEBUG=1) | `log_debug "Using bucket: s3://example"` |
| `log_header` | Major section | `log_header "iOS Build - your-project"` |
| `log_section` | Minor section | `log_section "Step 1: Environment Validation"` |

#### Error Handling

```bash
# Check required commands exist
require_command "flutter" "brew install flutter"
require_command "aws" "brew install awscli"

# Check required files exist
require_file "$REPO_ROOT/.env" "Copy .env.example to .env"

# Check required directories exist
require_directory "$IOS_DIR" "Run script from repository root"
```

#### Path Utilities

```bash
# Get script directory
SCRIPT_DIR="$(get_script_dir)"

# Get repository root (finds .git directory)
REPO_ROOT="$(get_repo_root)"
```

#### Platform Detection

```bash
if is_macos; then
    echo "Running on macOS"
fi

if is_linux; then
    echo "Running on Linux"
fi
```

#### User Interaction

```bash
# Ask yes/no question (returns 0 for yes, 1 for no)
if ask_yes_no "Continue with deployment?" "y"; then
    deploy
fi

# Respects AUTO_YES variable for non-interactive mode
AUTO_YES=true ./script.sh  # Automatically answers yes
```

---

## Logging Standards

### Use Standard Logging Functions

**Always use the common library functions** - never use raw `echo`:

```bash
# ✅ Good
log_info "Starting deployment"
log_success "Deployment complete"
log_warning "No .env file found, using defaults"
log_error "Deployment failed: bucket not found"

# ❌ Bad
echo "Starting deployment"
echo -e "\033[0;32m✓\033[0m Deployment complete"
echo "WARNING: No .env file found"
```

### Message Format

```bash
# Action in progress (present continuous)
log_info "Building iOS application..."

# Action complete (past tense)
log_success "iOS application built"

# Error messages (what failed + why)
log_error "Failed to build iOS application: Xcode not found"

# Debug messages (key-value pairs)
log_debug "build_config=release target=simulator version=1.0.0"
```

### Logging Levels

| Level | Function | When to Use |
|-------|----------|-------------|
| **INFO** | `log_info` | Normal progress updates, milestones |
| **SUCCESS** | `log_success` | Successful completion of operations |
| **WARNING** | `log_warning` | Non-critical issues, degraded functionality |
| **ERROR** | `log_error` | Errors that allow script to continue |
| **FATAL** | `die` | Unrecoverable errors that require exit |
| **DEBUG** | `log_debug` | Detailed info for troubleshooting (DEBUG=1 only) |

---

## Error Handling

### Required Error Handling

```bash
# At top of every script
set -euo pipefail
init_script  # Sets up ERR trap

# For critical operations
if ! aws s3 ls "s3://$BUCKET" &> /dev/null; then
    die "S3 bucket not found: $BUCKET"
fi

# For expected failures
if ! some_command 2> /dev/null; then
    log_warning "Optional operation failed, continuing"
fi
```

### Exit Codes

```bash
# Success
exit 0

# Generic failure
exit 1

# Custom error codes
readonly ERR_MISSING_DEPENDENCY=2
readonly ERR_BUILD_FAILED=3
readonly ERR_NETWORK_ERROR=4

if ! command -v flutter &> /dev/null; then
    log_error "Flutter not found"
    exit $ERR_MISSING_DEPENDENCY
fi
```

---

## Variable Naming

### Conventions

```bash
# Constants (readonly, uppercase with underscores)
readonly SCRIPT_NAME="deploy.sh"
readonly DEFAULT_REGION="us-west-2"
readonly MAX_RETRIES=3

# Configuration (uppercase)
BUILD_MODE="debug"
TARGET_PLATFORM="ios"
ENABLE_CACHE=true

# Local variables (lowercase with underscores)
local build_output="/tmp/build"
local retry_count=0
local user_input=""

# Paths (uppercase, end with _DIR or _FILE)
readonly SCRIPT_DIR="$(get_script_dir)"
readonly REPO_ROOT="$(get_repo_root)"
readonly BUILD_DIR="$REPO_ROOT/build"
readonly CONFIG_FILE="$REPO_ROOT/.env"
```

---

## Argument Parsing

### Standard Pattern

```bash
parse_arguments() {
    # Set defaults
    local mode=""
    local verbose=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                print_usage
                exit 0
                ;;
            --mode)
                mode="$2"
                shift 2
                ;;
            --verbose|-v)
                verbose=true
                shift
                ;;
            --debug)
                export DEBUG=1
                shift
                ;;
            *)
                die "Unknown option: $1 (use --help for usage)"
                ;;
        esac
    done

    # Validate required arguments
    [[ -z "$mode" ]] && die "Missing required argument: --mode"

    # Export for use in script
    MODE="$mode"
    VERBOSE="$verbose"
}
```

---

## Testing

### Validation Checklist

Before committing any script:

- [ ] Script has proper header with PURPOSE and USAGE
- [ ] Uses `source "...lib/common.sh"`
- [ ] Calls `init_script` after sourcing common library
- [ ] Uses `log_*` functions (no raw `echo`)
- [ ] Has `--help` flag that prints usage
- [ ] Uses `readonly` for constants
- [ ] Validates required commands with `require_command`
- [ ] Handles errors with `die` or explicit error messages
- [ ] Uses `get_repo_root` instead of hardcoded `../..`
- [ ] Works when run from any directory

### Manual Testing

```bash
# Test from repository root
cd /path/to/project
./scripts/deploy.sh --help

# Test from script directory
cd /path/to/project/scripts
./deploy.sh --help

# Test with missing dependencies
mv /usr/local/bin/flutter /usr/local/bin/flutter.bak
./scripts/deploy.sh  # Should fail with clear message

# Test error handling
./scripts/deploy.sh --invalid-flag  # Should show usage
```

---

## Examples

### Minimal Script

```bash
#!/usr/bin/env bash

################################################################################
# your-project Hello World
################################################################################
# PURPOSE: Example script demonstrating standardized style
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
init_script

main() {
    log_header "Hello World Example"
    log_info "Hello from your-project!"
    log_success "Example complete"
}

main "$@"
```

### Full-Featured Script

```bash
#!/usr/bin/env bash

################################################################################
# your-project Deployment Script
################################################################################
# PURPOSE: Deploy application to AWS infrastructure
#   - Validates environment configuration
#   - Builds application artifacts
#   - Deploys to S3 and CloudFront
#   - Invalidates CDN cache
#
# USAGE:
#   ./deploy.sh [OPTIONS]
#
# OPTIONS:
#   --env ENV          Environment (dev, staging, prod)
#   --skip-build       Skip build step (use existing artifacts)
#   --dry-run          Show what would be deployed without deploying
#
# EXAMPLES:
#   ./deploy.sh --env dev
#   ./deploy.sh --env prod --skip-build
#
# DEPENDENCIES:
#   - aws-cli (brew install awscli)
#   - node (brew install node)
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
init_script

readonly REPO_ROOT="$(get_repo_root)"
readonly BUILD_DIR="$REPO_ROOT/build"

# Configuration
ENVIRONMENT=""
SKIP_BUILD=false
DRY_RUN=false

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                ENVIRONMENT="$2"
                shift 2
                ;;
            --skip-build)
                SKIP_BUILD=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                die "Unknown option: $1"
                ;;
        esac
    done

    # Validate required arguments
    [[ -z "$ENVIRONMENT" ]] && die "Missing required argument: --env"

    # Validate environment value
    case "$ENVIRONMENT" in
        dev|staging|prod) ;;
        *) die "Invalid environment: $ENVIRONMENT (must be dev, staging, or prod)" ;;
    esac
}

print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Deploy application to AWS infrastructure

Options:
    --env ENV          Environment to deploy to (dev, staging, prod)
    --skip-build       Skip build step
    --dry-run          Show deployment plan without executing
    -h, --help         Show this help message

Examples:
    $(basename "$0") --env dev
    $(basename "$0") --env prod --skip-build
EOF
}

validate_environment() {
    log_section "Validating Environment"

    require_command "aws" "brew install awscli"
    require_command "node" "brew install node"
    require_file "$REPO_ROOT/.env" "Copy .env.example to .env"

    # Load environment variables
    set -a
    source "$REPO_ROOT/.env"
    set +a

    # Verify AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        die "AWS credentials not configured. Run: aws configure"
    fi

    log_success "Environment validated"
}

build_application() {
    if [[ "$SKIP_BUILD" == true ]]; then
        log_section "Skipping Build (using existing artifacts)"
        return 0
    fi

    log_section "Building Application"

    # Clean previous build
    rm -rf "$BUILD_DIR"
    mkdir -p "$BUILD_DIR"

    # Build
    if ! npm run build; then
        die "Build failed"
    fi

    log_success "Build complete"
}

deploy_to_s3() {
    log_section "Deploying to S3"

    local bucket="app-${ENVIRONMENT}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would deploy to s3://$bucket"
        return 0
    fi

    if ! aws s3 sync "$BUILD_DIR" "s3://$bucket" --delete; then
        die "S3 deployment failed"
    fi

    log_success "Deployed to S3: s3://$bucket"
}

invalidate_cache() {
    log_section "Invalidating CloudFront Cache"

    local distribution_id="${CLOUDFRONT_DISTRIBUTION_ID}"

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN: Would invalidate distribution $distribution_id"
        return 0
    fi

    if ! aws cloudfront create-invalidation \
        --distribution-id "$distribution_id" \
        --paths "/*" &> /dev/null; then
        log_warning "Cache invalidation failed (non-critical)"
        return 0
    fi

    log_success "Cache invalidated"
}

main() {
    log_header "your-project Deployment - $ENVIRONMENT"

    validate_environment
    build_application
    deploy_to_s3
    invalidate_cache

    log_success "Deployment complete!"
    log_info "Application URL: https://${CLOUDFRONT_URL}"
}

parse_arguments "$@"
main
```

---

## Anti-Patterns

### Never Do This

```bash
# ❌ Don't use raw echo with color codes
echo -e "\033[0;32mSuccess\033[0m"

# ❌ Don't use cd without validation
cd ../../recipe_archive

# ❌ Don't ignore errors
flutter build ios || true

# ❌ Don't use unclear variable names
x="debug"
tmp="/tmp/build"

# ❌ Don't use magic numbers
sleep 5  # Why 5 seconds?

# ❌ Don't duplicate common code
RED='\033[0;31m'
GREEN='\033[0;32m'
# (Use common library instead)
```

---

## Customization for Your Project

**To adopt for your project**:

1. Copy `common.sh` to `scripts/lib/common.sh`
2. Update project name in headers (change "your-project" to your project name)
3. Add project-specific helper functions to `common.sh`
4. Create script templates in your docs/
5. Enforce standards in code reviews

**Project-Specific Extensions**:

```bash
# Add to scripts/lib/project-helpers.sh

# Project-specific validation
validate_project_config() {
    require_file "$REPO_ROOT/config/app.yaml"
    # ... more checks
}

# Project-specific deployment
deploy_to_production() {
    log_section "Deploying to Production"
    # ... deployment logic
}
```

---

**Remember**: Consistent shell scripts are maintainable shell scripts. Use the common library religiously.
