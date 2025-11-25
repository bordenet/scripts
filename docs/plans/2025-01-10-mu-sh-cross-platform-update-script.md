# mu.sh - Cross-Platform Update Script for WSL/Windows

## Overview

**Purpose:** Comprehensive system update script for WSL environment that also updates Windows packages and OS. Designed for daily manual execution over morning coffee.

**Name:** `mu.sh` (Matt's Update script)

**Target Environment:** Microsoft Surface (ARM64/aarch64) running WSL (primary) + Windows 11 with PowerShell

**Design Philosophy:**
- Single command execution from WSL terminal
- Compact, high signal-to-noise console output
- Comprehensive error reporting at end
- No aggressive flags (no --force)
- Daily use pattern
- ARM64-optimized with native version managers

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
2. nvm (Node Version Manager) - ARM64 optimized
3. rbenv (Ruby Version Manager) - ARM64 optimized
4. rustup (Rust toolchain manager) - ARM64 optimized
5. Homebrew (optional, for tools with good ARM64 Linux support)
6. npm (global packages)
7. pip/pip3 (Python package manager and packages)

**Phase 2: Windows Updates (via PowerShell interop)**
1. winget (Windows package manager)
2. Windows Update (OS patches and security updates)

### Package Manager Strategy

**ARM64 Hybrid Approach:**

**WSL (Primary - Native Version Managers):**
- **apt:** System utilities and base packages (good ARM64 support)
- **nvm:** Node.js version management (better ARM64 support than Homebrew)
- **rbenv:** Ruby version management (native ARM64 builds)
- **rustup:** Rust toolchain (official ARM64 support)
- **Homebrew (optional):** For dev tools with good ARM64 Linux support
  - Only used where packages are available and stable
  - Falls back gracefully if not installed
  - Provides some consistency with macOS bu.sh workflow

**Rationale for ARM64:**
- Homebrew on ARM64 Linux has limited package support
- Many formulae lack ARM64 Linux bottles
- Native version managers (nvm, rbenv, rustup) provide better ARM64 compatibility
- Reduces compilation failures and dependency issues

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

**nvm updates:**
```bash
# Update nvm itself via git
cd ~/.nvm && git fetch --tags origin
git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)`
```
- Only runs if `~/.nvm` directory exists
- Updates to latest stable version
- ARM64 compatible

**rbenv updates:**
```bash
# Update rbenv itself
cd ~/.rbenv && git pull

# Update ruby-build plugin
cd ~/.rbenv/plugins/ruby-build && git pull
```
- Only runs if `rbenv` command exists
- Updates both rbenv and ruby-build plugin
- Ensures access to latest Ruby versions with ARM64 support

**rustup updates:**
```bash
rustup update            # Update Rust toolchain
```
- Only runs if `rustup` command exists
- Updates all installed toolchains
- Official ARM64 support

**Homebrew updates (optional):**
```bash
brew update              # Update Homebrew itself
brew upgrade             # Upgrade all packages (no --force)
brew cleanup             # Remove old versions
brew doctor              # Check for issues (warnings → error report)
```
- Only runs if `brew` command exists
- Provides some consistency with macOS workflow
- Limited ARM64 Linux support, use cautiously

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

**Critical implementation details:**
- **No `set -e`**: Script must NOT use `set -e` to allow continuation through errors
- **`set -o pipefail`**: Used to catch pipeline failures, but disabled in specific sections
- **`|| true` on all commands**: Ensures no command causes script exit
- **Subshells for pip operations**: Wrap pip list pipelines in `()` with `set +o pipefail`

```bash
# Error collection array
ERRORS=()

# Capture pattern with run_phase function
run_phase "apt upgrade" "$LOG_DIR/mu_apt_upgrade.log" \
    sudo apt upgrade -y || true

# For pip operations with pipelines
(
    set +o pipefail  # Disable pipefail for this section
    outdated=$(pip3 list --outdated --format=freeze 2>/dev/null | cut -d= -f1)
    if [ -n "$outdated" ]; then
        echo "$outdated" | xargs -n1 pip3 install --upgrade
    fi
) > "$LOG_DIR/mu_pip3_packages.log" 2>&1 &

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

**WSL (Required):**
- apt (built-in to Ubuntu/Debian WSL)
- Python 3 with pip
- npm (via nvm or direct install)

**WSL (Optional - Installed = Auto-updated):**
- nvm (Node Version Manager) - Recommended for ARM64
- rbenv (Ruby Version Manager) - Recommended for ARM64
- rustup (Rust toolchain) - Recommended for ARM64
- Homebrew for Linux - Optional, limited ARM64 support

**Windows (must be accessible from WSL):**
- PowerShell (built into Windows 11)
- winget (built into Windows 11)
- PSWindowsUpdate module (script installs if missing)

---

## Notes

- Script designed for managed corporate PC (aggressive updates acceptable)
- Daily execution pattern over morning coffee
- User controls restart timing (no auto-reboot)
- **ARM64 optimized:** Uses native version managers (nvm, rbenv, rustup) for better compatibility
- Homebrew optional in WSL (limited ARM64 support, use cautiously)
- Provides some consistency with user's 4 macOS machines via optional Homebrew
- No --force flags to avoid breaking dependencies
- All package managers gracefully skipped if not installed
