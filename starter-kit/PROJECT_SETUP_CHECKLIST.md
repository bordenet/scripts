# Project Setup Checklist

**Purpose**: Step-by-step guide to bootstrap a new project with comprehensive safety nets from day one.

**Time Estimate**: 2-4 hours for complete setup

---

## Prerequisites

- [ ] **Git repository initialized**
  ```bash
  git init
  git add .
  git commit -m "Initial commit"
  ```

- [ ] **Project structure decided**
  - Monorepo vs. polyrepo
  - Languages/frameworks (Go, Node.js, Python, Flutter, etc.)
  - Deployment target (AWS, GCP, Azure, self-hosted)

- [ ] **Development machine ready**
  - macOS, Linux, or WSL2 on Windows
  - Admin/sudo access
  - Internet connection

---

## Phase 1: Foundation (30 minutes)

### 1.1 Create Directory Structure

```bash
mkdir -p scripts/lib
mkdir -p scripts/setup-components
mkdir -p docs
mkdir -p build
mkdir -p tests
mkdir -p .husky
```

### 1.2 Copy Starter Kit Files

```bash
# From starter-kit directory
cp starter-kit/common.sh scripts/lib/common.sh
cp starter-kit/.gitignore.template .gitignore
cp starter-kit/.env.example .env.example
```

### 1.3 Create .gitignore

```gitignore
# Copy from starter-kit/.gitignore.template and customize
# Key sections:

# SECURITY: Never commit credentials
.env
.env.local
.env.*.local
aws-credentials.json
secrets.json
*.pem
*.key

# Binaries (platform-specific, build from source)
*.exe
*.dll
*.bin
**/bin/*
**/*-darwin-*
**/*-linux-*
**/*-windows-*

# Build artifacts
node_modules/
dist/
build/
builds/
.dart_tool/
DerivedData/
cdk.out/
*.zip

# IDE and temp files
.vscode/
.idea/
*.swp
.DS_Store

# Test artifacts
coverage/
test-results/
.validation-logs/
```

### 1.4 Create .env.example

```bash
# Copy from starter-kit and customize for your project

# ------------------------------------------------------------------------------
# AWS Configuration (if using AWS)
# ------------------------------------------------------------------------------
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=your-account-id-here

# ------------------------------------------------------------------------------
# Application Settings
# ------------------------------------------------------------------------------
ENVIRONMENT=dev
PROJECT_NAME=YourProject

# ------------------------------------------------------------------------------
# Testing Credentials (never commit real values)
# ------------------------------------------------------------------------------
TEST_USER_EMAIL=
TEST_USER_PASSWORD=
```

**Checklist**:
- [ ] `.gitignore` created with all critical patterns
- [ ] `.env.example` created with all required variables
- [ ] `.env` added to `.gitignore`
- [ ] `common.sh` copied to `scripts/lib/common.sh`
- [ ] Directory structure created

---

## Phase 2: Pre-Commit Hooks (30 minutes)

### 2.1 Install Husky

```bash
npm init -y  # If no package.json exists
npm install --save-dev husky
npx husky install
npm pkg set scripts.prepare="husky install"
```

### 2.2 Create Basic Pre-Commit Hook

```bash
# .husky/pre-commit
#!/usr/bin/env bash
echo "🔍 Running pre-commit checks..."
npm test
```

```bash
chmod +x .husky/pre-commit
```

### 2.3 Create Binary Detection Hook

```bash
# .husky/check-binaries
#!/usr/bin/env bash
# Copy from starter-kit/check-binaries-template
```

```bash
chmod +x .husky/check-binaries
```

### 2.4 Update Pre-Commit to Include Binary Check

```bash
# .husky/pre-commit
#!/usr/bin/env bash
./.husky/check-binaries
npm test
```

### 2.5 Test Hooks

```bash
# Test binary detection
touch test-binary
chmod +x test-binary
git add test-binary
git commit -m "Test binary detection"  # Should fail

# Clean up
rm test-binary

# Test normal commit
echo "test" > test.txt
git add test.txt
git commit -m "Test commit"  # Should pass
```

**Checklist**:
- [ ] Husky installed
- [ ] `.husky/pre-commit` created
- [ ] `.husky/check-binaries` created
- [ ] Hooks tested and working
- [ ] Both `.husky/pre-commit` and `.husky/check-binaries` executable

---

## Phase 3: Dependency Management (1-2 hours)

### 3.1 Create Setup Script

```bash
# scripts/setup-<platform>.sh
# Copy template from starter-kit/setup-template.sh
```

### 3.2 Define Modular Components

```bash
# scripts/setup-components/00-package-manager.sh
install_package_manager() {
  # Homebrew for macOS, apt for Ubuntu, etc.
}

# scripts/setup-components/10-essentials.sh
install_essentials() {
  # git, wget, curl, jq, etc.
}

# scripts/setup-components/20-languages.sh
install_languages() {
  # Node.js, Python, Go, etc.
}

# scripts/setup-components/30-tools.sh
install_tools() {
  # Project-specific CLI tools
}

# scripts/setup-components/40-env.sh
configure_environment() {
  # .env setup, PATH configuration
}
```

### 3.3 Implement Main Setup Script

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
init_script

# Source all components
for component in "$SCRIPT_DIR/setup-components"/*.sh; do
  source "$component"
done

# Run installation
log_header "Project Setup"

install_package_manager
install_essentials
install_languages
install_tools
configure_environment

log_success "Setup complete!"
```

### 3.4 Test Setup Script

```bash
# Test in Docker container (macOS example)
docker run -it --rm -v $(pwd):/workspace ubuntu:22.04 bash
cd /workspace
./scripts/setup-ubuntu.sh --yes

# Or test on fresh VM
```

**Checklist**:
- [ ] `scripts/setup-<platform>.sh` created
- [ ] Setup components created (modular)
- [ ] Script includes ALL dependencies
- [ ] Script tested on clean machine
- [ ] Documentation updated with setup command

---

## Phase 4: Validation System (1-2 hours)

### 4.1 Create Validation Script

```bash
# validate-monorepo.sh
# Copy from starter-kit/validate-template.sh
```

### 4.2 Define Validation Tiers

```bash
declare -A TEST_TIERS
TEST_TIERS[p1]="dependencies builds_core tests_unit"
TEST_TIERS[med]="${TEST_TIERS[p1]} builds_extended linting"
TEST_TIERS[all]="${TEST_TIERS[med]} tests_e2e security_scan"
```

### 4.3 Implement Validation Functions

```bash
validate_dependencies() {
  log_section "Validating Dependencies"
  require_command "node" "Run: ./scripts/setup-macos.sh"
  require_command "go" "Run: ./scripts/setup-macos.sh"
  log_success "Dependencies validated"
}

validate_builds() {
  log_section "Validating Builds"
  npm run build || die "npm build failed"
  go build ./... || die "go build failed"
  log_success "Builds validated"
}

validate_tests() {
  log_section "Running Tests"
  npm test || die "npm tests failed"
  go test ./... || die "go tests failed"
  log_success "Tests passed"
}

validate_linting() {
  log_section "Running Linters"
  npm run lint || die "npm lint failed"
  golangci-lint run ./... || die "golangci-lint failed"
  log_success "Linting passed"
}

validate_security() {
  log_section "Security Scanning"
  npm audit --audit-level=high || die "npm audit failed"
  # Add gitleaks, etc.
  log_success "Security checks passed"
}
```

### 4.4 Test Validation

```bash
# Test each tier
./validate-monorepo.sh --p1
./validate-monorepo.sh --med
./validate-monorepo.sh --all
```

**Checklist**:
- [ ] `validate-monorepo.sh` created
- [ ] Validation tiers defined (p1, med, all)
- [ ] Dependency checks implemented
- [ ] Build validation implemented
- [ ] Test execution implemented
- [ ] Linting validation implemented
- [ ] Security scanning implemented
- [ ] All tiers tested

---

## Phase 5: CI/CD Integration (30 minutes)

### 5.1 Create GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  validate:
    runs-on: ubuntu-latest

    steps:
    - uses: actions/checkout@v3

    - name: Setup environment
      run: ./scripts/setup-ubuntu.sh --yes

    - name: Run validation
      run: ./validate-monorepo.sh --all

    - name: Security scan
      run: npm audit --audit-level=high
```

### 5.2 Test CI Pipeline

```bash
# Create test PR
git checkout -b test-ci
git push origin test-ci

# Check GitHub Actions tab for results
```

**Checklist**:
- [ ] `.github/workflows/ci.yml` created
- [ ] CI runs validation on push
- [ ] CI runs on pull requests
- [ ] CI tested with real PR
- [ ] CI status badge added to README

---

## Phase 6: Documentation (30 minutes)

### 6.1 Create Project Guide (CLAUDE.md)

```bash
# Copy from starter-kit/DEVELOPMENT_PROTOCOLS.md
# Customize for your project
```

**Include**:
- Git workflow policy
- Build commands
- Test commands
- Deployment commands
- Common tasks
- Debugging protocols

### 6.2 Create README.md

```markdown
# ProjectName

**Description**: One sentence description

## Quick Start

\`\`\`bash
# 1. Clone repository
git clone <repo-url>
cd <project>

# 2. Install dependencies
./scripts/setup-macos.sh

# 3. Create environment file
cp .env.example .env
# Edit .env with your values

# 4. Build
npm run build

# 5. Test
npm test

# 6. Run
npm start
\`\`\`

## Development

- **Setup**: `./scripts/setup-macos.sh`
- **Build**: `npm run build`
- **Test**: `npm test`
- **Validate**: `./validate-monorepo.sh --p1`
- **Deploy**: `./scripts/deploy.sh`

## Documentation

- [Development Guide](CLAUDE.md)
- [Setup Checklist](docs/PROJECT_SETUP_CHECKLIST.md)
- [Style Guide](docs/CODING_STANDARDS.md)

## Contributing

See [CLAUDE.md](CLAUDE.md) for development protocols.
```

**Checklist**:
- [ ] `CLAUDE.md` created
- [ ] `README.md` created
- [ ] Quick start instructions tested
- [ ] All documentation links work

---

## Phase 7: Final Validation (15 minutes)

### 7.1 Complete Test

```bash
# 1. Clone repository fresh
cd /tmp
git clone <your-repo-url> test-project
cd test-project

# 2. Run setup
./scripts/setup-macos.sh --yes

# 3. Validate
./validate-monorepo.sh --all

# 4. Clean up
cd ..
rm -rf test-project
```

### 7.2 Final Checklist

- [ ] Fresh clone works with setup script
- [ ] Validation passes on clean clone
- [ ] Pre-commit hooks work
- [ ] CI pipeline runs successfully
- [ ] Documentation is complete and accurate
- [ ] `.env.example` has all required variables
- [ ] `.gitignore` blocks all sensitive files
- [ ] Binary detection hook prevents compiled files

---

## Maintenance Schedule

### Daily
- Pre-commit hooks run automatically

### Weekly
- [ ] Run `./validate-monorepo.sh --all`
- [ ] Review pre-commit hook execution times

### Monthly
- [ ] Update dependencies in `setup-<platform>.sh`
- [ ] Review `.gitignore` for new artifact patterns
- [ ] Audit `.env.example` for completeness

### Quarterly
- [ ] Test `setup-<platform>.sh` on fresh VM
- [ ] Review security scanning tools
- [ ] Audit pre-commit hooks effectiveness

---

## Customization Guide

**For your specific project, customize**:

1. **Languages/Frameworks**
   - Add language-specific linting (ESLint, golangci-lint, etc.)
   - Add framework-specific builds (Flutter, React, etc.)

2. **Cloud Provider**
   - AWS-specific validation (CDK synth, etc.)
   - GCP-specific validation (gcloud, etc.)

3. **Deployment**
   - Add deployment validation
   - Add environment-specific checks

4. **Testing**
   - Add E2E tests
   - Add integration tests
   - Add performance tests

---

## Troubleshooting

**Setup script fails**:
- Check internet connection
- Verify admin/sudo access
- Review error messages in logs
- Try running setup components individually

**Pre-commit hooks not running**:
```bash
# Reinstall Husky
rm -rf .husky
npm run prepare
```

**Validation fails unexpectedly**:
```bash
# Run validation with debug output
DEBUG=1 ./validate-monorepo.sh --p1

# Check individual validations
./validate-monorepo.sh --help
```

---

## Success Criteria

Your project is production-ready when:

- [✅] New developers can set up in <30 minutes with one command
- [✅] Broken code cannot be committed (pre-commit hooks block)
- [✅] No credentials in git history (verified with gitleaks)
- [✅] CI pipeline runs on all PRs
- [✅] Validation passes on fresh clone
- [✅] Documentation is complete and accurate

---

**Setup complete! You've built a comprehensive safety net.** 🎉
