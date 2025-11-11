#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: mu.sh (Matt's Update)
#
# Description: Comprehensive system update script for WSL + Windows environments.
#              Updates apt, version managers (nvm, rbenv, rustup), Homebrew (optional),
#              npm, pip/pipx in WSL, then triggers winget and Windows Update via PowerShell
#              interop with UAC elevation. Optimized for ARM64 architecture with native
#              tools. Designed for daily manual execution with compact console output and
#              actionable error reporting.
#
# Usage: ./mu.sh [--skip-windows-update]
#
# Options:
#   --skip-windows-update    Skip Windows Update (winget will still run)
#
# Dependencies:
#   WSL: apt, nvm (optional), rbenv (optional), rustup (optional), Homebrew (optional), npm, pip, pipx (optional)
#   Windows: PowerShell with UAC elevation, winget, PSWindowsUpdate module
#
# Author: Claude Code
# Last Updated: 2025-01-10
#
# -----------------------------------------------------------------------------

# Don't exit on error - we handle errors explicitly and continue
set -o pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

LOG_DIR="/tmp"
LOG_RETENTION_HOURS=24
ERRORS=()
SKIP_WINDOWS_UPDATE=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-windows-update)
            SKIP_WINDOWS_UPDATE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--skip-windows-update]"
            echo ""
            echo "Options:"
            echo "  --skip-windows-update    Skip Windows Update (winget will still run)"
            echo "  -h, --help              Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# -----------------------------------------------------------------------------
# Helper Functions
# -----------------------------------------------------------------------------

# Spinner function for visual feedback with timeout
spinner() {
    local pid=$1
    local timeout_seconds=${2:-600}  # Default 10 minutes
    local delay=0.1
    local spinstr='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local elapsed=0

    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " %c  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"

        elapsed=$((elapsed + 1))
        # Check timeout (elapsed * delay = seconds)
        if [ $elapsed -gt $((timeout_seconds * 10)) ]; then
            kill -9 $pid 2>/dev/null
            printf "    \b\b\b\b"
            return 124  # Timeout exit code
        fi
    done
    printf "    \b\b\b\b"
    return 0
}

# Run command with spinner, timeout, and error capture
run_phase() {
    local phase_name=$1
    local log_file=$2
    local timeout_seconds=600  # 10 minutes default
    shift 2
    local cmd=("$@")

    printf "%-30s" "$phase_name..."

    # Ensure log file is writable by creating it first
    # This handles cases where the command uses sudo but redirection doesn't
    touch "$log_file" 2>/dev/null || {
        # If touch fails, try with sudo
        sudo touch "$log_file" 2>/dev/null || {
            echo "✗"
            ERRORS+=("$phase_name failed - cannot create log file $log_file")
            return 1
        }
        # Make it writable by current user
        sudo chmod 666 "$log_file" 2>/dev/null
    }

    # Run command in background
    "${cmd[@]}" > "$log_file" 2>&1 &
    local pid=$!

    # Show spinner with timeout
    spinner $pid $timeout_seconds
    local spinner_exit=$?

    # Check if timed out
    if [ $spinner_exit -eq 124 ]; then
        echo "⏱ TIMEOUT"
        ERRORS+=("$phase_name timed out after ${timeout_seconds}s - see $log_file")
        return 124
    fi

    # Check exit status
    wait $pid 2>/dev/null
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo "✓"
        return 0
    else
        echo "✗"
        ERRORS+=("$phase_name failed (exit code: $exit_code) - see $log_file")
        return 1
    fi
}

# Wait for PID with timeout
wait_with_timeout() {
    local pid=$1
    local timeout_seconds=${2:-600}  # Default 10 minutes
    local elapsed=0
    local delay=0.1

    while ps -p "$pid" > /dev/null 2>&1; do
        sleep $delay
        elapsed=$((elapsed + 1))
        # Check timeout (elapsed * delay = seconds)
        if [ $elapsed -gt $((timeout_seconds * 10)) ]; then
            kill -9 $pid 2>/dev/null
            return 124  # Timeout exit code
        fi
    done

    wait $pid 2>/dev/null
    return $?
}

# Clean up old logs
cleanup_old_logs() {
    find "$LOG_DIR" -name "mu_*.log" -type f -mtime +1 -delete 2>/dev/null || true
}

# Print error report
print_error_report() {
    local error_count=${#ERRORS[@]}

    echo ""
    echo "=================================================="
    echo "UPDATE SUMMARY"
    echo "=================================================="
    echo "Execution Time: $1 seconds"
    echo ""

    if [ $error_count -eq 0 ]; then
        echo "✓ All updates completed successfully!"
        echo "=================================================="
    else
        echo "⚠ ERRORS DETECTED ($error_count)"
        echo "=================================================="
        echo ""
        local i=1
        for error in "${ERRORS[@]}"; do
            echo "$i. $error"
            echo ""
            i=$((i + 1))
        done
        echo "Review logs in $LOG_DIR for details."
        echo "=================================================="
    fi
}

# -----------------------------------------------------------------------------
# Main Script
# -----------------------------------------------------------------------------

echo "=================================================="
echo "mu.sh - Matt's Update Script"
echo "=================================================="
echo ""

# Start timer
start_time=$(date +%s)

# Request sudo upfront
echo "Requesting sudo privileges..."
if sudo -v; then
    echo "✓ Sudo privileges granted"
    # Keep sudo alive in background - exit if parent dies
    (while true; do sudo -n true; sleep 50; kill -0 $$ 2>/dev/null || exit; done 2>/dev/null) &
    SUDO_KEEPER_PID=$!
else
    echo "⚠ Sudo authentication failed - some operations may require manual password entry"
fi
echo ""

# Clean up old logs
cleanup_old_logs

# -----------------------------------------------------------------------------
# Phase 1: WSL Updates
# -----------------------------------------------------------------------------

echo "PHASE 1: WSL Updates"
echo "--------------------------------------------------"

# apt updates
run_phase "apt update" "$LOG_DIR/mu_apt_update.log" \
    sudo apt update || true

run_phase "apt upgrade" "$LOG_DIR/mu_apt_upgrade.log" \
    sudo apt upgrade -y || true

run_phase "apt autoremove" "$LOG_DIR/mu_apt_autoremove.log" \
    sudo apt autoremove -y || true

run_phase "apt autoclean" "$LOG_DIR/mu_apt_autoclean.log" \
    sudo apt autoclean || true

# Homebrew updates
if command -v brew &> /dev/null; then
    # Warn on ARM64 about limited support
    if [ "$(uname -m)" = "aarch64" ]; then
        echo "⚠ Homebrew on ARM64 Linux - limited package support"
        echo "  Consider using nvm, rbenv, rustup for language runtimes"
    fi

    run_phase "brew update" "$LOG_DIR/mu_brew_update.log" \
        brew update || true

    run_phase "brew upgrade" "$LOG_DIR/mu_brew_upgrade.log" \
        brew upgrade || true

    run_phase "brew cleanup" "$LOG_DIR/mu_brew_cleanup.log" \
        brew cleanup || true

    # brew doctor - capture warnings but don't fail
    printf "%-30s" "brew doctor..."
    if brew doctor > "$LOG_DIR/mu_brew_doctor.log" 2>&1; then
        echo "✓"
    else
        echo "⚠"
        ERRORS+=("brew doctor warnings - see $LOG_DIR/mu_brew_doctor.log")
    fi
else
    echo "⊘ Homebrew not installed - skipping"
fi

# nvm (Node Version Manager) updates
if [ -d "$HOME/.nvm" ]; then
    printf "%-30s" "nvm update..."
    (
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        # Update nvm itself
        cd "$NVM_DIR" && git fetch --tags origin && git checkout `git describe --abbrev=0 --tags --match "v[0-9]*" $(git rev-list --tags --max-count=1)` && \. "$NVM_DIR/nvm.sh"
    ) > "$LOG_DIR/mu_nvm.log" 2>&1 &
    pid=$!
    spinner $pid 600
    spinner_exit=$?

    if [ $spinner_exit -eq 124 ]; then
        echo "⏱ TIMEOUT"
        ERRORS+=("nvm update timed out after 600s - see $LOG_DIR/mu_nvm.log")
    else
        wait $pid 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✓"
        else
            echo "✗"
            ERRORS+=("nvm update failed - see $LOG_DIR/mu_nvm.log")
        fi
    fi
else
    echo "⊘ nvm not installed - skipping"
fi

# rbenv (Ruby Version Manager) updates
if command -v rbenv &> /dev/null; then
    run_phase "rbenv update" "$LOG_DIR/mu_rbenv.log" \
        bash -c "cd ~/.rbenv && git pull" || true

    # Update ruby-build plugin
    if [ -d "$HOME/.rbenv/plugins/ruby-build" ]; then
        run_phase "ruby-build update" "$LOG_DIR/mu_ruby_build.log" \
            bash -c "cd ~/.rbenv/plugins/ruby-build && git pull" || true
    fi
else
    echo "⊘ rbenv not installed - skipping"
fi

# rustup updates
if command -v rustup &> /dev/null; then
    run_phase "rustup update" "$LOG_DIR/mu_rustup.log" \
        rustup update || true
else
    echo "⊘ rustup not installed - skipping"
fi

# npm updates (global packages)
if command -v npm &> /dev/null; then
    run_phase "npm update -g" "$LOG_DIR/mu_npm_update.log" \
        npm update -g || true

    run_phase "npm install -g npm" "$LOG_DIR/mu_npm_self.log" \
        npm install -g npm || true
else
    echo "⊘ npm not installed - skipping"
fi

# pip3 updates - skip on externally-managed environments
if command -v pip3 &> /dev/null; then
    # Check if this is an externally-managed environment
    # 1. Check for Linux EXTERNALLY-MANAGED marker file
    # 2. Check if pip3 install fails with externally-managed error (Homebrew on macOS)
    is_externally_managed=false

    if [ -f "/usr/lib/python$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')/EXTERNALLY-MANAGED" ]; then
        is_externally_managed=true
    elif python3 -m pip install --help 2>&1 | grep -q "externally-managed-environment" 2>/dev/null; then
        # Quick check without actually attempting an install
        is_externally_managed=true
    elif ! python3 -m pip install --dry-run --upgrade pip >/dev/null 2>&1; then
        # Last resort: test if pip upgrade would fail
        if python3 -m pip install --dry-run --upgrade pip 2>&1 | grep -q "externally-managed"; then
            is_externally_managed=true
        fi
    fi

    if [ "$is_externally_managed" = true ]; then
        echo "⊘ pip3 externally-managed - use apt/pipx/brew instead"
    else
        run_phase "pip3 upgrade" "$LOG_DIR/mu_pip3_upgrade.log" \
            python3 -m pip install --upgrade pip || true

        # Update all installed pip3 packages
        printf "%-30s" "pip3 update packages..."
        (
            set +o pipefail  # Disable pipefail for this section
            outdated=$(pip3 list --outdated --format=freeze 2>/dev/null | cut -d= -f1)
            if [ -n "$outdated" ]; then
                echo "$outdated" | xargs -n1 pip3 install --upgrade
            fi
        ) > "$LOG_DIR/mu_pip3_packages.log" 2>&1 &
        pid=$!
        spinner $pid 600
        spinner_exit=$?

        if [ $spinner_exit -eq 124 ]; then
            echo "⏱ TIMEOUT"
            ERRORS+=("pip3 package updates timed out after 600s - see $LOG_DIR/mu_pip3_packages.log")
        else
            wait $pid 2>/dev/null
            if [ $? -eq 0 ]; then
                echo "✓"
            else
                echo "✗"
                ERRORS+=("pip3 package updates failed - see $LOG_DIR/mu_pip3_packages.log")
            fi
        fi
    fi
else
    echo "⊘ pip3 not installed - skipping"
fi

# pipx updates (for externally-managed Python environments)
if command -v pipx &> /dev/null; then
    run_phase "pipx upgrade-all" "$LOG_DIR/mu_pipx_upgrade.log" \
        pipx upgrade-all || true
else
    echo "⊘ pipx not installed - skipping"
fi

# pip (Python 2) updates if present
if command -v pip &> /dev/null && [[ $(pip --version) == *"python 2"* ]]; then
    run_phase "pip upgrade" "$LOG_DIR/mu_pip_upgrade.log" \
        python -m pip install --upgrade pip || true

    printf "%-30s" "pip update packages..."
    (
        set +o pipefail  # Disable pipefail for this section
        outdated=$(pip list --outdated --format=freeze 2>/dev/null | cut -d= -f1)
        if [ -n "$outdated" ]; then
            echo "$outdated" | xargs -n1 pip install --upgrade
        fi
    ) > "$LOG_DIR/mu_pip_packages.log" 2>&1 &
    pid=$!
    spinner $pid 600
    spinner_exit=$?

    if [ $spinner_exit -eq 124 ]; then
        echo "⏱ TIMEOUT"
        ERRORS+=("pip package updates timed out after 600s - see $LOG_DIR/mu_pip_packages.log")
    else
        wait $pid 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "✓"
        else
            echo "✗"
            ERRORS+=("pip package updates failed - see $LOG_DIR/mu_pip_packages.log")
        fi
    fi
fi

echo ""

# -----------------------------------------------------------------------------
# Phase 2: Windows Updates (via PowerShell)
# -----------------------------------------------------------------------------

echo "PHASE 2: Windows Updates"
echo "--------------------------------------------------"

# Check if we're in WSL
if grep -qi microsoft /proc/version 2>/dev/null; then
    # winget updates
    printf "%-30s" "winget upgrade..."

    # Ensure log file is writable
    touch "$LOG_DIR/mu_winget.log" 2>/dev/null || sudo touch "$LOG_DIR/mu_winget.log" 2>/dev/null
    [ -f "$LOG_DIR/mu_winget.log" ] && sudo chmod 666 "$LOG_DIR/mu_winget.log" 2>/dev/null

    # Note: winget may require UAC elevation for package installs
    # Use --accept-package-agreements, --accept-source-agreements, and --disable-interactivity
    # to minimize prompts, but UAC may still block automation
    powershell.exe -Command "winget upgrade --all --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | Out-String" > "$LOG_DIR/mu_winget.log" 2>&1 &
    pid=$!
    spinner $pid 600
    spinner_exit=$?

    if [ $spinner_exit -eq 124 ]; then
        echo "⏱ TIMEOUT"
        ERRORS+=("winget upgrade timed out after 600s - likely waiting for UAC prompt - see $LOG_DIR/mu_winget.log")
    else
        wait $pid 2>/dev/null
        winget_exit=$?
        if [ $winget_exit -eq 0 ]; then
            echo "✓"
        else
            echo "⚠"
            # Don't treat as hard error - may need manual UAC approval
            ERRORS+=("winget upgrade incomplete (exit: $winget_exit) - may need UAC approval - see $LOG_DIR/mu_winget.log")
        fi
    fi

    # Windows Update (requires elevation)
    if [ "$SKIP_WINDOWS_UPDATE" = true ]; then
        echo "⊘ Windows Update skipped (--skip-windows-update)"
    else
        printf "%-30s" "Windows Update..."

        # Create a temporary PowerShell script
        temp_ps_script=$(mktemp --suffix=.ps1)
        win_ps_script=$(wslpath -w "$temp_ps_script")
        win_log_file=$(wslpath -w "$LOG_DIR/mu_windows_update.log")

        # Write the PowerShell script that will run elevated
        cat > "$temp_ps_script" << 'PSEOF'
param($LogFile)
$ErrorActionPreference = "Continue"
$output = @()

try {
    # Install PSWindowsUpdate if not present
    if (!(Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        $output += "Installing PSWindowsUpdate module..."
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser
    }

    # Import module
    Import-Module PSWindowsUpdate

    # Run Windows Update
    $updates = Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false
    $output += $updates | Format-List | Out-String

    if (!$updates) {
        $output += "No updates available."
    }
}
catch {
    $output += "Error: $_"
    $output += $_.ScriptStackTrace
}

$output | Out-File -FilePath $LogFile -Encoding UTF8
PSEOF

        # Use Start-Process with -Verb RunAs to elevate
        # The outer powershell.exe launches the elevated one
        powershell.exe -NoProfile -Command "
            Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', '$win_ps_script', '$win_log_file' -Verb RunAs -Wait -WindowStyle Normal
        " > /dev/null 2>&1 &
        pid=$!
        spinner $pid 600
        spinner_exit=$?

        # Clean up
        rm -f "$temp_ps_script"

        if [ $spinner_exit -eq 124 ]; then
            echo "⏱ TIMEOUT"
            ERRORS+=("Windows Update timed out after 600s - see $LOG_DIR/mu_windows_update.log")
        else
            wait $pid 2>/dev/null
            wu_exit=$?

            # Check the result
            if [ $wu_exit -eq 0 ] && [ -f "$LOG_DIR/mu_windows_update.log" ]; then
                if grep -qi "PermissionDenied\|AccessDenied\|elevated" "$LOG_DIR/mu_windows_update.log" 2>/dev/null; then
                    echo "✗"
                    ERRORS+=("Windows Update requires elevation - UAC prompt may have been dismissed - see $LOG_DIR/mu_windows_update.log")
                elif grep -qi "Error:" "$LOG_DIR/mu_windows_update.log" 2>/dev/null; then
                    echo "⚠"
                    ERRORS+=("Windows Update completed with errors - see $LOG_DIR/mu_windows_update.log")
                else
                    echo "✓"
                fi
            else
                echo "✗"
                ERRORS+=("Windows Update failed - see $LOG_DIR/mu_windows_update.log")
            fi
        fi
    fi
else
    echo "⊘ Not running in WSL - skipping Windows updates"
fi

echo ""

# -----------------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------------

# Kill sudo keeper process if it exists
if [ -n "$SUDO_KEEPER_PID" ]; then
    kill $SUDO_KEEPER_PID 2>/dev/null || true
fi

# Calculate execution time
end_time=$(date +%s)
execution_time=$((end_time - start_time))

# Print error report
print_error_report $execution_time

exit 0
