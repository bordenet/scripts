# Deployment Workflow

## File Mapping

### Core Documentation

| Starter-Kit File | Deploy To | Customization Needed |
|------------------|-----------|----------------------|
| `SAFETY_NET.md` | `docs/SAFETY_NET.md` | Replace "your-project" with project name |
| `DEVELOPMENT_PROTOCOLS.md` | `CLAUDE.md` (root) | Extract relevant sections, add project-specific protocols |
| `PROJECT_SETUP_CHECKLIST.md` | `docs/SETUP.md` | Customize for project tech stack |

### Templates

| Starter-Kit File | Deploy To | Customization Needed |
|------------------|-----------|----------------------|
| `common.sh` | `scripts/lib/common.sh` | None - use as-is |
| `.gitignore.template` | `.gitignore` (root) | Merge with existing, remove unused sections |
| `.env.template` | `.env.example` (root) | Replace variables with project-specific ones |
| `check-binaries.template` | `.husky/check-binaries` | Customize binary patterns for project |

## Step-by-Step Deployment

### 1. Create Directory Structure

```bash
mkdir -p docs
mkdir -p scripts/lib
mkdir -p scripts/setup-components
mkdir -p .husky
```

### 2. Deploy Core Documentation

```bash
# Safety Net
cp starter-kit/SAFETY_NET.md docs/SAFETY_NET.md
# Then customize (see Customization Guidelines)

# Development Protocols → CLAUDE.md
cp starter-kit/DEVELOPMENT_PROTOCOLS.md CLAUDE.md
# Then extract relevant sections

# Setup Checklist
cp starter-kit/PROJECT_SETUP_CHECKLIST.md docs/SETUP.md
# Then customize for tech stack
```

### 3. Deploy Templates

```bash
# Common shell functions
cp starter-kit/common.sh scripts/lib/common.sh

# .gitignore
if [ -f .gitignore ]; then
  # Merge with existing
  cat starter-kit/.gitignore.template >> .gitignore
else
  cp starter-kit/.gitignore.template .gitignore
fi

# .env.example
cp starter-kit/.env.template .env.example
# Then customize variables

# Binary detection hook
cp starter-kit/check-binaries.template .husky/check-binaries
chmod +x .husky/check-binaries
```

### 4. Deploy Setup Scripts

```bash
# macOS setup
cp starter-kit/setup-macos.sh scripts/setup-macos.sh
chmod +x scripts/setup-macos.sh

# Linux setup
cp starter-kit/setup-linux.sh scripts/setup-linux.sh
chmod +x scripts/setup-linux.sh

# Setup components
cp starter-kit/setup-components/* scripts/setup-components/
```

### 5. Deploy Validation System

```bash
# Main validation script
cp starter-kit/validate-monorepo.sh validate-monorepo.sh
chmod +x validate-monorepo.sh
```

### 6. Deploy Pre-Commit Hooks

```bash
# Install Husky
npm install --save-dev husky
npx husky install

# Create pre-commit hook
cat > .husky/pre-commit << 'EOF'
#!/usr/bin/env bash
. "$(dirname -- "$0")/_/husky.sh"

./validate-monorepo.sh --p1
./.husky/check-binaries
EOF

chmod +x .husky/pre-commit
```

## Deployment Checklist

- [ ] Directory structure created
- [ ] Core documentation deployed and customized
- [ ] Templates deployed and customized
- [ ] Setup scripts deployed and made executable
- [ ] Validation system deployed
- [ ] Pre-commit hooks installed and tested
- [ ] All files committed to git
- [ ] Validation passes (`./validate-monorepo.sh --all`)

