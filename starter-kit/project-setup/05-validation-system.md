# Phase 4: Validation System (1-2 hours)

## 4.1 Create validate-monorepo.sh

Create `validate-monorepo.sh`:

```bash
#!/usr/bin/env bash

set -euo pipefail

source scripts/lib/common.sh

TIER="${1:---p1}"

log_info "Running validation tier: $TIER"

case "$TIER" in
  --p1)
    run_p1_validation
    ;;
  --med)
    run_p1_validation
    run_med_validation
    ;;
  --all)
    run_p1_validation
    run_med_validation
    run_all_validation
    ;;
  *)
    log_error "Unknown tier: $TIER"
    echo "Usage: $0 [--p1|--med|--all]"
    exit 1
    ;;
esac

log_info "Validation complete!"
```

Make it executable:

```bash
chmod +x validate-monorepo.sh
```

## 4.2 Add P1 Validation (Critical, ~30s)

Add to `validate-monorepo.sh`:

```bash
run_p1_validation() {
  log_info "P1: Checking for secrets..."
  
  # Check for .env files
  if git ls-files | grep -E "^\.env$"; then
    log_error ".env file is tracked in git!"
    exit 1
  fi
  
  # Check for credential files
  if git ls-files | grep -E "\.(pem|key)$"; then
    log_error "Credential files found in git!"
    exit 1
  fi
  
  log_info "P1: No secrets detected"
}
```

## 4.3 Add Medium Validation (Important, ~2-5min)

Add to `validate-monorepo.sh`:

```bash
run_med_validation() {
  log_info "MED: Running linters..."
  
  # JavaScript/TypeScript
  if [ -f "package.json" ]; then
    npm run lint
  fi
  
  # Go
  if [ -f "go.mod" ]; then
    golangci-lint run ./...
  fi
  
  # Python
  if [ -f "requirements.txt" ]; then
    flake8 .
  fi
  
  log_info "MED: Linting complete"
}
```

## 4.4 Add Full Validation (Comprehensive, ~5-10min)

Add to `validate-monorepo.sh`:

```bash
run_all_validation() {
  log_info "ALL: Running tests..."
  
  # JavaScript/TypeScript
  if [ -f "package.json" ]; then
    npm test
  fi
  
  # Go
  if [ -f "go.mod" ]; then
    go test ./...
  fi
  
  # Python
  if [ -f "requirements.txt" ]; then
    pytest
  fi
  
  log_info "ALL: Running builds..."
  
  # Go
  if [ -f "go.mod" ]; then
    go build ./...
  fi
  
  log_info "ALL: Tests and builds complete"
}
```

## Verification

```bash
# Test each tier
./validate-monorepo.sh --p1    # Should pass quickly
./validate-monorepo.sh --med   # Should run linters
./validate-monorepo.sh --all   # Should run everything
```

