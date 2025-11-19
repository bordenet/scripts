# Engineering Starter Kit

**Purpose**: Portable collection of battle-tested engineering best practices, ready to be copied into new projects.

**Origin**: Born from the [RecipeArchive](https://github.com/bordenet/RecipeArchive) project.

## What Is This?

This directory contains **hard-won lessons** from building a production-grade, multi-platform application (Flutter mobile, browser extensions, AWS backend, Go microservices). These documents capture engineering protocols, safety nets, and coding standards that took months to develop and debug.

**Use this starter-kit to avoid repeating painful mistakes in future projects.**

## When to Use

Copy this starter-kit to a new project when:

1. **Starting a new repository** - Bootstrap with proven engineering practices
2. **Onboarding an AI assistant** - Give Claude Code / Gemini / ChatGPT these documents
3. **Standardizing an existing project** - Retrofit safety nets into legacy codebases
4. **Teaching best practices** - Use as training material for new engineers

## What's Included

### Core Documents

| Document | Purpose | Use When |
|----------|---------|----------|
| **SAFETY_NET.md** | Comprehensive guide to automated safety mechanisms | Setting up validation, pre-commit hooks, dependency management |
| **DEVELOPMENT_PROTOCOLS.md** | Critical protocols for AI-assisted development | Working with Claude Code, avoiding token waste, escalation policies |
| **SHELL_SCRIPT_STANDARDS.md** | Shell script style guide with common library | Writing automation scripts |
| **CODE_STYLE_STANDARDS.md** | Cross-language style guide (Go, JS/TS, Dart, Kotlin, Swift) | Establishing coding conventions |
| **PROJECT_SETUP_CHECKLIST.md** | Step-by-step checklist for new projects | First-time project setup |
| **VALIDATION_SYSTEM.md** | Building a monorepo validation system | Creating CI/CD pipelines |
| **PRE_COMMIT_HOOKS.md** | Setting up git hooks for quality gates | Preventing broken commits |
| **BUILD_HYGIENE.md** | Build system best practices | Configuring build processes |

### Reference Materials

| File | Description |
|------|-------------|
| `common.sh` | Reusable shell script library (logging, error handling, etc.) |
| `.env.example` | Template for environment variables |
| `validate-monorepo-template.sh` | Template validation script |
| `setup-template.sh` | Template dependency installation script |

## How to Use

### Option 1: Copy Entire Starter Kit to New Project

```bash
# In your new project
mkdir -p docs/starter-kit
cp -r /path/to/your-project/starter-kit/* ./docs/starter-kit/

# Review and customize for your project
# Then commit to git
git add docs/starter-kit
git commit -m "Add engineering starter-kit from your-project"
```

### Option 2: Cherry-Pick Specific Documents

```bash
# Copy only what you need
cp /path/to/your-project/starter-kit/SAFETY_NET.md ./docs/
cp /path/to/your-project/starter-kit/common.sh ./scripts/lib/
```

### Option 3: Provide to AI Assistants

When starting work with Claude Code or other AI assistants:

1. **Copy relevant docs to project root** or provide as context
2. **Reference in project README**: "See `docs/starter-kit/` for engineering standards"
3. **Create a `CLAUDE.md`** using `DEVELOPMENT_PROTOCOLS.md` as a template

## Quick Start for New Projects

Follow this order:

1. ✅ **Read `PROJECT_SETUP_CHECKLIST.md`** - Get oriented
2. ✅ **Copy `common.sh`** to `scripts/lib/common.sh`
3. ✅ **Create `setup-<platform>.sh`** using `setup-template.sh`
4. ✅ **Set up pre-commit hooks** following `PRE_COMMIT_HOOKS.md`
5. ✅ **Create validation script** using `VALIDATION_SYSTEM.md`
6. ✅ **Establish style guides** using `CODE_STYLE_STANDARDS.md`
7. ✅ **Configure AI assistant** using `DEVELOPMENT_PROTOCOLS.md`

## Why This Matters

### Before These Practices

- ❌ Breaking commits regularly merged to main
- ❌ "Works on my machine" dependency issues
- ❌ Inconsistent shell scripts (each engineer's personal style)
- ❌ Hours wasted debugging build toolchain issues
- ❌ No standardized error handling or logging
- ❌ AI assistants making the same mistakes repeatedly

### After These Practices

- ✅ Pre-commit hooks catch issues before they reach git
- ✅ Single command reproduces entire development environment
- ✅ All scripts follow same conventions (readable by anyone)
- ✅ 5-minute / 3-attempt escalation policy saves hours
- ✅ Standardized logging makes debugging 10x faster
- ✅ AI assistants follow consistent, proven protocols

## Maintenance

This starter-kit was created from RecipeArchive at commit `66ba440` on 2025-11-17 and is maintained in the scripts repository.

**To update**: When practices improve, update these documents and bump the version.

## License

MIT License - Copyright (c) 2025 Matt J Bordenet. These are engineering best practices, not proprietary code.

## Questions?

- **Repository**: [scripts](https://github.com/bordenet/scripts)
- **Origin**: [RecipeArchive](https://github.com/bordenet/RecipeArchive) project
- **Last updated**: 2025-11-19

---

**Remember**: These practices evolved through real production pain. Use them to avoid repeating that pain.
