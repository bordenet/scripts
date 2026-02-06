# Token Conservation

## Efficient File Reading

```bash
# ❌ Bad: Read entire large file
Read tools/large-file.go (10,000 lines)

# ✅ Good: Read specific section
Read tools/large-file.go (offset: 100, limit: 50)

# ✅ Better: Use grep to find relevant code first
Grep pattern="handleRecipe" path="tools/"
```

## Avoid Redundant Operations

```bash
# ❌ Bad: Re-read files unnecessarily
Read utils.go
[make small edit]
Read utils.go again  # Waste! You just read this

# ✅ Good: Trust your context
Read utils.go
[make small edit with Edit tool]
# No need to re-read unless user reports issues
```

## Batch Operations

```bash
# ❌ Bad: Sequential file edits
Read file1.js
Edit file1.js
Read file2.js
Edit file2.js

# ✅ Good: Parallel reads, then edits
Read file1.js, file2.js, file3.js (in parallel)
Edit file1.js, file2.js, file3.js
```

## Environment-Specific Instructions

### CLAUDE.md Template

Create a `CLAUDE.md` in your project root with project-specific guidance:

```markdown
# ProjectName Development Guide

## Git Workflow Policy
[Copy from above - adjust for your project context]

## Build & Deployment
- Build command: `npm run build`
- Test command: `npm test`
- Deploy command: `./scripts/deploy.sh`

## Critical Protocols
- [Add project-specific rules]

## Common Tasks
- [Document frequent operations]
```

