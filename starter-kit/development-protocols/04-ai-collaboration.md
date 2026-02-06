# AI Agent Collaboration

## Reviewing Work from Other AI Agents

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

## Task Handoffs Between AI Agents

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

## Before Starting Work

1. Check git status/diff if another AI worked on this
2. Read project's `CLAUDE.md` file
3. Understand which environment you're in (Web vs CLI)

