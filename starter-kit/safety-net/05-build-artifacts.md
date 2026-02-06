# Build Artifact Protection

## .gitignore Patterns

**Critical Categories**:

```gitignore
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
*.a
*.o
tools/*/bin/*
aws-backend/functions/*/bootstrap

# Build artifacts
node_modules/
dist/
build/
builds/
.dart_tool/
DerivedData/
cdk.out/
*.zip
*.ipa
*.apk
*.aab

# IDE and temp files
.vscode/
.idea/
*.swp
*.swo
.DS_Store

# Test artifacts
coverage/
test-results/
playwright-report/
.validation-logs/
```

## Why This Matters

**Bad Example** (artifacts in git):

```bash
# Clone repo
git clone repo
cd repo

# Try to build
./build.sh

# ERROR: Binary from macOS doesn't work on Linux
# ERROR: node_modules from old npm version conflicts
# ERROR: Build artifacts corrupt source files
```

**Good Example** (clean git):

```bash
# Clone repo
git clone repo
cd repo

# Install dependencies
./scripts/setup-linux.sh

# Build fresh
./build.sh

# ✅ Everything works (built for THIS platform)
```

