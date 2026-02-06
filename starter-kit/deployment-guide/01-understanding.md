# Understanding the Starter-Kit

## What is the Starter-Kit?

The `starter-kit/` directory contains reusable templates, scripts, and documentation for bootstrapping new projects with comprehensive safety nets.

## When You Encounter This

If you're an AI assistant and you see a `starter-kit/` directory in a repository, here's what to do:

### Step 1: Understand the Context

Ask the user:
- "I see you have the starter-kit. Would you like me to deploy it into this project?"
- "Which components do you need? (All / Safety net only / Specific documents)"

### Step 2: Don't Just Copy

**DO NOT** simply copy the starter-kit directory to the new project.

**INSTEAD**, distribute the content appropriately based on the deployment workflow.

## Core Components

### Documentation Files

- `SAFETY_NET.md` - Automated safety mechanisms
- `DEVELOPMENT_PROTOCOLS.md` - AI assistant protocols
- `PROJECT_SETUP_CHECKLIST.md` - Setup guide
- `DEPLOYMENT_GUIDE_FOR_AI.md` - This guide

### Template Files

- `common.sh` - Shared shell functions
- `.gitignore.template` - Git ignore patterns
- `.env.template` - Environment variable template
- `check-binaries.template` - Binary detection hook

## Key Principle

**Distribute, don't duplicate.** Each file has a specific destination in the target project.

