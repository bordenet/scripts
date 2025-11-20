#!/usr/bin/env bash
################################################################################
# mu.sh Helper Functions Library
################################################################################
# PURPOSE: Shared utility functions for mu.sh (Matt's Update script)
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/lib/mu-helpers.sh"
################################################################################

set -o pipefail

# Configuration
LOG_DIR="${LOG_DIR:-/tmp}"
LOG_RETENTION_HOURS="${LOG_RETENTION_HOURS:-24}"

# Error collection
declare -a ERRORS

################################################################################
# Visual Feedback Functions
################################################################################

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

################################################################################
# Phase Execution Functions
################################################################################

# Run command with spinner, timeout, and error capture
run_phase() {
    local phase_name=$1
    local log_file=$2
    local timeout_seconds=600  # 10 minutes default
    shift 2
    local cmd=("$@")

    printf "%-30s" "$phase_name..."

    # Ensure log file is writable by creating it first
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

################################################################################
# Maintenance Functions
################################################################################

# Clean up old logs
cleanup_old_logs() {
    find "$LOG_DIR" -name "mu_*.log" -type f -mtime +1 -delete 2>/dev/null || true
}

################################################################################
# Reporting Functions
################################################################################

# Print error report
print_error_report() {
    local execution_time=$1
    local error_count=${#ERRORS[@]}

    echo ""
    echo "=================================================="
    echo "UPDATE SUMMARY"
    echo "=================================================="
    echo "Execution Time: $execution_time seconds"
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


################################################################################
# Windows Update Helper
################################################################################

# Run Windows Update via PowerShell (requires elevation)
run_windows_update() {
    printf "%-30s" "Windows Update..."

    # Create a temporary PowerShell script
    local temp_ps_script
    temp_ps_script=$(mktemp --suffix=.ps1)
    local win_ps_script
    win_ps_script=$(wslpath -w "$temp_ps_script")
    local win_log_file
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
    local pid=$!
    spinner $pid 600
    local spinner_exit=$?

    # Clean up
    rm -f "$temp_ps_script"

    if [ $spinner_exit -eq 124 ]; then
        echo "⏱ TIMEOUT"
        ERRORS+=("Windows Update timed out after 600s - see $LOG_DIR/mu_windows_update.log")
    else
        wait $pid 2>/dev/null
        local wu_exit=$?

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
}
