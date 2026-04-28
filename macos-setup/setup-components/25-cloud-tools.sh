#!/usr/bin/env bash
################################################################################
# Component: Cloud Development Tools
################################################################################
# PURPOSE: Install cloud provider CLIs (AWS, etc.)
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - Add/remove cloud providers as needed for your project
# - Currently includes: AWS CLI
# - Extend with: gcloud, azure-cli, terraform, etc.
################################################################################

# Component metadata

set -euo pipefail

COMPONENT_NAME="Cloud development tools"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # AWS CLI
    if ! aws --version &> /dev/null; then
      check_installing "AWS CLI"
      brew reinstall awscli > /dev/null 2>&1
      if ! aws --version &> /dev/null; then
        print_error "AWS CLI reinstall failed. Please check your Homebrew and Python setup."
        die "Setup failed"
      fi
      check_done "AWS CLI"
    else
      check_exists "AWS CLI ($(aws --version | awk '{print $1}'))"
    fi

    section_end
}
