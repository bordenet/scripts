#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: check-alpine-version.sh
#
# Description: This script checks if the Alpine Linux version specified in the
#              sandbox setup script is the latest stable version available from
#              the official Alpine Linux website.
#
# Usage: ./check-alpine-version.sh
#
# Dependencies: curl, grep, sed, awk
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Script Setup ---
start_time=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# --- Main Script ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Alpine Linux Version Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Get the currently configured version from the setup script.
if [ -f "setup_sandbox.sh" ]; then
    CURRENT_VERSION=$(grep "^ALPINE_VERSION=" setup_sandbox.sh | cut -d'"' -f2 | head -1)
    echo "Current version configured in setup_sandbox.sh: $CURRENT_VERSION"
else
    echo "Error: setup_sandbox.sh not found. Cannot determine current version."
    exit 1
fi

echo ""
echo "Checking Alpine Linux website for the latest stable version..."
echo ""

# Scrape the downloads page for the latest version number.
LATEST_VERSION_RAW=$(curl -s https://alpinelinux.org/downloads/ | grep -o "alpine-virt-[0-9]\+\.[0-9]\+\.[0-9]\+-x86_64.iso" | head -1)
LATEST_VERSION=$(echo "$LATEST_VERSION_RAW" | sed 's/alpine-virt-//' | sed 's/-x86_64.iso//')

if [ -n "$LATEST_VERSION" ]; then
    echo "Latest stable version available: $LATEST_VERSION"
    if [ "$CURRENT_VERSION" == "$LATEST_VERSION" ]; then
        echo "✅ You are using the latest version."
    else
        echo "⚠️ A newer version is available."
    fi
else
    echo "❌ Could not determine the latest version from the Alpine Linux website."
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "alpine.iso" ]; then
    LOCAL_SIZE=$(ls -lh alpine.iso | awk '{print $5}')
    echo "✅ Local alpine.iso exists ($LOCAL_SIZE)"
else
    echo "❌ No alpine.iso found - run ./setup_sandbox.sh to download"
fi

echo ""
echo "📝 To update to a new version:"
echo "   1. Edit setup_sandbox.sh"
# The following line has been corrected to properly escape the double quote within the string.
echo "   2. Change ALPINE_VERSION=\"$CURRENT_VERSION\" to the new version"
echo "   3. Remove alpine.iso: rm alpine.iso"
echo "   4. Run ./setup_sandbox.sh to download the new version"

echo ""
echo "🔗 Manual check: https://alpinelinux.org/downloads/"
echo ""

# --- Completion ---
end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo "Execution time: ${execution_time} seconds"