#!/usr/bin/env bash

set -euo pipefail

[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }

# ┌───────────────────────────────────────────────┐
# │         Ollama LAN Server Bootstrap          │
# │     Auto-detects LAN IP and starts Ollama     │
# │     Author: Matt Bordenet | macOS only        │
# │     Platform: macOS only                      │
# └───────────────────────────────────────────────┘

# Show help message
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
  echo "Usage: ./start-ollama.sh [--help]"
  echo ""
  echo "This script detects your Mac's LAN IP address and starts Ollama bound to that IP."
  echo "It kills any existing Ollama process on port 11434 before launching."
  echo ""
  echo "Options:"
  echo "  --help, -h     Show this help message"
  exit 0
fi

# Detect LAN IP (Wi-Fi or Ethernet)
LAN_IP=$(ipconfig getifaddr en0)
if [ -z "$LAN_IP" ]; then
  LAN_IP=$(ipconfig getifaddr en1)
fi

# Sanity check
if [ -z "$LAN_IP" ]; then
  echo "❌ Could not determine LAN IP address. Is your network interface up?"
  exit 1
fi

echo "📡 Detected LAN IP: $LAN_IP"

# Kill existing Ollama process on port 11434
PID=$(lsof -iTCP:11434 -sTCP:LISTEN -t)
if [ -n "$PID" ]; then
  echo "🛑 Killing existing Ollama process (PID $PID)"
  kill -9 "$PID" || true
fi

# Start Ollama bound to LAN IP
echo "🚀 Starting Ollama with OLLAMA_HOST=$LAN_IP"
OLLAMA_HOST="$LAN_IP" ollama serve
