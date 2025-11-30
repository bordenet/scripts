#!/usr/bin/env bash

set -euo pipefail

[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

# ┌────────────────────────────────────────────────────────────┐
# │                  Homebrew Environment Cloner               │
# │     Export and import brew packages + casks for macOS      │
# │     Author: Matt Bordenet | Version: 1.0                   │
# │     Platform: macOS only                                   │
# └────────────────────────────────────────────────────────────┘

# Argument defaults
MANIFEST_FILE="brew-manifest.txt"
VERBOSE=false

# --- Logging Function ---
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

show_help() {
  echo "Usage: ./clone-brew.sh [--export | --import | --help] [--verbose]"
  echo ""
  echo "Options:"
  echo "  --export     Save installed brew packages and casks to $MANIFEST_FILE"
  echo "  --import     Install brew packages and casks from $MANIFEST_FILE"
  echo "  --verbose    Enable verbose output showing detailed execution steps"
  echo "  --help       Show this help message"
  exit 0
}

export_manifest() {
  echo "📤 Exporting Homebrew packages and casks to $MANIFEST_FILE..."
  log_verbose "Collecting list of installed formulas"
  log_verbose "Running: brew list --formula"
  {
    echo "# brew packages"
    brew list --formula
    echo ""
    echo "# brew casks"
    log_verbose "Collecting list of installed casks" >&2
    log_verbose "Running: brew list --cask" >&2
    brew list --cask
  } > "$MANIFEST_FILE"
  log_verbose "Manifest file written to $MANIFEST_FILE"
  echo "✅ Export complete."
}

import_manifest() {
  if [ ! -f "$MANIFEST_FILE" ]; then
    echo "❌ Manifest file '$MANIFEST_FILE' not found."
    exit 1
  fi

  echo "📥 Importing Homebrew packages and casks from $MANIFEST_FILE..."
  log_verbose "Reading manifest file: $MANIFEST_FILE"

  # Read and install formulas
  log_verbose "Parsing formulas from manifest"
  awk '/^# brew packages/{flag=1; next} /^# brew casks/{flag=0} flag && NF' "$MANIFEST_FILE" | while read -r formula; do
    echo "🔧 Installing formula: $formula"
    log_verbose "Running: brew install $formula"
    brew install "$formula"
  done

  # Read and install casks
  log_verbose "Parsing casks from manifest"
  awk '/^# brew casks/{flag=1; next} flag && NF' "$MANIFEST_FILE" | while read -r cask; do
    echo "📦 Installing cask: $cask"
    log_verbose "Running: brew install --cask $cask"
    brew install --cask "$cask"
  done

  echo "✅ Import complete."
}

# Entry point - parse all arguments
ACTION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --export)
      ACTION="export"
      shift
      ;;
    --import)
      ACTION="import"
      shift
      ;;
    --verbose|-v)
      VERBOSE=true
      shift
      ;;
    --help|-h|"")
      show_help
      ;;
    *)
      echo "❌ Unknown option: $1"
      show_help
      ;;
  esac
done

# Execute the action
case "$ACTION" in
  export) export_manifest ;;
  import) import_manifest ;;
  "") show_help ;;
esac
