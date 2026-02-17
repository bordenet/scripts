# Critical Invariants — Always Follow

> **Load this file at the START of every conversation.**

## Recursive Self-Management Protocol

After editing ANY guidance file (`AGENTS.md` or `.ai-guidance/*.md`):

```bash
wc -l AGENTS.md .ai-guidance/*.md 2>/dev/null
```

### Thresholds

| File | Limit | Action if exceeded |
|------|-------|-------------------|
| `AGENTS.md` | 250 lines | Extract to `.ai-guidance/*.md` |
| `.ai-guidance/*.md` | 250 lines | Split into sub-directory (e.g., `testing/unit.md`) |

### If ANY threshold exceeded:

1. **STOP** current task immediately
2. **Refactor** the bloated file (ZERO DATA LOSS)
3. **Verify** all content preserved
4. **Resume** original task

## Zero Data Loss Verification

Before completing any refactor:

- [ ] Original content snapshot captured
- [ ] Every section accounted for in new structure
- [ ] No custom rules deleted (only moved or split)
- [ ] Diff shows reorganization, not deletion

## Refactoring: AGENTS.md → .ai-guidance/

1. `cat AGENTS.md > /tmp/original.md`
2. `mkdir -p .ai-guidance`
3. Classify content by topic
4. Extract to sub-files (≤250 lines each)
5. Update loading table in AGENTS.md
6. Verify: `wc -l AGENTS.md` ≤250

## Refactoring: .ai-guidance/*.md → sub-directory

If a sub-file like `testing.md` exceeds 250 lines:

1. `mkdir -p .ai-guidance/testing`
2. Split into: `testing/unit.md`, `testing/integration.md`, etc.
3. Replace original with index: `testing.md` → references sub-files
4. Verify: each new file ≤250 lines

## Recovery

If verification fails: restore from snapshot

