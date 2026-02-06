# Development Protocols - Index

**Purpose**: Critical protocols for working with AI assistants to avoid token waste, prevent costly mistakes, and maintain code quality.

**These protocols evolved from painful real-world failures. Follow them rigorously.**

## Quick Start

For AI coding assistants: Load the specific module you need based on your current task.

## Modules

| Module | When to Load | Lines |
|--------|--------------|-------|
| [Git Workflow](development-protocols/01-git-workflow.md) | Committing, pushing, creating PRs | ~90 |
| [Build & Compilation](development-protocols/02-build-compilation.md) | Fixing build errors, compilation issues | ~70 |
| [Code Quality Gates](development-protocols/03-code-quality.md) | Running linters, tests, coverage checks | ~60 |
| [AI Agent Collaboration](development-protocols/04-ai-collaboration.md) | Working with multiple AI assistants | ~55 |
| [Debugging Protocol](development-protocols/05-debugging.md) | Systematic debugging approach | ~45 |
| [Token Conservation](development-protocols/06-token-conservation.md) | Avoiding token waste, efficient prompting | ~50 |
| [Quick Reference](development-protocols/07-quick-reference.md) | Common tasks and real-world impact | ~40 |

## Progressive Loading Pattern

1. **Creating a PR?** → Load [Git Workflow](development-protocols/01-git-workflow.md)
2. **Build failing?** → Load [Build & Compilation](development-protocols/02-build-compilation.md)
3. **Tests failing?** → Load [Code Quality Gates](development-protocols/03-code-quality.md)
4. **Debugging an issue?** → Load [Debugging Protocol](development-protocols/05-debugging.md)

## Related Documentation

- `SAFETY_NET.md` - Automated safety mechanisms
- `PROJECT_SETUP_CHECKLIST.md` - Complete setup guide
- `DEPLOYMENT_GUIDE_FOR_AI.md` - Deployment procedures

## Total Content

**Original file**: 505 lines
**Refactored**: 7 modules, each ≤100 lines
**Index**: This file (~45 lines)

