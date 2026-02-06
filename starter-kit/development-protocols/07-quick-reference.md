# Quick Reference Card

## Before Starting Work

1. Check git status/diff if another AI worked on this
2. Read project's `CLAUDE.md` file
3. Understand which environment you're in (Web vs CLI)

## During Work

1. Escalate build issues after 5min / 3 attempts
2. Run `go build` after linting fixes (Go projects)
3. Run `npm run lint -- --fix` after JS edits
4. Never modify source files in place (use build/)

## Before Committing

1. Run `./validate-monorepo.sh --p1` (if available)
2. Check that you haven't staged binaries or credentials
3. Write descriptive commit message (imperative mood)

## Before Creating PR

1. Review ALL commits from branch divergence
2. Include comprehensive summary (not just latest commit)
3. Add test plan and related issues

## After Push (Web mode only)

1. Clean up backwards-looking documentation
2. Update current focus sections
3. Keep docs forward-looking

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

## Customization for Your Project

Copy this template to your project and customize:

1. **Add project-specific tools** (replace recipe-tracer examples with yours)
2. **Add common error patterns** (document recurring issues)
3. **Add deployment protocols** (how to deploy safely)
4. **Add monitoring protocols** (how to check production health)

---

**These protocols represent lessons learned from real projects. Use them to avoid common mistakes.**

