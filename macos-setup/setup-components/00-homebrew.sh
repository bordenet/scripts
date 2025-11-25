#!/usr/bin/env bash
################################################################################
# Component: Homebrew
################################################################################
# PURPOSE: Install the Homebrew package manager.
# REUSABLE: YES
# DEPENDENCIES: none
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is fully reusable - copy as-is.
# - It is a fundamental dependency for most other components.
################################################################################

# Component metadata

set -euo pipefail

COMPONENT_NAME="Package manager"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Install Homebrew if not present
    if ! command -v brew &> /dev/null; then
      if timed_confirm "Homebrew is required but not installed. Install Homebrew? (Large download ~100MB)"; then
        check_installing "Homebrew"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" > /dev/null 2>&1
        if ! command -v brew &> /dev/null; then
          print_error "Homebrew installation failed. Please install Homebrew manually."
          die "Setup failed"
        fi
        check_done "Homebrew"
      else
        print_error "Homebrew is required for this setup. Exiting."
        die "Setup failed"
      fi
    else
      check_exists "Homebrew"
    fi

    section_end
}
