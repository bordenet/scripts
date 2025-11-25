#!/usr/bin/env bash

set -euo pipefail

[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

# ┌────────────────────────────────────────────────────────────┐
# │                  Homebrew Environment Cloner               │
# │     Export and import brew packages + casks for macOS      │
# │     Author: Matt Bordenet | Version: 1.0                   │
# │     Platform: macOS only                                   │
# └────────────────────────────────────────────────────────────┘

MANIFEST_FILE="brew-manifest.txt"

show_help() {
  echo "Usage: ./clone-brew.sh [--export | --import | --help]"
  echo ""
  echo "Options:"
  echo "  --export     Save installed brew packages and casks to $MANIFEST_FILE"
  echo "  --import     Install brew packages and casks from $MANIFEST_FILE"
  echo "  --help       Show this help message"
  exit 0
}

export_manifest() {
  echo "📤 Exporting Homebrew packages and casks to $MANIFEST_FILE..."
  {
    echo "# brew packages"
    brew list --formula
    echo ""
    echo "# brew casks"
    brew list --cask
  } > "$MANIFEST_FILE"
  echo "✅ Export complete."
}

import_manifest() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    echo "❌ Manifest file '$MANIFEST_FILE' not found."
    exit 1
  fi

  echo "📥 Importing Homebrew packages and casks from $MANIFEST_FILE..."

  # Read and install formulas
  awk '/^# brew packages/{flag=1; next} /^# brew casks/{flag=0} flag && NF' "$MANIFEST_FILE" | while read -r formula; do
    echo "🔧 Installing formula: $formula"
    brew install "$formula"
  done

  # Read and install casks
  awk '/^# brew casks/{flag=1; next} flag && NF' "$MANIFEST_FILE" | while read -r cask; do
    echo "📦 Installing cask: $cask"
    brew install --cask "$cask"
  done

  echo "✅ Import complete."
}

# Entry point
case "$1" in
  --export) export_manifest ;;
  --import) import_manifest ;;
  --help|-h|"") show_help ;;
  *) echo "❌ Unknown option: $1"; show_help ;;
esac
