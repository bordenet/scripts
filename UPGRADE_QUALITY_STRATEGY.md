# STYLE_GUIDE.md v2.0 Upgrade Quality Strategy

**Date:** 2025-11-25  
**Objective:** Upgrade all 81 scripts to STYLE_GUIDE.md v2.0 WITHOUT breaking functionality  
**Risk Level:** HIGH - Last upgrade left scripts broken for weeks

---

## Quality Strategy Overview

### Multi-Layered Defense

1. **Baseline Snapshot** - Capture current state before ANY changes
2. **Automated Test Harness** - Validate every change automatically
3. **Incremental Batching** - Process 5-10 scripts at a time
4. **Regression Testing** - Test each batch before proceeding
5. **Rollback Plan** - Git branches for safe experimentation

### Success Criteria

- ✅ Zero syntax errors (`bash -n`)
- ✅ Zero shellcheck warnings (`shellcheck -S warning`)
- ✅ All scripts remain executable
- ✅ Help flags work (`-h`, `--help`)
- ✅ Core functionality preserved (smoke tests)
- ✅ No regressions from current state

---

## Phase 1: Analysis & Baseline

### 1.1 Analyze STYLE_GUIDE.md Changes

**Action:** Compare v1.2 (1487 lines) vs v2.0 (333 lines)

**Key Questions:**
- What requirements were removed?
- What requirements were added?
- What requirements changed?
- Are current scripts already compliant?

### 1.2 Create Baseline Snapshot

**Action:** Capture current state of all scripts

```bash
# Create baseline validation report
./ci-quality-gates.sh > baseline-report.txt 2>&1

# List all scripts with line counts
find . -name "*.sh" -type f ! -path "*/.*" | while read -r script; do
    echo "$script: $(wc -l < "$script") lines"
done > baseline-line-counts.txt

# Test all help flags
find . -name "*.sh" -type f ! -path "*/.*" -executable | while read -r script; do
    echo "Testing: $script"
    timeout 2 "$script" --help >/dev/null 2>&1 && echo "  ✓ Help works" || echo "  ✗ Help broken"
done > baseline-help-test.txt
```

---

## Phase 2: Build Test Harness

### 2.1 Automated Validation Script

Create `validate-upgrade.sh` that tests:

1. **Syntax validation** - `bash -n script.sh`
2. **ShellCheck** - `shellcheck -S warning script.sh`
3. **Executability** - File has execute permission
4. **Help flag** - `script.sh --help` exits 0
5. **Line count** - Script ≤ 400 lines
6. **Shebang** - `#!/usr/bin/env bash`
7. **Error handling** - Contains `set -euo pipefail` (except bu.sh/mu.sh/lib files)

### 2.2 Smoke Test Suite

Create `smoke-test.sh` for critical scripts:

- `bu.sh --help` (don't run actual backup)
- `mu.sh --help` (don't run actual update)
- `integrate-claude-web-branch.sh --help`
- `purge-identity.sh --help --what-if`
- `schedule-claude.sh --help`

### 2.3 Comparison Tool

Create `compare-before-after.sh`:
- Compare baseline vs current state
- Highlight any regressions
- Show improvement metrics

---

## Phase 3: Incremental Upgrade

### 3.1 Batch Strategy

**Batch Size:** 5-10 scripts per batch  
**Order:** Start with simplest scripts first

**Batch 1:** Simple utility scripts (no dependencies)
**Batch 2:** Scripts with lib dependencies
**Batch 3:** Complex scripts (bu.sh, mu.sh, integrate-claude-web-branch.sh)
**Batch 4:** Specialized scripts (analyze-malware-sandbox/, capture-packets/)

### 3.2 Per-Batch Workflow

For each batch:

1. Create feature branch: `git checkout -b upgrade-batch-N`
2. Identify changes needed for v2.0 compliance
3. Make changes to batch scripts
4. Run validation: `./validate-upgrade.sh <scripts>`
5. Run smoke tests: `./smoke-test.sh <scripts>`
6. Compare: `./compare-before-after.sh`
7. If all pass → commit batch
8. If any fail → fix or rollback
9. Merge to main only after batch passes

### 3.3 Change Tracking

Document every change in `UPGRADE_LOG.md`:
- Script name
- Changes made
- Validation results
- Any issues encountered

---

## Phase 4: Validation & Rollback

### 4.1 Continuous Validation

After each batch:
- Run full CI: `./ci-quality-gates.sh`
- Test pre-commit hook
- Verify GitHub Actions pass

### 4.2 Rollback Plan

If anything breaks:
1. Identify failing script(s)
2. `git revert` the batch commit
3. Fix issues in isolation
4. Re-test before re-committing

---

## Risk Mitigation

### High-Risk Scripts

These scripts are critical and must be tested thoroughly:
- `bu.sh` - Backup utility (data loss risk)
- `mu.sh` - System update (system stability risk)
- `purge-identity.sh` - Deletes data (data loss risk)
- `integrate-claude-web-branch.sh` - Git operations (repo corruption risk)

**Mitigation:** Test these in isolated environments first

### Known Pitfalls from Last Upgrade

1. **Masked errors** - `local var=$(cmd)` pattern
2. **Library sourcing** - Symlink resolution issues
3. **Platform differences** - BSD vs GNU tools
4. **Timer implementation** - ANSI escape code issues

**Mitigation:** Validate these patterns specifically

---

## Success Metrics

### Before Starting
- Current state: 81 scripts, 100% compliant with v1.2
- Baseline captured: ✅

### After Completion
- All scripts: 100% compliant with v2.0
- Zero regressions: ✅
- All tests pass: ✅
- Documentation updated: ✅

---

## Timeline

- **Phase 1 (Analysis):** 30 minutes
- **Phase 2 (Test Harness):** 1 hour
- **Phase 3 (Upgrade):** 2-4 hours (depends on changes needed)
- **Phase 4 (Validation):** 30 minutes

**Total Estimated Time:** 4-6 hours

---

## Next Steps

1. ✅ Create this strategy document
2. ⏳ Analyze STYLE_GUIDE.md changes
3. ⏳ Create baseline snapshot
4. ⏳ Build test harness
5. ⏳ Execute upgrade in batches
6. ⏳ Final validation

