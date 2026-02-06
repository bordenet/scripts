# Git Workflow

## Context-Aware Git Commands

**CRITICAL**: Different environments have different expectations.

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

**How to identify**: Claude Code / Web sessions include task instructions with designated feature branches. VS Code agent mode sessions are conversational without task context.

## Commit Message Standards

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

## Creating Pull Requests

### Process

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

