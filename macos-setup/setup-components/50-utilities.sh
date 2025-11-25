#!/usr/bin/env bash
################################################################################
# Component: Additional Utilities
################################################################################
# PURPOSE: Install and configure common command-line utilities.
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is fully reusable - copy as-is.
# - All tools installed are universally useful for development.
# - No changes are needed when copying to a new repo.
################################################################################

# Component metadata

set -euo pipefail

COMPONENT_NAME="Additional utilities"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # jq for JSON processing
    if ! command -v jq &> /dev/null; then
      check_installing "jq"
      brew install jq > /dev/null 2>&1
      check_done "jq"
    else
      check_exists "jq"
    fi

    # coreutils for timeout command (needed for multi-tenant tests)
    if ! command -v gtimeout &> /dev/null; then
      check_installing "coreutils"
      brew install coreutils > /dev/null 2>&1
      check_done "coreutils"
    else
      check_exists "coreutils"
    fi

    # curl and wget (usually pre-installed but ensure availability)
    if ! command -v curl &> /dev/null; then
      check_installing "curl"
      brew install curl > /dev/null 2>&1
      check_done "curl"
    fi

    if ! command -v wget &> /dev/null; then
      check_installing "wget"
      brew install wget > /dev/null 2>&1
      check_done "wget"
    fi

    # Tree for directory visualization
    if ! command -v tree &> /dev/null; then
      check_installing "tree"
      brew install tree > /dev/null 2>&1
      check_done "tree"
    fi

    # Git repository tools for large file management and history cleanup
    if ! command -v bfg &> /dev/null; then
      check_installing "BFG Repo-Cleaner"
      brew install bfg > /dev/null 2>&1
      check_done "BFG Repo-Cleaner"
    else
      check_exists "BFG Repo-Cleaner"
    fi

    if ! command -v git-lfs &> /dev/null; then
      check_installing "Git LFS"
      brew install git-lfs > /dev/null 2>&1
      git lfs install --system 2>/dev/null || git lfs install 2>/dev/null || true
      check_done "Git LFS"
    else
      check_exists "Git LFS"
    fi

    if ! command -v git-filter-repo &> /dev/null; then
      check_installing "git-filter-repo"
      brew install git-filter-repo > /dev/null 2>&1
      check_done "git-filter-repo"
    else
      check_exists "git-filter-repo"
    fi

    section_end
}
