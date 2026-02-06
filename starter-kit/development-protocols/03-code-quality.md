# Code Quality Gates

## Go Compilation Protocol

**MANDATORY**: Always run compilation checks before declaring Go work complete.

```bash
# 1. Fix linting errors
golangci-lint run ./...

# 2. CRITICAL: Check compilation
go build

# 3. If imports are unused, remove them
# Then re-run both checks
golangci-lint run ./...
go build

# 4. Only declare work complete after BOTH pass
```

**Common Gotcha**: Removing unused functions often leaves behind unused imports. The `go build` check catches this immediately.

**Why This Matters**: Unused imports are compilation errors in Go, not just linting warnings.

## JavaScript/TypeScript Linting

**MANDATORY**: Always use double quotes.

```bash
# After editing JavaScript files
npm run lint -- --fix
```

**Enforcement** (`.eslintrc.json`):

```json
{
  "rules": {
    "quotes": ["error", "double"]
  }
}
```

## Pre-Push Validation

```bash
# Before pushing to remote
./validate-monorepo.sh --p1    # Quick check (~30s)

# Before creating PR
./validate-monorepo.sh --med   # Medium check (~2-5min)

# Before releasing
./validate-monorepo.sh --all   # Full check (~5-10min)
```

## Checklist

**Before Committing**:
1. Run `./validate-monorepo.sh --p1` (if available)
2. Check that you haven't staged binaries or credentials
3. Write descriptive commit message (imperative mood)

**Before Creating PR**:
1. Review ALL commits from branch divergence
2. Include comprehensive summary (not just latest commit)
3. Add test plan and related issues

