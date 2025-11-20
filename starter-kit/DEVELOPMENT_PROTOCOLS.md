# Development Protocols for AI-Assisted Engineering

**Purpose**: Critical protocols for working with AI assistants (Claude Code, GitHub Copilot, Gemini, ChatGPT) to avoid token waste, prevent costly mistakes, and maintain code quality.

**These protocols evolved from painful real-world failures. Follow them rigorously.**

---

## Table of Contents

1. [Git Workflow](#git-workflow)
2. [Build & Compilation Issues](#build--compilation-issues)
3. [Code Quality Gates](#code-quality-gates)
4. [AI Agent Collaboration](#ai-agent-collaboration)
5. [Debugging Protocol](#debugging-protocol)
6. [Token Conservation](#token-conservation)

---

## Git Workflow

### Context-Aware Git Commands

**CRITICAL**: Different environments have different expectations.

**Environment Detection**:

```markdown
### Claude Code / Web (Web Interface)
**DO create pull requests yourself.**

When work is complete:
1. **Commit your changes** - stage files, create commits with clear messages
2. **Push to the feature branch** - use the designated branch from task instructions
3. **Create the pull request** - use `gh pr create` with detailed summary and test plan
4. **Return the PR URL** - provide the link so the user can review

### VS Code Agent Mode (CLI)
**Don't run git commands yourself unless I explicitly request it.**

When work is complete:
1. **Show the user what commands to run** - provide exact git commands as copyable text
2. **Let the user execute them** - they want to learn and save Claude Pro tokens
3. **Do NOT stage files or create commits** - the user will do this themselves
```

**How to identify**: Claude Code / Web sessions include task instructions with designated feature branches. VS Code agent mode sessions are conversational without task context.

### Commit Message Standards

```bash
# ✅ Good commit messages (imperative mood, specific)
git commit -m "Add pre-commit hook for binary detection"
git commit -m "Fix race condition in recipe normalization Lambda"
git commit -m "Update CLAUDE.md with Go compilation protocol"

# ❌ Bad commit messages (vague, past tense)
git commit -m "Updates"
git commit -m "Fixed stuff"
git commit -m "WIP"
```

### Creating Pull Requests

**Process**:

1. **Understand the full scope** - Check ALL commits from branch divergence

   ```bash
   # See all commits in this branch
   git log main..HEAD

   # See all changes since branching
   git diff main...HEAD
   ```

2. **Draft comprehensive PR summary**

   ```bash
   gh pr create --title "Add mobile share extension support" --body "$(cat <<'EOF'
   ## Summary
   - Implemented iOS Share Extension with WKWebView proxy
   - Added Android Share Intent with WebView loader
   - Updated Flutter MethodChannel bridge for both platforms

   ## Test Plan
   - [x] Test iOS Share Extension with NYT recipe
   - [x] Test Android Share Intent with Food52 recipe
   - [x] Verify image downloading bypasses CDN restrictions
   - [ ] Test offline web archive capture

   ## Related Issues
   Closes #123
   EOF
   )"
   ```

3. **NEVER use shortened summaries** - Include ALL work, not just latest commit

---

## Build & Compilation Issues

### MANDATORY 5-Minute / 3-Attempt Escalation Policy

**When encountering build/compilation errors:**

1. **After 5 minutes OR 3 failed attempts**, STOP
2. **Generate Perplexity.ai prompt** with:
   - Exact error message
   - Environment details (Xcode version, OS version, tool versions)
   - Project structure (Flutter/React/Go/etc.)
   - Steps already attempted
   - Full dependency chain if applicable

3. **DO NOT continue troubleshooting** without external research
4. **Use Perplexity's findings** to guide solution

**Example Escalation**:

```
Perplexity.ai Query:

Xcode 16 build error with CocoaPods:

Error: "The file couldn't be opened because there is no such file"
Context:
- Xcode 16.0 on macOS 14.5
- Flutter 3.24.0
- CocoaPods 1.15.2
- Project: Flutter iOS app with Share Extension

Error occurs during:
`xcodebuild build -scheme Runner -configuration Debug`

Attempted fixes:
1. flutter clean && flutter pub get
2. cd ios && pod deintegrate && pod install
3. Deleted DerivedData

Full error:
[paste complete error trace]
```

**Why This Matters**: Build toolchain issues often have known solutions. Spending 30+ minutes on trial-and-error wastes time when a 2-minute search reveals the answer.

### Platform-Specific Build Rules

**iOS**:
- ❌ NEVER use `flutter build ios` (gets confused by multiple schemes)
- ✅ ALWAYS use `xcodebuild` directly
- ✅ Let Xcode build phases call Flutter compilation

**Android**:
- ❌ NEVER use `flutter build apk` for complex builds
- ✅ ALWAYS use `./gradlew assembleDebug` directly
- ✅ Use Gradle configurations (debug, release, profile)

**Go**:
- ✅ ALWAYS run `go build` after linting fixes
- ✅ Check for unused imports (common after removing functions)

---

## Code Quality Gates

### Go Compilation Protocol

**MANDATORY**: Always run compilation checks before declaring Go work complete.

```bash
# 1. Fix linting errors
golangci-lint run ./...

# 2. CRITICAL: Check compilation
go build

# 3. If imports are unused, remove them
# Then re-run both checks
golangci-lint run ./...
go build

# 4. Only declare work complete after BOTH pass
```

**Common Gotcha**: Removing unused functions often leaves behind unused imports. The `go build` check catches this immediately.

**Why This Matters**: Unused imports are compilation errors in Go, not just linting warnings.

### JavaScript/TypeScript Linting

**MANDATORY**: Always use double quotes.

```bash
# After editing JavaScript files
npm run lint -- --fix
```

**Enforcement** (`.eslintrc.json`):

```json
{
  "rules": {
    "quotes": ["error", "double"]
  }
}
```

### Pre-Push Validation

```bash
# Before pushing to remote
./validate-monorepo.sh --p1    # Quick check (~30s)

# Before creating PR
./validate-monorepo.sh --med   # Medium check (~2-5min)

# Before releasing
./validate-monorepo.sh --all   # Full check (~5-10min)
```

---

## AI Agent Collaboration

### Reviewing Work from Other AI Agents

**CRITICAL PROTOCOL**: When asked to review work from Google Gemini, GitHub Copilot, or other AI agents:

1. **ASSUME THE WORK IS DONE** - If told "AI X did the implementation", trust that code changes exist

2. **READ CAREFULLY** - Distinguish between:
   - "Review the PLAN" (just documentation, no code yet)
   - "Review the IMPLEMENTATION" (code changes already made)

3. **NEVER `git restore` without explicit permission** - File changes may represent hours of work

4. **Check git diff FIRST** - Before making assumptions, review what actually changed

   ```bash
   # See what changed
   git status
   git diff
   ```

5. **When uncertain, ASK**: "Should I review the plan document or the actual implementation changes?"

**Common Mistake Pattern (AVOID)**:
```
User: "Review Gemini's work on X"
Wrong: Assume no implementation exists, restore files
Right: Check git status/diff, review actual changes made
```

**Why This Matters**: Running `git restore` on implemented work wastes thousands of tokens recreating completed work and damages trust.

### Task Handoffs Between AI Agents

**When starting work after another AI**:

```bash
# 1. Check current state
git status
git log -5 --oneline
git diff main

# 2. Read any documentation they created
ls -la docs/
cat docs/IMPLEMENTATION_PLAN.md  # If exists

# 3. Ask clarifying questions BEFORE making changes
# "I see Gemini created X. Should I continue from there or start fresh?"
```

---

## Debugging Protocol

### Standard Workflow for Issues

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

### Localhost Testing Policy

**NEVER attempt to run Flutter locally** - This consistently fails and wastes significant tokens.

Instead:
- ✅ Test against production/staging environment
- ✅ Use remote debugging (Flutter DevTools)
- ✅ Use integration tests with mocked backends

---

## Token Conservation

### Efficient File Reading

```bash
# ❌ Bad: Read entire large file
Read tools/large-file.go (10,000 lines)

# ✅ Good: Read specific section
Read tools/large-file.go (offset: 100, limit: 50)

# ✅ Better: Use grep to find relevant code first
Grep pattern="handleRecipe" path="tools/"
```

### Avoid Redundant Operations

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

### Batch Operations

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

---

## Build Hygiene

### CRITICAL: Never Modify Source Files In Place

**All build scripts MUST output to a separate `build/` or `dist/` directory.**

```bash
# ❌ WRONG: Modifies source files
./build.sh  # Writes to src/generated.ts

# ✅ CORRECT: Outputs to build directory
./build.sh  # Writes to build/generated.ts
```

**Why**: Prevents accidental source code corruption and ensures reproducible builds.

**If you detect this happening**:
1. IMMEDIATELY alert the user
2. Fix the build scripts (this is a critical error)
3. Work stoppage until fixed

---

## Post-Push Cleanup

**After successful GitHub push**:

1. Remove backwards-looking "Recent Completed Work" sections from `CLAUDE.md`
2. Archive accomplishments to maintain lean documentation focused on:
   - Current issues requiring attention
   - How-to guidance for upcoming work
   - Essential context for development workflow
3. Keep document orientation forward-looking and actionable

**Example Cleanup**:

```markdown
<!-- ❌ Remove these after push -->
## Recent Completed Work
- Added mobile share extension
- Fixed image downloading
- Updated documentation

<!-- ✅ Keep these -->
## Current Focus
- Implement backup/restore functionality

## Known Issues
- Image upload fails for files >10MB (need to implement chunking)
```

---

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

---

## Real-World Impact

### Before These Protocols

- ❌ AI agent spent 2 hours on Xcode build issue (solution was on Stack Overflow)
- ❌ AI agent ran `git restore` on 3 hours of Gemini's work (had to recreate)
- ❌ Go code declared "complete" but had unused imports (failed in CI)
- ❌ AI agent created PR with only latest commit summary (missed 15 other commits)
- ❌ Build script modified source files (corrupted 5 TypeScript files)

### After These Protocols

- ✅ 5-minute escalation policy saves hours on toolchain issues
- ✅ "Check git diff first" prevents work loss
- ✅ Go compilation check catches issues before commit
- ✅ PR summaries include full branch scope
- ✅ Build hygiene prevents source corruption

---

## Quick Reference Card

**Before Starting Work**:
1. Check git status/diff if another AI worked on this
2. Read project's `CLAUDE.md` file
3. Understand which environment you're in (Web vs CLI)

**During Work**:
1. Escalate build issues after 5min / 3 attempts
2. Run `go build` after linting fixes (Go projects)
3. Run `npm run lint -- --fix` after JS edits
4. Never modify source files in place (use build/)

**Before Committing**:
1. Run `./validate-monorepo.sh --p1` (if available)
2. Check that you haven't staged binaries or credentials
3. Write descriptive commit message (imperative mood)

**Before Creating PR**:
1. Review ALL commits from branch divergence
2. Include comprehensive summary (not just latest commit)
3. Add test plan and related issues

**After Push** (Web mode only):
1. Clean up backwards-looking documentation
2. Update current focus sections
3. Keep docs forward-looking

---

## Customization for Your Project

Copy this template to your project and customize:

1. **Add project-specific tools** (replace recipe-tracer examples with yours)
2. **Add common error patterns** (document recurring issues)
3. **Add deployment protocols** (how to deploy safely)
4. **Add monitoring protocols** (how to check production health)

---

**These protocols represent lessons learned from real projects. Use them to avoid common mistakes.**
