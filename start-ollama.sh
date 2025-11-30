#!/usr/bin/env bash

set -euo pipefail

[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

# ┌───────────────────────────────────────────────┐
# │         Ollama LAN Server Bootstrap          │
# │     Auto-detects LAN IP and starts Ollama     │
# │     Author: Matt Bordenet | macOS only        │
# │     Platform: macOS only                      │
# └───────────────────────────────────────────────┘

# Argument defaults
VERBOSE=false

# --- Logging Function ---
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[VERBOSE] $*" >&2
    fi
}

# Show help message
show_help() {
  echo "Usage: ./start-ollama.sh [--help] [--verbose]"
  echo ""
  echo "This script detects your Mac's LAN IP address and starts Ollama bound to that IP."
  echo "It kills any existing Ollama process on port 11434 before launching."
  echo ""
  echo "Options:"
  echo "  --help, -h     Show this help message"
  echo "  --verbose, -v  Enable verbose output showing detailed execution steps"
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Run with --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Detect LAN IP (Wi-Fi or Ethernet)
log_verbose "Attempting to detect LAN IP from en0 (Wi-Fi)"
LAN_IP=$(ipconfig getifaddr en0)
if [ -z "$LAN_IP" ]; then
  log_verbose "en0 not available, trying en1 (Ethernet)"
  LAN_IP=$(ipconfig getifaddr en1)
fi

# Sanity check
if [ -z "$LAN_IP" ]; then
  echo "❌ Could not determine LAN IP address. Is your network interface up?"
  exit 1
fi

echo "📡 Detected LAN IP: $LAN_IP"
log_verbose "Using LAN IP: $LAN_IP"

# Kill existing Ollama process on port 11434
log_verbose "Checking for existing Ollama process on port 11434"
PID=$(lsof -iTCP:11434 -sTCP:LISTEN -t)
if [ -n "$PID" ]; then
  echo "🛑 Killing existing Ollama process (PID $PID)"
  log_verbose "Running: kill -9 $PID"
  kill -9 "$PID" || true
else
  log_verbose "No existing Ollama process found on port 11434"
fi

# Start Ollama bound to LAN IP
echo "🚀 Starting Ollama with OLLAMA_HOST=$LAN_IP"
log_verbose "Running: OLLAMA_HOST=$LAN_IP ollama serve"
OLLAMA_HOST="$LAN_IP" ollama serve
