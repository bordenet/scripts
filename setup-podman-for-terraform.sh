#!/bin/bash
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
#!/bin/bash

echo "🔧 Checking for Homebrew..."
if ! command -v brew >/dev/null 2>&1; then
  echo "❌ Homebrew not found. Please install it from https://brew.sh"
  exit 1
fi

echo "📦 Checking for Podman..."
if ! command -v podman >/dev/null 2>&1; then
  echo "📥 Installing Podman via Homebrew..."
  brew install podman
else
  echo "✅ Podman is already installed."
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

echo "🌐 Setting DOCKER_HOST to: $SOCKET"
export DOCKER_HOST=$SOCKET

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
