# Starter-Kit Deployment Guide for AI Assistants

**Purpose**: Instructions for Claude Code, Gemini, and other AI assistants on how to deploy starter-kit materials into a new repository.

**Target Audience**: AI assistants (you!) working on new projects

---

## When You Encounter This Starter-Kit

If you're an AI assistant and you see a `starter-kit/` directory in a repository, here's what to do:

### Step 1: Understand the Context

Ask the user:
- "I see you have the your-project starter-kit. Would you like me to deploy it into this project?"
- "Which components do you need? (All / Safety net only / Specific documents)"

### Step 2: Deploy Materials (Don't Just Copy)

**DO NOT** simply copy the starter-kit directory to the new project.

**INSTEAD**, distribute the content appropriately:

#### Core Documentation

| Starter-Kit File | Deploy To | Customization Needed |
|------------------|-----------|----------------------|
| `README.md` | Reference only | N/A - explains starter-kit |
| `SAFETY_NET.md` | `docs/SAFETY_NET.md` | Replace "your-project" with project name |
| `DEVELOPMENT_PROTOCOLS.md` | `CLAUDE.md` (root) | Extract relevant sections, add project-specific protocols |
| `CODE_STYLE_STANDARDS.md` | `docs/CODING_STANDARDS.md` | Remove unused languages |
| `SHELL_SCRIPT_STANDARDS.md` | `docs/SHELL_SCRIPTS.md` | Minimal changes |
| `PROJECT_SETUP_CHECKLIST.md` | `docs/SETUP.md` | Customize for project tech stack |

#### Templates

| Starter-Kit File | Deploy To | Customization Needed |
|------------------|-----------|----------------------|
| `common.sh` | `scripts/lib/common.sh` | None - use as-is |
| `.gitignore.template` | `.gitignore` (root) | Merge with existing, remove unused sections |
| `.env.template` | `.env.example` (root) | Replace variables with project-specific ones |
| `check-binaries.template` | `.husky/check-binaries` | Customize binary patterns for project |

#### Special Handling

**SCRIPT_COMPLIANCE_REVIEW.md**: DO NOT deploy. This is specific to your-project.

---

## Deployment Workflow

### Phase 1: Safety Net (High Priority)

1. **Copy common.sh**
   ```bash
   mkdir -p scripts/lib
   cp starter-kit/common.sh scripts/lib/common.sh
   chmod +x scripts/lib/common.sh
   ```

2. **Deploy .gitignore**
   ```bash
   # If .gitignore exists, merge intelligently
   # If not, create from template
   cp starter-kit/.gitignore.template .gitignore
   # Customize: Remove unused sections (Flutter, Go, etc.)
   ```

3. **Deploy .env.example**
   ```bash
   cp starter-kit/.env.template .env.example
   # Customize: Replace with project-specific variables
   # Keep only relevant sections
   ```

4. **Set up pre-commit hooks**
   ```bash
   npm install --save-dev husky
   npx husky install
   mkdir -p .husky
   cp starter-kit/check-binaries.template .husky/check-binaries
   chmod +x .husky/check-binaries

   # Create .husky/pre-commit
   cat > .husky/pre-commit << 'EOF'
   #!/usr/bin/env bash
   ./.husky/check-binaries
   npm test
   EOF
   chmod +x .husky/pre-commit
   ```

### Phase 2: Documentation (Medium Priority)

1. **Create CLAUDE.md**
   ```bash
   # Extract relevant sections from DEVELOPMENT_PROTOCOLS.md
   # Customize for project
   # Add project-specific commands
   cat > CLAUDE.md << 'EOF'
   # [ProjectName] Development Guide

   ## Git Workflow Policy
   [Copy from DEVELOPMENT_PROTOCOLS.md, customize]

   ## Build Commands
   - Build: `npm run build`
   - Test: `npm test`
   - Deploy: `./scripts/deploy.sh`

   ## Critical Protocols
   [Add project-specific rules]
   EOF
   ```

2. **Create docs/CODING_STANDARDS.md**
   ```bash
   mkdir -p docs
   cp starter-kit/CODE_STYLE_STANDARDS.md docs/CODING_STANDARDS.md
   # Remove languages not used in this project
   # Keep: Languages actually used
   # Example: If no Swift, remove Swift section
   ```

3. **Create docs/SAFETY_NET.md**
   ```bash
   cp starter-kit/SAFETY_NET.md docs/SAFETY_NET.md
   # Replace "your-project" with project name
   # Update examples to use project-specific code
   ```

### Phase 3: Setup Scripts (Medium Priority)

1. **Create setup script**
   ```bash
   mkdir -p scripts/setup-components

   # Create main setup script using SHELL_SCRIPT_STANDARDS.md as guide
   cat > scripts/setup-macos.sh << 'EOF'
   #!/usr/bin/env bash

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/lib/common.sh"
   init_script

   # [Add setup logic based on project needs]
   EOF
   chmod +x scripts/setup-macos.sh
   ```

2. **Create validation script**
   ```bash
   cat > validate-monorepo.sh << 'EOF'
   #!/usr/bin/env bash

   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/scripts/lib/common.sh" || source "$(dirname "$0")/lib/common.sh"
   init_script

   # [Add validation logic based on project needs]
   EOF
   chmod +x validate-monorepo.sh
   ```

### Phase 4: Cleanup (Low Priority)

1. **Remove starter-kit directory**
   ```bash
   # Once everything is deployed
   rm -rf starter-kit/
   ```

2. **Update README.md**
   ```markdown
   ## Development

   - **Setup**: `./scripts/setup-macos.sh`
   - **Validate**: `./validate-monorepo.sh --all`
   - **Documentation**: See `CLAUDE.md` for development guide
   ```

---

## Customization Guidelines

### Replace Project Names

Use search and replace:
```bash
# Replace "your-project" with actual project name
find docs/ -type f -name "*.md" -exec sed -i '' 's/your-project/YourProject/g' {} +
```

### Remove Unused Languages

**Example**: Project uses only Go and JavaScript (no Flutter, Swift, Kotlin)

Edit `docs/CODING_STANDARDS.md`:
- Keep: Go section
- Keep: JavaScript/TypeScript section
- Remove: Dart/Flutter section
- Remove: Swift section
- Remove: Kotlin section

### Customize .gitignore

**Example**: Project has no Flutter, remove Flutter sections

Edit `.gitignore`:
```gitignore
# Remove these sections:
# ################################################################################
# # Flutter / Dart
# ################################################################################
# .dart_tool/
# ...
```

### Customize .env.example

**Example**: Project doesn't use AWS, uses PostgreSQL

Edit `.env.example`:
```bash
# Remove AWS sections
# Add PostgreSQL section
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
DATABASE_HOST=localhost
DATABASE_PORT=5432
```

---

## Validation After Deployment

**Checklist** - Ensure these work:

- [ ] `scripts/lib/common.sh` exists and is executable
- [ ] `.gitignore` blocks all sensitive files
- [ ] `.env.example` exists, `.env` is in `.gitignore`
- [ ] Pre-commit hooks block binaries
- [ ] Pre-commit hooks run tests
- [ ] `CLAUDE.md` exists with project-specific guidance
- [ ] `docs/CODING_STANDARDS.md` includes only used languages
- [ ] `scripts/setup-<platform>.sh` works on clean machine
- [ ] `validate-monorepo.sh` runs successfully

**Test** - Run these commands:

```bash
# Test pre-commit hooks
echo "test" > test.txt
git add test.txt
git commit -m "Test commit"  # Should run hooks

# Test setup script
./scripts/setup-macos.sh --help

# Test validation
./validate-monorepo.sh --help

# Test common library
bash -c 'source scripts/lib/common.sh && log_info "Test"'
```

---

## What NOT to Do

**DON'T**:
- ❌ Copy entire starter-kit directory to new project
- ❌ Keep `SCRIPT_COMPLIANCE_REVIEW.md` (your-project-specific)
- ❌ Keep unused language sections in style guides
- ❌ Keep your-project project name in deployed docs
- ❌ Deploy without customizing for project tech stack

**DO**:
- ✅ Deploy content to appropriate locations
- ✅ Customize for project's tech stack
- ✅ Replace project names
- ✅ Remove unused sections
- ✅ Test after deployment
- ✅ Delete starter-kit/ after deployment complete

---

## Example Deployment Session

**User**: "I want to use the your-project starter-kit for my new Go API project"

**AI Response**:
```
I'll deploy the starter-kit for your Go API project. Here's what I'll do:

1. Deploy common.sh to scripts/lib/common.sh
2. Create .gitignore from template (Go + Node.js sections)
3. Create .env.example with AWS and PostgreSQL sections
4. Set up pre-commit hooks (Husky + binary detection)
5. Create CLAUDE.md with your project-specific guidance
6. Create docs/CODING_STANDARDS.md (Go + Shell scripts only)
7. Create scripts/setup-macos.sh for dependencies
8. Create validate-monorepo.sh for testing
9. Clean up by removing starter-kit/

Proceeding...
```

**After Deployment**:
```
✅ Starter-kit deployed successfully!

Customizations made:
- Removed Flutter, Swift, Kotlin, Dart sections (not used)
- Kept Go, JavaScript, Shell script standards
- Created .env.example with AWS and PostgreSQL
- Created CLAUDE.md with Go-specific protocols

Next steps:
1. Review CLAUDE.md and customize further
2. Fill in .env.example with your project variables
3. Run ./scripts/setup-macos.sh to install dependencies
4. Test validation: ./validate-monorepo.sh --all

Would you like me to proceed with any of these steps?
```

---

## Maintenance

After deployment, the starter-kit content lives in the project's documentation. Update as needed:

- `CLAUDE.md` - Add project-specific protocols
- `docs/CODING_STANDARDS.md` - Add project-specific conventions
- `docs/SAFETY_NET.md` - Document project-specific validations
- `scripts/lib/common.sh` - Add project-specific helper functions

---

## Questions to Ask

Before deploying, clarify with the user:

1. **Tech stack**: "What languages/frameworks does this project use?"
2. **Cloud provider**: "Are you using AWS, GCP, Azure, or self-hosted?"
3. **Deployment target**: "Is this a web app, mobile app, API, CLI tool, or library?"
4. **Team size**: "How many developers will use this?"
5. **CI/CD**: "Are you using GitHub Actions, GitLab CI, or something else?"

Use answers to customize deployment appropriately.

---

**Remember**: The goal is to extract value from starter-kit and adapt it to the new project, not to copy it verbatim. Think of it as a reference implementation to be customized, not a template to be cloned.
