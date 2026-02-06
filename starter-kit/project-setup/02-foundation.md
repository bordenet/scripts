# Phase 1: Foundation (30 minutes)

## 1.1 Create Directory Structure

```bash
mkdir -p scripts/lib
mkdir -p scripts/setup-components
mkdir -p docs
mkdir -p build
mkdir -p tests
mkdir -p .husky
```

## 1.2 Copy Starter Kit Files

```bash
# From starter-kit directory
cp starter-kit/common.sh scripts/lib/common.sh
cp starter-kit/.gitignore.template .gitignore
cp starter-kit/.env.example .env.example
```

## 1.3 Create .gitignore

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
*.swo
.DS_Store

# Test artifacts
coverage/
test-results/
playwright-report/
.validation-logs/
```

## 1.4 Create .env.example

```bash
# AWS Configuration
AWS_REGION=us-west-2
AWS_ACCOUNT_ID=your-account-id

# Application Settings
APP_NAME=your-app-name
ENVIRONMENT=development

# Database (if applicable)
DB_HOST=localhost
DB_PORT=5432
DB_NAME=your_db_name

# API Keys (NEVER commit real values)
API_KEY=your-api-key-here
```

## 1.5 Create scripts/lib/common.sh

```bash
#!/usr/bin/env bash

# Common functions for all scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${GREEN}✓${NC} $1"
}

log_error() {
  echo -e "${RED}✗${NC} $1" >&2
}

log_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

check_command() {
  if ! command -v "$1" &> /dev/null; then
    log_error "$1 is not installed"
    return 1
  fi
}
```

## Verification

```bash
# Check directory structure
ls -la scripts/
ls -la .husky/

# Verify .gitignore exists
cat .gitignore | head -20

# Verify .env.example exists
cat .env.example
```

