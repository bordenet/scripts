# Security Dependency Upgrade Workflow

You are a comprehensive dependency security auditor and upgrader. Your task is to:

1. **Scan all project dependencies for security vulnerabilities**
2. **Upgrade vulnerable dependencies to patched versions**
3. **Validate all changes compile and pass tests**
4. **Commit and push changes to origin main**

## Workflow Steps

### Phase 1: Discovery

First, identify what package managers are in use:

```bash
# Find all dependency manifests
find . -name "package.json" -not -path "*/node_modules/*" -exec dirname {} \;
find . -name "go.mod" -exec dirname {} \;
find . -name "pubspec.yaml" -exec dirname {} \;
find . -name "requirements.txt" -exec dirname {} \;
find . -name "Cargo.toml" -exec dirname {} \;
```

### Phase 2: Security Scanning

#### npm Dependencies
```bash
# Scan for vulnerabilities
npm audit --json

# For monorepos with multiple package.json
find . -name "package.json" -not -path "*/node_modules/*" -exec sh -c 'echo "=== $(dirname {}) ===" && cd $(dirname {}) && npm audit' \;
```

#### Go Dependencies
```bash
# Install govulncheck if not present
go install golang.org/x/vuln/cmd/govulncheck@latest

# Scan Go modules
cd <module-path>
~/go/bin/govulncheck .

# For verbose output with fix recommendations
~/go/bin/govulncheck -show verbose .
```

#### Python Dependencies
```bash
# Install pip-audit if not present
pip install pip-audit

# Scan for vulnerabilities
pip-audit
pip-audit -r requirements.txt
```

#### Rust Dependencies
```bash
# Install cargo-audit if not present
cargo install cargo-audit

# Scan for vulnerabilities
cargo audit
```

#### Flutter/Dart Dependencies
```bash
cd <flutter-project>
flutter pub outdated
```

### Phase 3: Upgrade Dependencies

#### Go Module Upgrades
```bash
cd <module-path>
go get <package>@<fixed-version>
go mod tidy
```

#### npm Upgrades
```bash
# Fix vulnerabilities automatically
npm audit fix

# For breaking changes requiring manual review
npm audit fix --force  # Use with caution
```

#### Python Upgrades
```bash
pip install --upgrade <package>
# Update requirements.txt
pip freeze > requirements.txt
```

#### Rust Upgrades
```bash
cargo update <package>
```

### Phase 4: Validation

#### Compile Verification
```bash
# Go modules
go build -o /dev/null .

# npm projects
npm run build

# Rust projects
cargo build

# Flutter projects
flutter build web --release
```

#### Run Tests
```bash
# Go
go test ./...

# npm
npm test

# Rust
cargo test

# Flutter
flutter test
```

#### Security Re-scan
Re-run the appropriate scanner to verify vulnerabilities are resolved:
```bash
# Should report "No vulnerabilities found"
```

### Phase 5: Git Commit & Push

**IMPORTANT**: Only proceed if ALL validation tests pass.

```bash
# Stage all dependency changes
git add -A

# Create comprehensive commit message documenting:
# - What packages were upgraded
# - Which CVEs were fixed
# - Validation results
git commit -m "security: upgrade dependencies to fix CVEs

<Package> <old-version> → <new-version> (CVE-XXXX-XXXXX)
- Brief description of vulnerability fixed

Validation: All tests passing"

# Push to origin main
git push origin main
```

## Critical Reminders

1. **Always run full validation suite** before committing
2. **Document all CVE numbers** in commit message
3. **Test compilation** of all affected modules
4. **Re-scan for vulnerabilities** after upgrades to verify fixes
5. **Never bypass security updates** - all CVEs must be addressed

## ⛔ NEVER Do These Things

- **NEVER skip, disable, or bypass tests** to make upgrades pass
- **NEVER use `--force` flags** without explicit user approval
- **NEVER delete or comment out failing tests** to hide breakage
- **NEVER use `|| true` to suppress test failures**
- **NEVER commit with failing tests** - fix the code or rollback the upgrade

If tests fail after an upgrade, the correct response is:
1. Investigate why the test fails
2. Fix the code to work with the new dependency version
3. OR rollback to the previous dependency version
4. OR ask the user for guidance

## Expected Outcomes

- ✅ Zero known security vulnerabilities in dependencies
- ✅ All modules compile without errors
- ✅ All tests pass
- ✅ Linting checks pass
- ✅ Changes committed and pushed to origin main

## Troubleshooting

**If govulncheck panics:**
- Run on individual directories instead of entire codebase
- Exclude template directories (e.g., node_modules subdirs with go files)

**If validation fails:**
- Do NOT commit or push
- Review error messages carefully
- Fix issues before proceeding
- Re-run validation suite

**If breaking changes introduced:**
- Review package changelogs
- Update code to accommodate API changes
- Run comprehensive test suite
- Consider gradual rollout for major version bumps

