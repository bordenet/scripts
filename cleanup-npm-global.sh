#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: cleanup-npm-global.sh
#
# Description: This script helps manage and clean up globally installed npm
#              packages. It lists all global packages, checks for known
#              deprecated modules, and provides interactive prompts to
#              uninstall packages and reinstall a core set of tools.
#
# Platform: Cross-platform
#
# Usage: ./cleanup-npm-global.sh
#
# Dependencies: npm
#
# Author: Matt J Bordenet
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit on error, undefined variable, or pipe failure
set -euo pipefail

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    cleanup-npm-global.sh - Manage and clean up globally installed npm packages

SYNOPSIS
    cleanup-npm-global.sh [OPTIONS]

DESCRIPTION
    Helps manage and clean up globally installed npm packages. Lists all global
    packages, checks for known deprecated modules, and provides interactive prompts
    to uninstall packages and reinstall a core set of tools.

OPTIONS
    -h, --help
        Display this help message and exit.

PLATFORM
    Cross-platform (macOS, Linux, WSL)

DEPENDENCIES
    • npm - Node.js package manager

EXAMPLES
    # Run interactive cleanup
    ./cleanup-npm-global.sh

NOTES
    This script provides interactive prompts before making any changes.
    A log file is created at /tmp/npm-global-cleanup-YYYYMMDD-HHMMSS.log

AUTHOR
    Matt J Bordenet

SEE ALSO
    npm(1), npm-list(1), npm-uninstall(1)

EOF
    exit 0
}

# Parse arguments
case "${1:-}" in
    -h|--help)
        show_help
        ;;
esac

# --- Script Setup ---
start_time=$(date +%s)
LOG_FILE="/tmp/npm-global-cleanup-$(date +%Y%m%d-%H%M%S).log"
touch "$LOG_FILE"

echo "--- NPM Global Package Cleanup ---"
echo "Full log will be saved to: ${LOG_FILE}"
echo ""

# --- Main Logic ---

# 1. List globally installed packages
echo "🔍 Checking globally installed npm packages..."
GLOBAL_LIST=$(npm ls -g --depth=0 || echo "⚠️ Failed to list global packages")
echo "${GLOBAL_LIST}" | tee -a "${LOG_FILE}"

# 2. Check for specific deprecated modules
echo ""
echo "📦 Checking for deprecated modules (e.g., inflight)..."
INFLIGHT_TREE=$(npm ls -g inflight 2>/dev/null || echo "No inflight module found.")
echo "${INFLIGHT_TREE}" | tee -a "${LOG_FILE}"

if echo "${INFLIGHT_TREE}" | grep -q "inflight@"; then
  echo "⚠️ 'inflight' detected. This is a deprecated dependency. Consider removing the parent package." | tee -a "${LOG_FILE}"
else
  echo "✅ No 'inflight' module detected." | tee -a "${LOG_FILE}"
fi

# 3. Interactive Uninstall
echo ""
read -r -p "🧹 Do you want to uninstall any packages? [y/N] " UNINSTALL_CONFIRM
if [[ "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Enter package names to uninstall (space-separated), then press ENTER:"
  read -r TO_REMOVE
  if [ -n "$TO_REMOVE" ]; then
    for pkg in $TO_REMOVE; do
      echo "---"
      echo "Attempting to uninstall '$pkg'..." | tee -a "$LOG_FILE"
      if npm uninstall -g "$pkg"; then
        echo "✅ Successfully uninstalled '$pkg'" | tee -a "$LOG_FILE"
      else
        echo "❌ Failed to uninstall '$pkg'. It may not be installed or another error occurred." | tee -a "$LOG_FILE"
      fi
    done
  else
    echo "No packages entered. Skipping uninstall."
  fi
else
  echo "🚫 Skipping uninstall step." | tee -a "$LOG_FILE"
fi

# 4. Interactive Reinstall of Core Tools
echo ""
read -r -p "🔁 Reinstall a core set of tools (typescript, npm, aws-cdk)? [y/N] " REINSTALL_CONFIRM
if [[ "$REINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
  CORE_TOOLS=(typescript npm aws-cdk)
  echo "---"
  echo "Reinstalling core tools..."
  for tool in "${CORE_TOOLS[@]}"; do
    echo "Installing '$tool'..." | tee -a "$LOG_FILE"
    if npm install -g "$tool"; then
      echo "✅ Successfully installed '$tool'" | tee -a "$LOG_FILE"
    else
      echo "❌ Failed to install '$tool'" | tee -a "$LOG_FILE"
    fi
  done
else
  echo "🚫 Skipping reinstall step." | tee -a "$LOG_FILE"
fi

# --- Completion ---
end_time=$(date +%s)
execution_time=$((end_time - start_time))

echo ""
echo "---"
echo "✅ Cleanup process complete."
echo "📄 Log saved to ${LOG_FILE}"
echo "Execution time: ${execution_time} seconds."