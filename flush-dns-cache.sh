#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: flush-dns-cache.sh
#
# Description: This script flushes the DNS cache on macOS, Windows/WSL, and Linux.
#              Automatically detects the platform and uses the appropriate method.
#
# Platform: Cross-platform (macOS, Windows/WSL, Linux)
#
# Usage: ./flush-dns-cache.sh
#
# Author: Matt J Bordenet
#
# Last Updated: 2025-01-11
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    flush-dns-cache.sh - Flush DNS cache across multiple platforms

SYNOPSIS
    flush-dns-cache.sh [OPTIONS]

DESCRIPTION
    Flushes the DNS cache on macOS, Windows/WSL, and Linux. Automatically detects
    the platform and uses the appropriate method for that system.

OPTIONS
    -h, --help
        Display this help message and exit.

PLATFORM
    Cross-platform (macOS, Windows/WSL, Linux)

EXAMPLES
    # Flush DNS cache
    ./flush-dns-cache.sh

PLATFORM-SPECIFIC METHODS
    macOS:
        Uses dscacheutil and mDNSResponder

    Windows/WSL:
        Flushes both Windows DNS cache via PowerShell and WSL systemd-resolved

    Linux:
        Attempts multiple methods: systemd-resolved, nscd, dnsmasq

NOTES
    May require sudo privileges on some platforms.
    On Windows, may require Administrator privileges.

AUTHOR
    Matt J Bordenet

SEE ALSO
    dscacheutil(1), resolvectl(1), nscd(8), systemd-resolved(8)

EOF
    exit 0
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# Start timer
start_time=$(date +%s)

# --- Platform Detection ---
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

# --- Platform-Specific DNS Flush Functions ---

flush_dns_macos() {
    echo "Flushing DNS cache on macOS..."
    sudo dscacheutil -flushcache
    sudo killall -HUP mDNSResponder
    echo "✓ macOS DNS cache flushed successfully."
}

flush_dns_wsl() {
    echo "Flushing DNS cache on Windows via WSL..."
    # Flush Windows DNS cache via PowerShell
    powershell.exe -Command "Clear-DnsClientCache" 2>/dev/null || {
        echo "⚠️  Warning: Failed to flush Windows DNS cache. May require administrator privileges."
        echo "   Try running PowerShell as Administrator and execute: Clear-DnsClientCache"
    }

    # Also flush WSL's own DNS if systemd-resolved is running
    if command -v resolvectl &> /dev/null; then
        echo "Flushing WSL systemd-resolved cache..."
        sudo resolvectl flush-caches 2>/dev/null || true
    fi

    echo "✓ Windows/WSL DNS cache flush attempted."
}

flush_dns_linux() {
    echo "Flushing DNS cache on Linux..."

    # Try systemd-resolved (Ubuntu 18.04+, Fedora, etc.)
    if command -v resolvectl &> /dev/null; then
        echo "Using systemd-resolved..."
        sudo resolvectl flush-caches
        echo "✓ systemd-resolved cache flushed."
    elif command -v systemd-resolve &> /dev/null; then
        echo "Using systemd-resolve (legacy)..."
        sudo systemd-resolve --flush-caches
        echo "✓ systemd-resolve cache flushed."
    # Try nscd (older systems)
    elif command -v nscd &> /dev/null; then
        echo "Using nscd..."
        sudo nscd -i hosts
        echo "✓ nscd cache flushed."
    # Try dnsmasq
    elif systemctl is-active --quiet dnsmasq 2>/dev/null; then
        echo "Using dnsmasq..."
        sudo systemctl restart dnsmasq
        echo "✓ dnsmasq restarted."
    else
        echo "⚠️  Warning: No recognized DNS caching service found."
        echo "   Common services: systemd-resolved, nscd, dnsmasq"
        echo "   Your system may not be caching DNS, or uses a different service."
    fi
}

flush_dns_windows() {
    echo "Flushing DNS cache on Windows (Git Bash/MSYS)..."
    # On native Windows (Git Bash, MSYS, Cygwin), call ipconfig directly
    ipconfig //flushdns || {
        echo "⚠️  Warning: Failed to flush DNS cache. May require administrator privileges."
        echo "   Try running as Administrator."
    }
    echo "✓ Windows DNS cache flush attempted."
}

# --- Main Execution ---

PLATFORM=$(detect_platform)

echo "Detected platform: $PLATFORM"
echo ""

case "$PLATFORM" in
    macos)
        flush_dns_macos
        ;;
    wsl)
        flush_dns_wsl
        ;;
    linux)
        flush_dns_linux
        ;;
    windows)
        flush_dns_windows
        ;;
    *)
        echo "❌ Error: Unknown or unsupported platform: $(uname -s)" >&2
        exit 1
        ;;
esac

# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo ""
echo "Execution time: ${execution_time} seconds"