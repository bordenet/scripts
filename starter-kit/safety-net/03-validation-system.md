# Validation System

## Architecture

**Multi-tier validation** allows fast feedback for commits and comprehensive checks for releases:

| Tier | Duration | Use Case | What Runs |
|------|----------|----------|-----------|
| **p1** | ~20-30s | Pre-commit | Dependencies, core builds, critical tests |
| **med** | ~2-5min | Pre-push | P1 + extended builds, basic quality checks |
| **all** | ~5-10min | Pre-release | Everything (E2E tests, security scans, infrastructure) |

## Implementation (validate-monorepo.sh)

**Core Structure**:

```bash
#!/usr/bin/env bash

set -euo pipefail

# Tier definitions
declare -A TEST_TIERS
TEST_TIERS[p1]="dependencies builds_core tests_unit"
TEST_TIERS[med]="${TEST_TIERS[p1]} builds_extended linting"
TEST_TIERS[all]="${TEST_TIERS[med]} tests_e2e security_scan infra_check"

# Parse arguments
VALIDATION_TIER="med"  # Default

while [[ $# -gt 0 ]]; do
  case $1 in
    --p1)  VALIDATION_TIER="p1"; shift ;;
    --med) VALIDATION_TIER="med"; shift ;;
    --all) VALIDATION_TIER="all"; shift ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# Run validations for selected tier
SELECTED_TESTS="${TEST_TIERS[$VALIDATION_TIER]}"

for test in $SELECTED_TESTS; do
  run_validation "$test"
done
```

## Key Validations

**1. Dependency Checks**

```bash
validate_dependencies() {
  require_command "node" "brew install node"
  require_command "go" "brew install go"
  require_command "flutter" "brew install flutter"

  # Check versions
  node_version=$(node --version)
  [[ "$node_version" =~ ^v18 ]] || die "Node.js 18+ required"
}
```

**2. Build Validation**

```bash
validate_builds() {
  # Go builds
  for dir in tools/*/; do
    (cd "$dir" && go build) || die "Go build failed: $dir"
  done

  # Node.js builds
  npm run build || die "npm build failed"

  # Flutter builds
  (cd recipe_archive && flutter build web) || die "Flutter build failed"
}
```

**3. Test Execution**

```bash
validate_tests() {
  # Unit tests
  npm test || die "npm tests failed"

  # Go tests
  go test ./... || die "Go tests failed"

  # E2E tests (only in 'all' tier)
  if [[ "$VALIDATION_TIER" == "all" ]]; then
    npm run test:e2e || die "E2E tests failed"
  fi
}
```

**4. Security Scanning**

```bash
validate_security() {
  # Check for secrets in code
  if command -v gitleaks &> /dev/null; then
    gitleaks detect --no-git || die "Secrets detected"
  fi

  # npm audit
  npm audit --audit-level=high || die "npm audit failed"

  # Go vulnerability check
  govulncheck ./... || die "Go vulnerabilities found"
}
```

## Progress Dashboard

Use Go-based validator for real-time progress:

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ your-project Monorepo Validation (med)  ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

Prerequisites     ████████████████████  100%  ✓
Dependencies      ████████████████████  100%  ✓
Core Builds       ████████████░░░░░░░░   65%  ...
Extended Builds   ░░░░░░░░░░░░░░░░░░░░    0%
Linting           ░░░░░░░░░░░░░░░░░░░░    0%

Elapsed: 45s  |  ETA: 2m 15s
```

