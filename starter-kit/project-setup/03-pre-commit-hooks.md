# Phase 2: Pre-Commit Hooks (30 minutes)

## 2.1 Install Husky

```bash
npm install --save-dev husky
npx husky install
npm pkg set scripts.prepare="husky install"
```

## 2.2 Create Pre-Commit Hook

Create `.husky/pre-commit`:

```bash
#!/usr/bin/env bash
. "$(dirname -- "$0")/_/husky.sh"

# Run validation
./validate-monorepo.sh --p1

# Check for binaries
./.husky/check-binaries

# Check for protected files
./.husky/check-protected-files
```

Make it executable:

```bash
chmod +x .husky/pre-commit
```

## 2.3 Create Binary Detection Hook

Create `.husky/check-binaries`:

```bash
#!/usr/bin/env bash

BINARY_PATTERNS=(
  "*.exe"
  "*.dll"
  "*.bin"
  "*.a"
  "*.o"
  "**/bin/*"
)

for pattern in "${BINARY_PATTERNS[@]}"; do
  if git diff --cached --name-only | grep -E "$pattern"; then
    echo "❌ ERROR: Attempting to commit binary file: $pattern"
    echo "Binaries should be built from source, not committed to git"
    exit 1
  fi
done
```

Make it executable:

```bash
chmod +x .husky/check-binaries
```

## 2.4 Create Protected Files Hook

Create `.husky/check-protected-files`:

```bash
#!/usr/bin/env bash

PROTECTED_FILES=(
  ".env"
  "aws-credentials.json"
  "secrets.json"
  "*.pem"
  "*.key"
)

for pattern in "${PROTECTED_FILES[@]}"; do
  if git diff --cached --name-only | grep -E "$pattern"; then
    echo "❌ ERROR: Attempting to commit protected file: $pattern"
    echo "This file contains secrets and should NEVER be committed"
    exit 1
  fi
done
```

Make it executable:

```bash
chmod +x .husky/check-protected-files
```

## Verification

```bash
# Test by trying to commit a binary
touch test.exe
git add test.exe
git commit -m "Test"  # Should fail

# Clean up
git reset HEAD test.exe
rm test.exe
```

