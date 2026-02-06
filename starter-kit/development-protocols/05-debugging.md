# Debugging Protocol

## Standard Workflow for Issues

**Recipe Normalization Issues** (example domain):

```bash
# 1. Find Recipe ID
cd tools/content-ops && ./content-ops -include-recipe-id "Recipe Name"

# 2. Trace Processing
cd tools/recipe-tracer && ./recipe-tracer -recipe RECIPE_ID

# 3. Analyze Output
# - Check ingredient count, instruction count
# - Review CloudWatch logs in output
# - Look for cache hits (stale data?)
# - Verify S3 operations
```

**Production Error Triage**:

```bash
# 1. Use project-specific diagnostic tools
cd tools/get-diagnostics && ./get-diagnostics -all -since 24h

# 2. Never use AWS CLI directly
# ❌ aws s3 ls s3://bucket
# ✅ Use project tools that understand the data model
```

## Localhost Testing Policy

**NEVER attempt to run Flutter locally** - This consistently fails and wastes significant tokens.

Instead:
- ✅ Test against production/staging environment
- ✅ Use remote debugging (Flutter DevTools)
- ✅ Use integration tests with mocked backends

## During Work

1. Escalate build issues after 5min / 3 attempts
2. Run `go build` after linting fixes (Go projects)
3. Run `npm run lint -- --fix` after JS edits
4. Never modify source files in place (use build/)

