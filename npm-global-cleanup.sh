#!/bin/bash

set -euo pipefail

LOG_FILE="/tmp/npm-global-cleanup.log"
touch "$LOG_FILE"

echo "🔍 Checking globally installed npm packages..."
GLOBAL_LIST=$(npm ls -g --depth=0 || echo "⚠️ Failed to list global packages")
echo "$GLOBAL_LIST" | tee -a "$LOG_FILE"

echo ""
echo "📦 Checking for deprecated modules like inflight, glob < v9, etc..."
INFLIGHT_TREE=$(npm ls -g inflight 2>/dev/null || echo "No inflight module found.")
echo "$INFLIGHT_TREE" | tee -a "$LOG_FILE"

if echo "$INFLIGHT_TREE" | grep -q "inflight@"; then
  echo "⚠️ inflight detected. Consider removing the parent package (e.g., jest)." | tee -a "$LOG_FILE"
else
  echo "✅ No inflight module detected." | tee -a "$LOG_FILE"
fi

echo ""
read -r -p "🧹 Do you want to uninstall deprecated or unused packages? [y/N] " UNINSTALL_CONFIRM
if [[ "$UNINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
  echo ""
  echo "Enter package names to uninstall (space-separated):"
  read -r TO_REMOVE
  for pkg in $TO_REMOVE; do
    echo "Attempting to remove $pkg..." | tee -a "$LOG_FILE"
    if npm uninstall -g "$pkg"; then
      echo "✅ Successfully removed $pkg" | tee -a "$LOG_FILE"
    else
      echo "❌ Failed to remove $pkg" | tee -a "$LOG_FILE"
    fi
  done
else
  echo "🚫 Skipping uninstall step." | tee -a "$LOG_FILE"
fi

echo ""
read -r -p "🔁 Reinstall core tools (typescript, npm, aws-cdk)? [y/N] " REINSTALL_CONFIRM
if [[ "$REINSTALL_CONFIRM" =~ ^[Yy]$ ]]; then
  CORE_TOOLS=(typescript npm aws-cdk)
  for tool in "${CORE_TOOLS[@]}"; do
    echo "Installing $tool..." | tee -a "$LOG_FILE"
    if npm install -g "$tool"; then
      echo "✅ Installed $tool" | tee -a "$LOG_FILE"
    else
      echo "❌ Failed to install $tool" | tee -a "$LOG_FILE"
    fi
  done
else
  echo "🚫 Skipping reinstall step." | tee -a "$LOG_FILE"
fi

echo ""
echo "📄 Cleanup complete. Log saved to $LOG_FILE"
