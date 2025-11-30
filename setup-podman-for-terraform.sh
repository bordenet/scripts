#!/usr/bin/env bash

set -euo pipefail

[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }
#
# Script: setup-podman-for-terraform.sh
# Description: This script automates the setup and configuration of Podman
#              to be used as a Docker-compatible environment for Terraform.
#              It installs Podman (if necessary), initializes and starts the
#              Podman virtual machine, and sets the DOCKER_HOST environment
#              variable to enable Terraform's Docker provider to connect to Podman.
# Platform: macOS only
# Usage: ./setup-podman-for-terraform.sh
# Dependencies: Homebrew (macOS), Podman, Terraform (for usage context)
#

# --- Help Function ---
show_help() {
    cat << EOF
NAME
    setup-podman-for-terraform.sh - Configure Podman as Docker alternative for Terraform

SYNOPSIS
    setup-podman-for-terraform.sh [OPTIONS]

DESCRIPTION
    Automates the setup and configuration of Podman to be used as a Docker-compatible
    environment for Terraform. Installs Podman (if necessary), initializes and starts
    the Podman virtual machine, and sets the DOCKER_HOST environment variable.

OPTIONS
    -h, --help
        Display this help message and exit.

    --what-if
        Show what would be done without making any changes (dry-run mode).

    -v, --verbose
        Enable verbose logging.

PLATFORM
    macOS only - Script will exit with error on other platforms

DEPENDENCIES
    • Homebrew - Package manager
    • Podman - Docker alternative
    • Terraform - For usage context

EXAMPLES
    # Setup Podman for Terraform
    ./setup-podman-for-terraform.sh

    # Preview what would be done (dry-run)
    ./setup-podman-for-terraform.sh --what-if

NOTES
    Sets DOCKER_HOST environment variable to enable Terraform's Docker provider
    to connect to Podman.

SEE ALSO
    podman(1), terraform(1), brew(1)

EOF
    exit 0
}

# Parse arguments
WHAT_IF=false
VERBOSE=false

log_verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        --what-if)
            WHAT_IF=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            break
            ;;
    esac
done

if $WHAT_IF; then
  echo "🔍 WHAT-IF MODE: Showing what would be done"
  echo ""
fi

log_verbose "Starting setup-podman-for-terraform.sh"
log_verbose "What-if mode: $WHAT_IF"

echo "🔧 Checking for Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "❌ Homebrew not found. Please install it from https://brew.sh"
  exit 1
fi
log_verbose "Homebrew found at: $(command -v brew)"

echo "📦 Checking for Podman..."
if ! command -v podman >/dev/null 2>&1; then
  log_verbose "Podman not found, needs installation"
  if $WHAT_IF; then
    echo "[WHAT-IF] Would install Podman via Homebrew"
  else
    echo "📥 Installing Podman via Homebrew..."
    brew install podman
  fi
else
  echo "✅ Podman is already installed."
  log_verbose "Podman found at: $(command -v podman)"
  log_verbose "Podman version: $(podman --version)"
fi

if $WHAT_IF; then
  echo "[WHAT-IF] Would initialize Podman VM"
  echo "[WHAT-IF] Would start Podman VM"
  echo "[WHAT-IF] Would verify Podman connection"
  echo "[WHAT-IF] Would set DOCKER_HOST environment variable"
  echo ""
  echo "✅ WHAT-IF complete. No changes made."
  exit 0
fi

echo "🧰 Initializing Podman VM..."
podman machine init >/dev/null 2>&1

echo "🚀 Starting Podman VM..."
podman machine start

echo "⏳ Waiting for Podman to boot..."
sleep 3

echo "🔍 Verifying Podman connection..."
if ! podman info >/dev/null 2>&1; then
  echo "❌ Podman VM failed to start or connect. Check your setup."
  exit 1
fi

echo "🔗 Getting Docker-compatible socket..."
SOCKET=$(podman system connection list | grep -E '^podman-machine-default' | awk '{print $2}')

if [ -z "$SOCKET" ]; then
  echo "❌ Could not find Docker-compatible socket."
  exit 1
fi
log_verbose "Found Podman socket: $SOCKET"

echo "🌐 Setting DOCKER_HOST to: $SOCKET"
export DOCKER_HOST=$SOCKET
log_verbose "DOCKER_HOST environment variable set"

echo ""
echo "✅ Podman is ready for Terraform!"
echo ""
echo "📄 Use this in your Terraform config:"
echo 'provider "docker" {'
echo "  host = \"$SOCKET\""
echo '}'
echo ""
echo "💡 To make DOCKER_HOST persistent, add this to your shell profile:"
echo "export DOCKER_HOST=$SOCKET"
