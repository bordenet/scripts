#!/usr/bin/env bash
# Security Check Script - Standalone version
# Scans for potential secrets and sensitive information
# Can be run as pre-commit hook or manually

set -euo pipefail

# Colors (only if terminal supports it)
if [[ -t 1 ]]; then
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[0;33m'
    C_RESET='\033[0m'
else
    C_RED='' C_GREEN='' C_YELLOW='' C_RESET=''
fi

# Navigate to project root (find .git directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."
PROJECT_ROOT=$(pwd)

echo "🔒 Security Check - Scanning for secrets..."

# Patterns to check for potential secrets
PATTERNS=(
    "password\s*[:=]\s*['\"][^'\"]{3,}['\"]"
    "api[_-]?key\s*[:=]\s*['\"][^'\"]{10,}['\"]"
    "secret\s*[:=]\s*['\"][^'\"]{10,}['\"]"
    "token\s*[:=]\s*['\"][^'\"]{10,}['\"]"
    "private[_-]?key\s*[:=]"
    "-----BEGIN\s+(RSA\s+)?PRIVATE\s+KEY-----"
    "sk-[a-zA-Z0-9]{32,}"        # OpenAI API keys
    "sk-ant-[a-zA-Z0-9]{32,}"    # Anthropic API keys
    "pplx-[a-zA-Z0-9]{32,}"      # Perplexity API keys
    "ghp_[a-zA-Z0-9]{36}"        # GitHub personal access tokens
    "gho_[a-zA-Z0-9]{36}"        # GitHub OAuth tokens
    "ghu_[a-zA-Z0-9]{36}"        # GitHub user-to-server tokens
    "ghs_[a-zA-Z0-9]{36}"        # GitHub server-to-server tokens
    "ghr_[a-zA-Z0-9]{36}"        # GitHub refresh tokens
    "AKIA[0-9A-Z]{16}"           # AWS Access Key IDs
)

ISSUES_FOUND=0

# Build exclude arguments for grep
EXCLUDE_DIRS="--exclude-dir=node_modules --exclude-dir=.git --exclude-dir=coverage --exclude-dir=.setup-cache --exclude-dir=build --exclude-dir=dist --exclude-dir=venv --exclude-dir=.venv --exclude-dir=.dart_tool --exclude-dir=Pods --exclude-dir=.gradle"
EXCLUDE_FILES="--exclude=check-secrets.sh --exclude=*.lock --exclude=package-lock.json --exclude=*.md --exclude=*.yaml --exclude=*.yml --exclude=.env --exclude=.env.* --exclude=*.env --exclude=*.eml --exclude=*.mbox"
GREP_OPTS="--binary-files=without-match"

# Check each pattern
for pattern in "${PATTERNS[@]}"; do
    if matches=$(grep -r -i -E "$pattern" . $EXCLUDE_DIRS $EXCLUDE_FILES $GREP_OPTS 2>/dev/null || true); then
        if [[ -n "$matches" ]]; then
            # Filter out mock/test/example/placeholder patterns and env var references
            filtered_matches=$(echo "$matches" | grep -v -E "(mock|test|example|demo|fake|dummy|sample|placeholder|your-|YOUR_|\\\$[A-Z_]+|\[HIDDEN\]|\[type=|semgrep|codacy|TOKEN_HERE|KEY_HERE|SECRET_HERE|_HERE\")" || true)
            if [[ -n "$filtered_matches" ]]; then
                echo ""
                echo -e "${C_RED}⚠ Potential secret found (pattern: ${pattern:0:30}...):${C_RESET}"
                echo "$filtered_matches"
                ISSUES_FOUND=$((ISSUES_FOUND + 1))
            fi
        fi
    fi
done

# Check for common secret files that shouldn't exist in tracked files
SECRET_FILES=(".env" ".env.local" ".env.production" "config/secrets.yml" "secrets.json" "private.key" "id_rsa" "id_dsa" "id_ecdsa" "id_ed25519")

echo ""
echo "🔍 Checking for secret files..."

for file in "${SECRET_FILES[@]}"; do
    if [[ -f "$file" ]]; then
        # Check if file is tracked by git
        if git ls-files --error-unmatch "$file" 2>/dev/null; then
            echo -e "${C_RED}⚠ SECRET FILE TRACKED IN GIT: $file${C_RESET}"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        elif [[ "$file" == ".env" ]] || [[ "$file" == ".env.local" ]]; then
            # .env files are expected locally, just verify they're gitignored
            if ! grep -q "^\.env" .gitignore 2>/dev/null; then
                echo -e "${C_YELLOW}⚠ $file exists but .env not in .gitignore${C_RESET}"
            fi
        fi
    fi
done

# Verify .gitignore has proper patterns
echo ""
echo "🔍 Validating .gitignore..."

if [[ -f ".gitignore" ]]; then
    REQUIRED_PATTERNS=(".env" "*.key" "*.pem")
    for pattern in "${REQUIRED_PATTERNS[@]}"; do
        if ! grep -qE "^\\${pattern//./\\.}$|^${pattern}$" .gitignore 2>/dev/null; then
            echo -e "${C_YELLOW}⚠ Consider adding '$pattern' to .gitignore${C_RESET}"
        fi
    done
    echo -e "${C_GREEN}✓ .gitignore validated${C_RESET}"
else
    echo -e "${C_YELLOW}⚠ No .gitignore file found - consider creating one${C_RESET}"
fi

# Summary
echo ""
if [[ $ISSUES_FOUND -eq 0 ]]; then
    echo -e "${C_GREEN}✅ Security check passed - no secrets detected${C_RESET}"
    exit 0
else
    echo -e "${C_RED}❌ Security check failed - $ISSUES_FOUND potential issues found${C_RESET}"
    echo ""
    echo "Recommendations:"
    echo "1. Remove any hardcoded secrets from source code"
    echo "2. Use environment variables for sensitive configuration"
    echo "3. Add secret files to .gitignore"
    echo "4. Consider using a secrets management service"
    exit 1
fi

