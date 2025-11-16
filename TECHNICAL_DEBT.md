# Technical Debt

This document tracks known violations of coding standards and areas requiring refactoring.

## Last Updated
2025-11-16

---

## Scripts Exceeding 400-Line Limit

Per our [STYLE_GUIDE.md](./STYLE_GUIDE.md), **no script shall exceed 400 lines of code**. The following scripts currently violate this standard:

| Script | Lines | Priority | Status | Notes |
|--------|-------|----------|--------|-------|
| [`purge-identity.sh`](./purge-identity.sh) | 2,073 | High | **Needs Refactoring** | Complex security tool with 53 functions. Break into library modules. |
| [`backup-wsl-config.sh`](./backup-wsl-config.sh) | 830 | High | **Needs Refactoring** | WSL configuration backup tool. Extract common functions. |
| [`mu.sh`](./mu.sh) | 400 | ~~Medium~~ | ✅ **COMPLETED** | Extracted helpers to `lib/mu-helpers.sh` (166 lines). |
| [`macos-setup/setup-macos-template.sh`](./macos-setup/setup-macos-template.sh) | 290 | ~~Medium~~ | ✅ **COMPLETED** | Extracted UI functions to `lib/ui.sh` (151 lines). |
| [`macos-setup/setup-components/20-mobile.sh`](./macos-setup/setup-components/20-mobile.sh) | 68 | ~~Medium~~ | ✅ **COMPLETED** | Split into 6 focused components (21-java, 22-flutter, 23-android, 24-ios, 25-cloud-tools). |

### Total Violations: 2 scripts (down from 5)
### Resolved: 3 scripts (60% reduction in violations)

---

## Refactoring Recommendations

### 1. `purge-identity.sh` (2,073 lines)

**Current State:**
- 53 functions
- Complex identity discovery and removal logic
- Multiple scanner functions for different apps/services
- Extensive error handling and logging

**Refactoring Plan:**

```
purge-identity/
├── purge-identity.sh           # Main orchestrator (< 400 lines)
├── lib/
│   ├── common.sh              # Shared logging, error handling
│   ├── discovery.sh           # Identity discovery functions
│   ├── validation.sh          # Input validation, confirmations
│   └── removal.sh             # Deletion operations
├── scanners/
│   ├── keychain.sh           # Keychain scanning
│   ├── browsers.sh           # Safari, Chrome, Edge, Firefox
│   ├── mail.sh               # Mail.app scanning
│   ├── ssh.sh                # SSH key scanning
│   └── cloud.sh              # Cloud storage scanning
└── README.md
```

**Estimated Effort:** 8-12 hours
**Risk:** Medium (complex security logic)

---

### 2. `backup-wsl-config.sh` (830 lines)

**Current State:**
- WSL configuration backup and restore
- Multiple backup targets
- Configuration validation

**Refactoring Plan:**

```
backup-wsl/
├── backup-wsl-config.sh       # Main entry point (< 400 lines)
├── lib/
│   ├── common.sh             # Shared utilities
│   ├── backup.sh             # Backup operations
│   ├── restore.sh            # Restore operations
│   └── validate.sh           # Configuration validation
└── README.md
```

**Estimated Effort:** 4-6 hours
**Risk:** Low (well-defined operations)

---

### 3. `mu.sh` (575 lines)

**Current State:**
- macOS maintenance utility
- Multiple system maintenance tasks
- Update and cleanup operations

**Refactoring Plan:**

```
mu/
├── mu.sh                      # Main orchestrator (< 400 lines)
├── lib/
│   ├── common.sh             # Shared utilities
│   ├── updates.sh            # System/brew updates
│   ├── cleanup.sh            # Cleanup operations
│   └── maintenance.sh        # Maintenance tasks
└── README.md
```

**Estimated Effort:** 3-5 hours
**Risk:** Low (straightforward operations)

---

### 4. `macos-setup/setup-macos-template.sh` (494 lines)

**Current State:**
- Template for macOS development environment setup
- Already uses modular component system
- Main script coordinates component installation

**Refactoring Plan:**

**Option A:** Extract menu/UI to separate module
```
macos-setup/
├── setup-macos-template.sh    # Minimal orchestrator (< 400 lines)
├── lib/
│   ├── common.sh             # Existing
│   ├── ui.sh                 # NEW: Menu and user interaction
│   └── orchestrator.sh       # NEW: Component coordination
└── setup-components/          # Existing
```

**Option B:** Split into setup phases
```
macos-setup/
├── setup-macos.sh             # Main entry point
├── setup-phase1-essentials.sh # Core system setup
├── setup-phase2-development.sh # Dev tools
├── setup-phase3-optional.sh   # Optional components
└── lib/                       # Existing
```

**Estimated Effort:** 2-4 hours
**Risk:** Low (already well-structured)

---

### 5. `macos-setup/setup-components/20-mobile.sh` (421 lines)

**Current State:**
- Combined iOS and Android development setup
- Xcode, Android Studio, simulators
- Mobile development tools

**Refactoring Plan:**

Split into platform-specific components:
```
macos-setup/setup-components/
├── 20-mobile.sh               # Coordinator (< 100 lines)
├── 21-ios-development.sh      # iOS/Xcode setup (< 300 lines)
├── 22-android-development.sh  # Android setup (< 300 lines)
└── 23-mobile-tools.sh         # Shared mobile tools (< 200 lines)
```

**Estimated Effort:** 2-3 hours
**Risk:** Low (clean separation of concerns)

---

## Prioritization

### Phase 1: Quick Wins (Low Risk, High Impact)
1. **20-mobile.sh** (421 lines) - Clean split into iOS/Android
2. **setup-macos-template.sh** (494 lines) - Extract UI/orchestration

**Total Effort:** 4-7 hours

### Phase 2: Medium Complexity
3. **mu.sh** (575 lines) - Extract maintenance modules
4. **backup-wsl-config.sh** (830 lines) - Extract backup/restore/validate

**Total Effort:** 7-11 hours

### Phase 3: Complex Refactoring
5. **purge-identity.sh** (2,073 lines) - Full library extraction

**Total Effort:** 8-12 hours

---

## Other Technical Debt

### Linting Status

**Note:** Shellcheck is not available in the current development environment (Claude Code web mode). All scripts should be linted locally before deployment.

**Linting Requirements:**
- All scripts must pass `shellcheck` with zero warnings
- Use `shellcheck --severity=warning` as minimum standard
- Document any intentional rule disables with comments

**Local Linting Command:**
```bash
# Lint all scripts
find . -type f -name "*.sh" -exec shellcheck {} +

# Lint with specific severity
find . -type f -name "*.sh" -exec shellcheck --severity=warning {} +
```

### Missing Features

None currently identified.

### Performance Issues

None currently identified.

### Security Concerns

None currently identified. All scripts follow security best practices:
- Input sanitization
- Proper error handling
- No use of `eval` with user input
- Secure file handling with null delimiters

---

## Resolution Process

When refactoring oversized scripts:

1. **Create feature branch:** `git checkout -b refactor/script-name`
2. **Review current script:** Understand all functionality
3. **Design module structure:** Plan library breakdown
4. **Extract functions:** Move to appropriate library files
5. **Test thoroughly:** Ensure no functionality loss
6. **Lint all files:** Verify zero shellcheck warnings
7. **Update documentation:** Update README, add migration notes
8. **Create PR:** Include before/after metrics

### Success Criteria

- [ ] All new files < 400 lines
- [ ] All functionality preserved
- [ ] All tests passing
- [ ] Zero shellcheck warnings
- [ ] Documentation updated
- [ ] Code reviewed and approved

---

## Tracking

**Total Debt:** 2 scripts remaining, 2,903 excess lines remaining

**Progress:**
- [ ] purge-identity.sh (2,073 lines → target: ≤400)
- [ ] backup-wsl-config.sh (830 lines → target: ≤400)
- [x] mu.sh (575 → 400 lines) ✅ Completed 2025-11-16
- [x] setup-macos-template.sh (494 → 290 lines) ✅ Completed 2025-11-16
- [x] 20-mobile.sh (421 → 68 lines coordinator + 5 focused components) ✅ Completed 2025-11-16

**Completed:** 3 of 5 scripts (60%)

---

## Notes

- Refactoring should be done incrementally to avoid introducing bugs
- Each refactoring should be a separate PR with thorough testing
- Consider adding integration tests before refactoring complex scripts
- Preserve git history during refactoring for better traceability

**Last Review Date:** 2025-11-16
