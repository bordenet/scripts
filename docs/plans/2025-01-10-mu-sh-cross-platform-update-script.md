# mu.sh - Cross-Platform Update Script for WSL/Windows

## Overview

**Purpose:** Comprehensive system update script for WSL environment that also updates Windows packages and OS. Designed for daily manual execution over morning coffee.

**Name:** `mu.sh` (Matt's Update script)

**Target Environment:** Microsoft Surface running WSL (primary) + Windows 11 with PowerShell

**Design Philosophy:**
- Single command execution from WSL terminal
- Compact, high signal-to-noise console output
- Comprehensive error reporting at end
- No aggressive flags (no --force)
- Daily use pattern

---

## User Context

- Primary work in WSL command line
- Uses O365 and Windows applications
- Manages 4 Macs with bu.sh (Homebrew-based update script)
- Wants consistent developer experience across all machines
- Development languages: Node, Ruby, Go, .NET, potentially Rust

---

## Architecture

### Two-Phase Execution

**Phase 1: WSL Updates**
1. apt (system packages)
2. Homebrew (dev tools and language runtimes)
3. npm (global packages)
4. pip/pip3 (Python package manager and packages)

**Phase 2: Windows Updates (via PowerShell interop)**
1. winget (Windows package manager)
2. Windows Update (OS patches and security updates)

### Package Manager Strategy

**WSL:**
- **apt:** System utilities and base packages
- **Homebrew:** Language runtimes and dev tools (node, ruby, go, rust, etc.)
- Provides consistency with macOS bu.sh workflow
- Fresh versions compared to Ubuntu default repos

**Windows:**
- **winget:** Primary package manager (native to Windows 11, Homebrew-like)
- Handles O365, VS Code, Windows Terminal, dev tools

---

## Detailed Requirements

### Initialization
- Request sudo upfront: `sudo -v` to cache credentials
- Start execution timer
- Clean up old log files (>24 hours) from /tmp

### WSL Update Phase

**apt updates:**
```bash
sudo apt update          # Refresh package lists
sudo apt upgrade -y      # Install updates non-interactively
sudo apt autoremove -y   # Remove unused packages
sudo apt autoclean       # Clear old package files
```

**Homebrew updates:**
```bash
brew update              # Update Homebrew itself
brew upgrade             # Upgrade all packages (no --force)
brew cleanup             # Remove old versions
brew doctor              # Check for issues (warnings → error report)
```

**npm updates:**
```bash
npm update -g            # Update global packages (no --force)
npm install -g npm       # Update npm itself
```

**pip updates:**
```bash
# Update pip itself
python3 -m pip install --upgrade pip

# Update all installed packages
pip3 list --outdated --format=freeze | cut -d= -f1 | xargs -n1 pip3 install --upgrade

# Handle pip2 if present (same pattern)
python2 -m pip install --upgrade pip (if exists)
pip list --outdated --format=freeze | cut -d= -f1 | xargs -n1 pip install --upgrade
```

### Windows Update Phase

**PowerShell interop:**
- Execute via `powershell.exe -Command "..."` from WSL
- Capture output and exit codes
- Parse for errors

**winget updates:**
```powershell
winget upgrade --all --silent
```
- Upgrades all packages non-interactively
- Minimizes UI popups
- Covers O365, dev tools, applications

**Windows Update:**
```powershell
# Install PSWindowsUpdate module if needed
Install-Module PSWindowsUpdate -Force -Scope CurrentUser

# Run Windows Update
Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false
```
- Downloads and installs OS patches
- No auto-reboot (user controls restart timing)

---

## UX Requirements

### Console Output - Compact & Clean

**During execution:**
- Spinner/progress indicators: `⠋ Updating apt...` → `✓ apt updated (45 packages)`
- One-line status per phase
- Suppress verbose command output
- Only show critical errors in real-time
- Optional: Clear screen between major phases

**End summary:**
```
==================================================
UPDATE SUMMARY
==================================================
Execution Time: 127 seconds

✓ WSL Updates: 4/4 succeeded
✓ Windows Updates: 2/2 succeeded

No errors detected. All systems updated successfully!
==================================================
```

### Error Reporting - Actionable Format

**If errors occur:**
```
==================================================
⚠ ERRORS DETECTED (2)
==================================================

1. npm global update failed
   Error: EACCES permission denied
   Fix: Run 'sudo chown -R $(whoami) ~/.npm'
   Retry: npm update -g

2. brew doctor warnings
   Warning: Outdated Xcode CommandLineTools
   Fix: Run 'softwareupdate --install -a'

==================================================
```

**Error format requirements:**
- What failed (phase/command)
- Actual error message
- Suggested fix (actionable)
- Command to retry manually

---

## Implementation Details

### File Structure
- **Location:** `/Users/matt/GitHub/scripts/mu.sh`
- **Permissions:** `chmod +x mu.sh`
- **Shebang:** `#!/bin/bash`

### Logging Strategy

**Log location:** `/tmp/mu_*.log`
- Always write detailed logs (both normal and verbose mode)
- Console output remains clean regardless
- Logs referenced in error report when failures occur

**Log files:**
- `/tmp/mu_apt.log`
- `/tmp/mu_brew.log`
- `/tmp/mu_npm.log`
- `/tmp/mu_pip.log`
- `/tmp/mu_winget.log`
- `/tmp/mu_windows_update.log`

**Log cleanup:**
- Remove logs older than 24 hours at script start
- Keeps disk usage minimal

### Error Handling Pattern

```bash
# Error collection array
ERRORS=()

# Capture pattern for each phase
if ! apt upgrade -y &> /tmp/mu_apt.log; then
    ERRORS+=("apt upgrade failed - check /tmp/mu_apt.log")
fi

# Continue execution even after failures
# Report all errors at end
```

### PowerShell Command Structure

```bash
# Execute Windows command from WSL
powershell.exe -Command "winget upgrade --all --silent" &> /tmp/mu_winget.log

# Capture exit code
WINGET_EXIT=$?

if [ $WINGET_EXIT -ne 0 ]; then
    ERRORS+=("winget upgrade failed - check /tmp/mu_winget.log")
fi
```

### Spinner Implementation

```bash
# Simple rotating spinner
spin() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p $pid > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}
```

---

## Future Enhancements (Not in Initial Version)

- `--verbose` flag to show full output instead of compact mode
- `--dry-run` flag to preview what would be updated
- Notification on completion (if run in background)
- Summary statistics (packages updated per phase)
- Historical log of update runs

---

## Success Criteria

1. Single command (`./mu.sh`) updates entire system (WSL + Windows)
2. Clean, readable console output that doesn't scroll excessively
3. All errors collected and presented actionably at end
4. Script continues through failures (no early exits)
5. Execution completes in reasonable time (<5 minutes typical)
6. Logs preserved for debugging but auto-cleaned after 24 hours
7. No prompts during execution (after initial sudo)

---

## Comparison to bu.sh

**Similarities:**
- Upfront sudo request
- Comprehensive package manager coverage
- Timer for execution time
- Continuation through errors

**Differences:**
- Two environments (WSL + Windows) vs single macOS
- PowerShell interop added
- More compact console output
- Actionable error reporting format
- Automatic log cleanup
- No Mac App Store (mas) equivalent needed

---

## Dependencies

**WSL (must be installed):**
- Homebrew for Linux
- npm (via Homebrew node or direct install)
- Python 3 with pip
- apt (built-in to Ubuntu/Debian WSL)

**Windows (must be accessible from WSL):**
- PowerShell (built into Windows 11)
- winget (built into Windows 11)
- PSWindowsUpdate module (script installs if missing)

---

## Notes

- Script designed for managed corporate PC (aggressive updates acceptable)
- Daily execution pattern over morning coffee
- User controls restart timing (no auto-reboot)
- Homebrew in WSL provides consistency with user's 4 macOS machines
- No --force flags to avoid breaking dependencies
