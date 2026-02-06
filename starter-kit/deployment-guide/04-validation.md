# Validation After Deployment

## Test Pre-Commit Hooks

```bash
# Test binary detection
touch test.exe
git add test.exe
git commit -m "Test"  # Should fail
git reset HEAD test.exe
rm test.exe

# Test protected file detection
touch .env
git add .env
git commit -m "Test"  # Should fail
git reset HEAD .env
rm .env
```

## Test Validation Tiers

```bash
# Test P1 (should be fast)
time ./validate-monorepo.sh --p1

# Test medium (should run linters)
time ./validate-monorepo.sh --med

# Test all (should run everything)
time ./validate-monorepo.sh --all
```

## Test Setup Scripts

```bash
# On a fresh VM or container
./scripts/setup-macos.sh  # or setup-linux.sh

# Verify all tools installed
git --version
node --version
npm --version
```

## Verify File Locations

```bash
# Check all files are in correct locations
ls -la docs/SAFETY_NET.md
ls -la CLAUDE.md
ls -la scripts/lib/common.sh
ls -la .husky/pre-commit
ls -la .husky/check-binaries
ls -la .env.example
```

## Success Criteria

- [ ] Pre-commit hooks block binaries and credentials
- [ ] `./validate-monorepo.sh --p1` passes in <30 seconds
- [ ] Setup scripts work on fresh machine
- [ ] All documentation is customized (no "your-project" placeholders)
- [ ] .env.example contains project-specific variables
- [ ] .gitignore contains project-specific patterns

