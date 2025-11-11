#!/bin/bash
[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }
# -----------------------------------------------------------------------------
#
# Script Name: bu.sh
#
# Description: This script performs a comprehensive system update and cleanup
#              for a macOS environment. It updates Homebrew, npm, mas (Mac App
#              Store), and pip. It also cleans up Homebrew installations and
#              triggers a macOS software update.
#
# Platform:    macOS only
#
# Usage: ./bu.sh
#
# Dependencies:
#   - Homebrew: For managing packages.
#   - npm: For managing Node.js packages.
#   - mas: For managing Mac App Store applications.
#   - pip: For managing Python packages.
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# Start timer
start_time=$(date +%s)

# --- Initial Setup ---
echo "Starting the system update and cleanup process..."
# Request sudo privileges upfront to avoid prompts later.
sudo -v
clear

# --- Homebrew Updates ---
echo "Updating Homebrew..."
brew update
echo "Upgrading Homebrew packages..."
brew upgrade
echo "Cleaning up old Homebrew package versions..."
brew cleanup -s
echo "Upgrading Homebrew Casks..."
brew upgrade --cask
echo "Removing the homebrew/cask tap (no longer necessary)..."
brew untap homebrew/cas || true

echo "Running Homebrew Doctor to check for issues..."
brew doctor
echo "Checking for missing Homebrew dependencies..."
brew missing

# --- npm Updates ---
echo "Updating global npm packages..."
npm update -g --force
echo "Updating npm itself..."
npm install -g npm --force || true

# --- Mac App Store Updates (mas) ---
echo "Checking for Mac App Store updates..."
if ! command -v mas &> /dev/null; then
    echo "mas command not found. Installing..."
    brew install mas
fi
mas outdated
echo "Upgrading all outdated Mac App Store apps..."
mas upgrade

# --- Pip Updates ---
echo "Upgrading pip for Python 2..."
pip install --upgrade pip || true

echo "Upgrading pip for Python 3..."
#pip3 install --upgrade pip
python3 -m pip install --upgrade pip --user || true

# --- macOS Software Update ---
echo "Checking for and installing macOS software updates..."
sudo softwareupdate --all --install --force -R

# --- Completion ---
echo "System update and cleanup process completed."

# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo "Total execution time: ${execution_time} seconds"
