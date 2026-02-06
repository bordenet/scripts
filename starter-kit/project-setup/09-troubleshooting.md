# Troubleshooting

## Pre-Commit Hooks Not Running

**Symptom**: Commits succeed even when they should fail

**Solution**:

```bash
# Reinstall Husky
rm -rf .husky
npx husky install

# Recreate hooks
npx husky add .husky/pre-commit "npm test"

# Make hooks executable
chmod +x .husky/pre-commit
chmod +x .husky/check-binaries
chmod +x .husky/check-protected-files
```

## Validation Script Fails

**Symptom**: `./validate-monorepo.sh` exits with errors

**Solution**:

```bash
# Check script permissions
chmod +x validate-monorepo.sh

# Check for syntax errors
bash -n validate-monorepo.sh

# Run with debug output
bash -x validate-monorepo.sh --p1
```

## Setup Script Fails on macOS

**Symptom**: `./scripts/setup-macos.sh` fails to install dependencies

**Solution**:

```bash
# Update Homebrew
brew update

# Check for conflicting installations
brew doctor

# Reinstall problematic packages
brew reinstall node
```

## Setup Script Fails on Linux

**Symptom**: `./scripts/setup-linux.sh` fails with permission errors

**Solution**:

```bash
# Run with sudo for system packages
sudo ./scripts/setup-linux.sh

# Or install to user directory
npm config set prefix ~/.local
```

## CI/CD Pipeline Fails

**Symptom**: GitHub Actions workflow fails

**Solution**:

```bash
# Check workflow syntax
cat .github/workflows/ci.yml

# Test locally with act
brew install act
act -j validate

# Check GitHub secrets
# Visit: Settings → Secrets and variables → Actions
```

## Dependencies Not Installing

**Symptom**: `npm install` or `go mod download` fails

**Solution**:

```bash
# Clear npm cache
npm cache clean --force
rm -rf node_modules package-lock.json
npm install

# Clear Go cache
go clean -modcache
go mod download
```

## Common Errors

### "command not found: husky"

```bash
npm install --save-dev husky
npx husky install
```

### "permission denied: ./validate-monorepo.sh"

```bash
chmod +x validate-monorepo.sh
```

### ".env file is tracked in git"

```bash
git rm --cached .env
echo ".env" >> .gitignore
git add .gitignore
git commit -m "Remove .env from git"
```

## Getting Help

1. Check documentation in `starter-kit/` directory
2. Review error messages carefully
3. Search GitHub issues
4. Ask in team chat with full error output

