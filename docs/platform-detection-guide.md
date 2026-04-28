# Platform Detection Guide for Shell Scripts

**Version:** 1.0
**Last Updated:** 2025-01-11
**Purpose:** Standardize platform detection across all shell scripts in this repository

---

## Table of Contents

1. [Overview](#overview)
2. [Detection Order & Logic](#detection-order--logic)
3. [Pattern Library](#pattern-library)
4. [Alternative Patterns](#alternative-patterns)
5. [Instructions for Gemini](#instructions-for-gemini)
6. [Script Inventory & Progress](#script-inventory--progress)

---

## Overview

This repository contains shell scripts designed for different platforms:
- **~90%** are macOS-only scripts
- **~5%** are WSL/Windows scripts
- **~5%** are cross-platform or Linux scripts

**Goal:** Every platform-specific script MUST gracefully exit with a clear error message when run on an unsupported platform.

**Design Principle:** Scripts should be self-contained and work independently when copied to other locations. DO NOT use shared/sourced detection scripts.

---

## Detection Order & Logic

Platform detection MUST follow this priority order:

1. **macOS (Darwin)** - Check `uname -s` for "Darwin"
2. **WSL** - Check `/proc/version` for "microsoft" or "Microsoft"
3. **Native Windows** - Check `uname -s` for "MINGW"/"MSYS"/"CYGWIN" (Git Bash, MSYS2, Cygwin)
4. **Linux** - Check `uname -s` for "Linux" (and not WSL)

### Why This Order?

- macOS check is fast and unambiguous
- WSL must be checked before generic Linux (WSL reports as Linux + microsoft)
- Most scripts are macOS-only, so fail-fast on the first check

---

## Pattern Library

### **Option B: Ultra-Compact (RECOMMENDED)**

This is the **primary pattern** - use this for 95% of scripts.

#### For macOS-only Scripts (Most Common)

```bash
#!/bin/bash
# macOS-only script
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }
```

**Placement:** Line 2-3, immediately after shebang, before any other code.

**Example in context:**
```bash
#!/bin/bash
# flush-dns-cache.sh - macOS DNS cache flusher
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

# Exit immediately if a command exits with a non-zero status
set -e

echo "Flushing DNS cache..."
sudo dscacheutil -flushcache
```

---

#### For WSL/Windows-only Scripts

```bash
#!/bin/bash
# WSL/Windows-only script
[[ "$(uname -s)" == "Darwin" ]] && { echo "Error: This script is for Windows/WSL, not macOS" >&2; exit 1; }
grep -qi microsoft /proc/version 2>/dev/null || { echo "Error: This script requires WSL" >&2; exit 1; }
```

**Example:** See [mu.sh](../mu.sh) (already has WSL check at line 411)

---

#### For Linux-only Scripts (Not WSL)

```bash
#!/bin/bash
# Linux-only script
[[ "$(uname -s)" == "Darwin" ]] && { echo "Error: This script is for Linux, not macOS" >&2; exit 1; }
[[ "$(uname -s)" == "Linux" ]] && grep -qi microsoft /proc/version 2>/dev/null && { echo "Error: This script is for native Linux, not WSL" >&2; exit 1; }
```

---

#### For Cross-Platform Scripts

**No check needed** - script should work on all platforms.

**Example:** Git utility scripts like [squash-last-n.sh](../squash-last-n.sh) that only use git commands.

---

### Edge Cases

#### Scripts That Use Homebrew

Homebrew can run on macOS or Linux. If the script **requires** macOS-specific commands (like `mas`, `softwareupdate`, `dscacheutil`), add the macOS check. If it only uses Homebrew, it may be cross-platform.

**Example:** [bu.sh](../bu.sh) uses `brew`, `mas`, and `softwareupdate` → macOS-only

#### Scripts That Use utmctl

UTM is a macOS virtualization tool → macOS-only

**Example:** [inspect.sh](../analyze-malware-sandbox/inspect.sh) uses `utmctl` → macOS-only

---

## Alternative Patterns

These patterns are provided for **future migration** if more complex requirements emerge.

### **Option A: Minimal Boilerplate (15-20 lines)**

A single `check_platform()` function with customizable error messages.

```bash
#!/bin/bash
# macOS-only script

check_platform() {
    local os_type
    os_type="$(uname -s)"

    case "$os_type" in
        Darwin)
            return 0  # macOS - OK
            ;;
        *)
            echo "Error: This script requires macOS" >&2
            echo "Detected: $os_type" >&2
            echo "Please run this script on a Mac" >&2
            exit 1
            ;;
    esac
}

check_platform
```

**Use when:** You need more detailed error messages or logging.

---

### **Option C: Structured with Helper (25-30 lines)**

Separate detection + validation for maximum clarity and reusability within a script.

```bash
#!/bin/bash
# macOS-only script

detect_platform() {
    local os_type
    os_type="$(uname -s)"

    case "$os_type" in
        Darwin)
            echo "macos"
            ;;
        Linux)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            else
                echo "linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

require_platform() {
    local required="$1"
    local detected
    detected="$(detect_platform)"

    if [[ "$detected" != "$required" ]]; then
        echo "Error: This script requires $required (detected: $detected)" >&2
        exit 1
    fi
}

require_platform "macos"
```

**Use when:** Script needs to support multiple platforms with different behavior, or you need to reference the platform multiple times in the script.

---

## Instructions for Gemini

### **STOP. READ THIS ENTIRE SECTION BEFORE STARTING WORK.**

This section contains **ABSOLUTE RULES** for adding platform checks to scripts. These are **NOT SUGGESTIONS**. You MUST follow every step exactly.

---

### **Workflow: DO THIS FOR EVERY SCRIPT**

#### **Step 1: Pick a Script from the Inventory Table**

- Scroll to the [Script Inventory & Progress](#script-inventory--progress) section
- Find a script marked ❌ (Needs Check)
- Read the entire script to understand what it does

#### **Step 2: Determine the Target Platform**

Ask these questions **IN THIS ORDER**:

1. **Does it use macOS-specific commands?**
   - `dscacheutil`, `softwareupdate`, `mas`, `killall mDNSResponder`, `utmctl`, `xcrun`, `xcodebuild`, `plutil`
   - **YES** → macOS-only

2. **Does it check for WSL or call Windows commands?**
   - Checks `/proc/version` for microsoft
   - Calls `powershell.exe`, `winget`, Windows Update
   - **YES** → WSL/Windows-only

3. **Does it only use git commands?**
   - Only uses `git` commands with no platform-specific tools
   - **YES** → Cross-platform (no check needed)

4. **Does it use Linux-specific tools?**
   - `apt`, `yum`, `systemctl` (but NOT in WSL context)
   - **YES** → Linux-only

5. **Does it use Homebrew?**
   - If it ALSO uses macOS-specific commands → macOS-only
   - If it ONLY uses Homebrew and nothing else → Cross-platform

**Write down your answer** before proceeding.

---

#### **Step 3: Update the Script Banner/Header**

**YOU MUST DO THIS STEP. DO NOT SKIP IT.**

1. Find the script header (usually in the first 30 lines)
2. Look for these fields: `# Description:`, `# Dependencies:`, `# Requirements:`
3. Add or update a `# Platform:` field

**Format:**
```bash
# Platform: macOS only
# Platform: WSL/Windows only
# Platform: Linux only
# Platform: Cross-platform
```

**Example BEFORE:**
```bash
#!/bin/bash
# Script Name: flush-dns-cache.sh
# Description: This script flushes the DNS cache on macOS.
# Usage: ./flush-dns-cache.sh
```

**Example AFTER:**
```bash
#!/bin/bash
# Script Name: flush-dns-cache.sh
# Description: This script flushes the DNS cache on macOS.
# Platform: macOS only
# Usage: ./flush-dns-cache.sh
```

---

#### **Step 4: Add the Platform Check**

**YOU MUST DO THIS STEP. DO NOT SKIP IT.**

1. Go to line 2 or 3 (right after shebang and any header comments)
2. Copy the **EXACT** pattern from the [Pattern Library](#pattern-library) above
3. Paste it **BEFORE** any `set -e`, `set -euo pipefail`, or other code

**CRITICAL RULES:**

- ✅ **DO** place check at line 2-3 (after shebang, before any code)
- ✅ **DO** copy the pattern exactly - do not modify the syntax
- ✅ **DO** use `>&2` to send errors to stderr
- ✅ **DO** use `exit 1` to indicate failure
- ❌ **DO NOT** put the check inside a function
- ❌ **DO NOT** put the check after `set -e` or other setup code
- ❌ **DO NOT** modify the error message format (keep it concise)
- ❌ **DO NOT** add additional logging unless explicitly requested

**Example for macOS script:**

```bash
#!/bin/bash
# flush-dns-cache.sh
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

set -e
# ... rest of script
```

---

#### **Step 5: Update the Inventory Table**

**YOU MUST DO THIS STEP. DO NOT SKIP IT.**

1. Scroll to the [Script Inventory & Progress](#script-inventory--progress) section
2. Find the row for the script you just updated
3. Change the Status from ❌ to ✅
4. Update the Target Platform column if it was wrong
5. Add a brief note in the Notes column

**Example BEFORE:**
```
| flush-dns-cache.sh | TBD | ❌ Needs Check | Uses dscacheutil |
```

**Example AFTER:**
```
| flush-dns-cache.sh | macOS | ✅ Done | Added check at line 3, updated banner |
```

---

#### **Step 6: Commit Your Changes**

**YOU MUST DO THIS STEP. DO NOT SKIP IT.**

1. Stage the modified script file
2. Stage the modified documentation (this file)
3. Commit with a descriptive message

**Commit Message Format:**
```
Add [platform] check to [script-name]

- Added platform detection at line [N]
- Updated script banner with Platform field
- Updated progress table in docs
```

**Example:**
```bash
git add flush-dns-cache.sh docs/platform-detection-guide.md
git commit -m "Add macOS check to flush-dns-cache.sh

- Added platform detection at line 3
- Updated script banner with Platform field
- Updated progress table in docs"
```

---

#### **Step 7: Repeat**

Go back to Step 1 and pick another script marked ❌.

Continue until all scripts marked ❌ are completed.

---

### **Common Mistakes to Avoid**

#### ❌ **MISTAKE 1: Wrong Platform Detection**

**WRONG:**
```bash
# Checking for Linux when script uses macOS commands
[[ "$(uname -s)" != "Linux" ]] && { echo "Error: This script requires Linux" >&2; exit 1; }
sudo dscacheutil -flushcache  # This is macOS-only!
```

**CORRECT:**
```bash
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }
sudo dscacheutil -flushcache
```

---

#### ❌ **MISTAKE 2: Incorrect grep Syntax for WSL**

**WRONG:**
```bash
grep -q "microsoft" /proc/version || exit 1  # Fails if /proc/version doesn't exist
```

**CORRECT:**
```bash
grep -qi microsoft /proc/version 2>/dev/null || { echo "Error: This script requires WSL" >&2; exit 1; }
```

---

#### ❌ **MISTAKE 3: Placing Check in Wrong Location**

**WRONG:**
```bash
#!/bin/bash
set -e

# ... 50 lines of code ...

check_platform() {
    [[ "$(uname -s)" != "Darwin" ]] && exit 1
}
check_platform
```

**CORRECT:**
```bash
#!/bin/bash
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

set -e
# ... rest of script
```

---

#### ❌ **MISTAKE 4: Forgetting to Update the Banner**

**WRONG:** Added platform check but didn't update the header comment.

**CORRECT:** Always add/update `# Platform:` field in the header.

---

#### ❌ **MISTAKE 5: Not Updating Progress Table**

**WRONG:** Modified the script but didn't update the inventory table in this document.

**CORRECT:** Always update the table to track progress.

---

### **Testing Your Changes (Optional but Recommended)**

If you have access to multiple platforms:

1. **Test on the WRONG platform** - verify the script exits with an error
2. **Test on the RIGHT platform** - verify the script runs normally

**Example:**
```bash
# On Linux, testing a macOS-only script:
bash flush-dns-cache.sh
# Expected output: "Error: This script requires macOS"
# Exit code: 1
```

---

### **Summary Checklist**

Before you commit, verify you completed ALL of these:

- [ ] Read the entire script to understand its purpose
- [ ] Determined the correct target platform
- [ ] Updated the script banner with `# Platform:` field
- [ ] Added platform check at line 2-3 using EXACT syntax from pattern library
- [ ] Updated the inventory table in this document (❌ → ✅)
- [ ] Added notes to the inventory table
- [ ] Committed changes with descriptive message
- [ ] (Optional) Tested on correct and incorrect platforms

---

## Script Inventory & Progress

### Legend

- ✅ **Done** - Platform check added and tested
- ❌ **Needs Check** - Platform-specific script without check
- ⚠️ **Needs Review** - Has a check but may need updating to standard format
- N/A **Cross-platform** - Script works on all platforms, no check needed

---

### Root Directory Scripts

| Script | Target Platform | Status | Notes |
|--------|----------------|--------|-------|
| mu.sh | WSL/Windows | ⚠️ Needs Review | Has WSL check at line 411, needs check at top + banner update |
| bu.sh | macOS | ✅ Done | Added check at line 2, updated banner |
| flush-dns-cache.sh | Cross-platform | ✅ Done | Updated 2025-01-11: supports macOS/WSL/Linux |
| clone-brew.sh | macOS | ✅ Done | Added check at line 2, updated banner |
| start-ollama.sh | macOS | ✅ Done | Added check at line 2, updated banner |
| setup-podman-for-terraform.sh | macOS | ✅ Done | Added check at line 2, updated banner |
| cleanup-npm-global.sh | Cross-platform | N/A | Only uses npm commands |
| resume-claude.sh | macOS | ✅ Done | Added check at line 2, updated banner |
| schedule-claude.sh | macOS | ✅ Done | Added check at line 2, updated banner |
| squash-last-n.sh | Cross-platform | ✅ Done | Updated 2025-01-11: added --what-if default behavior |
| squash-commits.sh | Cross-platform | ✅ Done | Updated 2025-01-11: added --what-if default behavior |
| scrub-git-history.sh | Cross-platform | N/A | Only uses git commands |
| reset-all-repos.sh | Cross-platform | ✅ Done | Updated 2025-01-11: added --what-if default behavior |
| enumerate-gh-repos.sh | Cross-platform | N/A | Uses GitHub CLI (gh) |
| get-active-repos.sh | Cross-platform | N/A | Uses GitHub CLI (gh) |
| get-dormant-repos.sh | Cross-platform | N/A | Uses GitHub CLI (gh) |
| sync-git-repos.sh | Cross-platform | N/A | Uses standard git only |

---

### xcode/ Directory

| Script | Target Platform | Status | Notes |
|--------|----------------|--------|-------|
| xcode/inspect-xcode.sh | macOS | ⚠️ Needs Review | Has check at line 43-48, needs banner update |

---

### macos-setup/ Directory

| Script | Target Platform | Status | Notes |
|--------|----------------|--------|-------|
| macos-setup/setup-macos-template.sh | macOS | ❌ Needs Check | Main setup script |
| macos-setup/lib/common.sh | macOS | ❌ Needs Check | Shared library with helper functions |
| macos-setup/lib/migrate-to-standard.sh | macOS | ❌ Needs Check | Migration script |
| macos-setup/setup-components/00-homebrew.sh | macOS | ❌ Needs Check | Homebrew installer |
| macos-setup/setup-components/10-essentials.sh | macOS | ❌ Needs Check | Essential packages |
| macos-setup/setup-components/20-mobile.sh | macOS | ❌ Needs Check | Mobile dev tools |
| macos-setup/setup-components/30-web-tools.sh | macOS | ❌ Needs Check | Web dev tools |
| macos-setup/setup-components/40-browser-tools.sh | macOS | ❌ Needs Check | Browser extensions |
| macos-setup/setup-components/50-utilities.sh | macOS | ❌ Needs Check | Utility tools |
| macos-setup/setup-components/70-env.sh | macOS | ❌ Needs Check | Environment setup |
| macos-setup/setup-components/80-mcp-claude-desktop.sh | macOS | ❌ Needs Check | Claude Desktop MCP |
| macos-setup/setup-components/90-mcp-claude-code.sh | macOS | ❌ Needs Check | Claude Code MCP |

---

### analyze-malware-sandbox/ Directory

| Script | Target Platform | Status | Notes |
|--------|----------------|--------|-------|
| analyze-malware-sandbox/inspect.sh | macOS | ❌ Needs Check | Uses utmctl (line 100) |
| analyze-malware-sandbox/status.sh | macOS | ❌ Needs Check | Uses utmctl |
| analyze-malware-sandbox/create-vm.sh | macOS | ❌ Needs Check | Uses utmctl |
| analyze-malware-sandbox/create-vm-alternate.sh | macOS | ❌ Needs Check | Uses utmctl |
| analyze-malware-sandbox/setup-sandbox.sh | macOS | ❌ Needs Check | Uses utmctl |
| analyze-malware-sandbox/provision-vm.sh | macOS | ❌ Needs Check | SSH to VM |
| analyze-malware-sandbox/setup-alpine.sh | Linux | ❌ Needs Check | Runs inside Alpine VM |
| analyze-malware-sandbox/check-alpine-version.sh | Cross-platform | N/A | Only checks files |
| analyze-malware-sandbox/shared/analyze.sh | Linux | ❌ Needs Check | Runs inside Alpine VM, uses Alpine tools |

---

### capture-packets/ Directory

| Script | Target Platform | Status | Notes |
|--------|----------------|--------|-------|
| capture-packets/capture.sh | macOS | ❌ Needs Check | Uses tcpdump - needs review if macOS-specific |
| capture-packets/start-pcap-rotate.sh | macOS | ❌ Needs Check | Uses tcpdump - needs review |
| capture-packets/stop-pcap-rotate.sh | macOS | ❌ Needs Check | Needs review |
| capture-packets/compress-pcap-gzip.sh | Cross-platform | N/A | Only uses gzip |
| capture-packets/compress-pcap-zstd.sh | Cross-platform | N/A | Only uses zstd |

---

### find-secrets-in-source--OLD/ Directory

| Script | Target Platform | Status | Notes |
|--------|----------------|--------|-------|
| find-secrets-in-source--OLD/passhog-simple.sh | Cross-platform | N/A | Only uses git and grep |

---

### Progress Summary

**Total Scripts:** 44
**Completed (✅):** 4
**Needs Check (❌):** 30
**Needs Review (⚠️):** 1
**Cross-platform (N/A):** 12

**Recent Updates (2025-01-11):**
- ✅ flush-dns-cache.sh: Now cross-platform (macOS/WSL/Linux)
- ✅ squash-commits.sh: Added --what-if default behavior, requires --force to execute
- ✅ squash-last-n.sh: Added --what-if default behavior, requires --force to execute
- ✅ reset-all-repos.sh: Added --what-if default behavior, requires --force to execute
- 🔄 Renamed all scripts from snake_case to kebab-case for consistency (bu.sh and mu.sh kept as-is)

**Next Priority:** Start with remaining root directory scripts (bu.sh, clone-brew.sh) and analyze-malware-sandbox scripts.

---

## Changelog

| Date | Version | Changes |
|------|---------|---------|
| 2025-01-11 | 1.1 | Updated script names to kebab-case, added --what-if mode to dangerous scripts, made flush-dns-cache.sh cross-platform |
| 2025-01-11 | 1.0 | Initial version - created pattern library, Gemini instructions, and script inventory |

---

## Questions?

If you encounter a script that doesn't fit these patterns, consult with the repository owner before proceeding.
