# Script Compliance Audit Report

**Date:** 2025-11-21  
**Auditor:** Claude Code  
**Standard:** STYLE_GUIDE.md v1.2

## Executive Summary

This audit reviewed all shell scripts in the repository against the coding standards defined in STYLE_GUIDE.md. The audit identified significant compliance gaps across multiple areas.

### Critical Findings

- **14 scripts** missing `-h/--help` flags entirely
- **24 scripts** have shellcheck warnings
- **Majority of scripts** missing `set -euo pipefail`
- **Many scripts** lack `show_help()` functions
- **No scripts** currently exceed 400-line limit ✅

## Scripts Missing Help Functionality

The following scripts are **completely missing** `-h/--help` flags:

### analyze-malware-sandbox/
- `check-alpine-version.sh`
- `create-vm-alternate.sh`
- `create-vm.sh`
- `inspect.sh`
- `provision-vm.sh`
- `setup-alpine.sh` (also uses `/bin/sh` instead of bash)
- `setup-sandbox.sh`
- `status.sh`

### capture-packets/
- `capture.sh`
- `compress-pcap-gzip.sh`
- `compress-pcap-zstd.sh`
- `start-pcap-rotate.sh`
- `stop-pcap-rotate.sh`

### xcode/
- `inspect-xcode.sh`

## Scripts Missing show_help() Function

Even scripts with help flags should use a dedicated `show_help()` function:

- `bu.sh`
- `fetch-github-projects.sh` (uses lib function)
- `integrate-claude-web-branch.sh`
- `macos-setup/setup-macos-template.sh`
- `purge-stale-claude-code-web-branches.sh`
- `schedule-claude.sh`
- `scorch-repo.sh`
- `scrub-git-history.sh`
- `squash-commits.sh`
- `squash-last-n.sh`
- `start-ollama.sh`

## Scripts Missing set -euo pipefail

Critical error handling missing in:

- `analyze-malware-sandbox/check-alpine-version.sh`
- `analyze-malware-sandbox/create-vm.sh`
- `analyze-malware-sandbox/setup-sandbox.sh`
- `bu.sh`
- `capture-packets/capture.sh`
- `capture-packets/start-pcap-rotate.sh`
- `capture-packets/stop-pcap-rotate.sh`
- `clone-brew.sh`
- `enumerate-gh-repos.sh`
- `fetch-github-projects.sh`
- `flush-dns-cache.sh`
- `get-active-repos.sh`
- `integrate-claude-web-branch.sh`
- `list-dormant-repos.sh`
- `macos-setup/setup-macos-template.sh`
- `mu.sh`
- `purge-identity.sh`
- `purge-stale-claude-code-web-branches.sh`
- `reset-all-repos.sh`
- `resume-claude.sh`
- `schedule-claude.sh`
- `setup-podman-for-terraform.sh`
- `start-ollama.sh`
- `xcode/inspect-xcode.sh`

## Scripts with ShellCheck Warnings

24 scripts have shellcheck warnings that must be addressed:

- All 8 scripts in `analyze-malware-sandbox/` (except `inspect.sh` and `status.sh`)
- All 5 scripts in `capture-packets/`
- `cleanup-npm-global.sh`
- `clone-brew.sh`
- `enumerate-gh-repos.sh`
- `flush-dns-cache.sh`
- `get-active-repos.sh`
- `list-dormant-repos.sh`
- `purge-identity.sh`
- `resume-claude.sh`
- `scrub-git-history.sh`
- `setup-podman-for-terraform.sh`
- `squash-last-n.sh`
- `start-ollama.sh`
- `validate-cross-references.sh`
- `xcode/inspect-xcode.sh`

## Recommended Remediation Plan

### Phase 1: Critical Fixes (High Priority)
1. Add `-h/--help` to all 14 scripts missing it
2. Add `set -euo pipefail` to all scripts missing it
3. Fix all shellcheck warnings

### Phase 2: Quality Improvements (Medium Priority)
1. Add `show_help()` functions where missing
2. Ensure all help output follows man-page format
3. Add comprehensive examples to all help text

### Phase 3: Verification (Required)
1. Run `validate-script-compliance.sh` on all scripts
2. Test all `-h/--help` flags
3. Verify all scripts pass `bash -n` syntax check
4. Confirm zero shellcheck warnings across repository

## Compliance Status by Directory

| Directory | Scripts | Compliant | Issues |
|-----------|---------|-----------|--------|
| analyze-malware-sandbox/ | 8 | 0 | All missing help, most have shellcheck warnings |
| capture-packets/ | 5 | 0 | All missing help, all have shellcheck warnings |
| root | ~30 | ~10 | Mixed compliance, mostly missing error handling |
| xcode/ | 1 | 0 | Missing help, has shellcheck warnings |

## Next Steps

1. Create standardized help template for quick implementation
2. Fix scripts in priority order (most-used first)
3. Add pre-commit hook to enforce standards
4. Update CI/CD to run compliance checks

---

**Note:** This audit focused on structural compliance. Functional testing and security review are separate concerns.

