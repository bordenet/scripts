# Pre-Commit Hooks

## Purpose

Block broken code from entering git history by running automated checks before each commit.

## Implementation (Husky)

**1. Install Husky**

```bash
npm install --save-dev husky
npx husky install
```

**2. Create Pre-Commit Hook** (`.husky/pre-commit`)

```bash
#!/usr/bin/env bash
npm test
```

**3. Make Hook Executable**

```bash
chmod +x .husky/pre-commit
```

**4. Configure package.json**

```json
{
  "scripts": {
    "prepare": "husky install"
  }
}
```

## Additional Hooks

### Block Binaries (`.husky/check-binaries`)

**Purpose**: Prevent compiled binaries from being committed (platform-specific, should be built from source).

```bash
#!/usr/bin/env bash
set -e

echo "🔍 Checking for compiled binaries..."

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

BINARIES_FOUND=()

while IFS= read -r file; do
    if [ ! -f "$file" ]; then
        continue
    fi

    FILE_TYPE=$(file -b "$file" 2>/dev/null || echo "unknown")

    if echo "$FILE_TYPE" | grep -qiE "(executable|Mach-O|ELF|PE32|shared object)"; then
        if ! echo "$FILE_TYPE" | grep -qiE "(shell script|text|ASCII)"; then
            BINARIES_FOUND+=("$file")
        fi
    fi
done <<< "$STAGED_FILES"

if [ ${#BINARIES_FOUND[@]} -gt 0 ]; then
    echo "❌ ERROR: Compiled binaries detected"
    for binary in "${BINARIES_FOUND[@]}"; do
        echo "  ✗ $binary"
    done
    echo ""
    echo "To fix: git reset HEAD <file>"
    exit 1
fi

echo "✅ No binaries detected"
```

### Protect Critical Files (`.husky/protect-prds`)

```bash
#!/usr/bin/env bash

# Prevent accidental modification of critical requirement documents
PROTECTED_FILES=(
  "docs/requirements/aws-backend.md"
  "docs/requirements/ios-app.md"
  "docs/architecture/data-model.md"
)

for file in "${PROTECTED_FILES[@]}"; do
  if git diff --cached --name-only | grep -q "^$file$"; then
    echo "❌ Cannot modify protected file: $file"
    echo "These files require explicit review before changes."
    exit 1
  fi
done
```

## Testing Pre-Commit Hooks

```bash
# Test the hook manually
./.husky/pre-commit

# Force commit to bypass (use sparingly!)
git commit --no-verify -m "Emergency fix"
```

