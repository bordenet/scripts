#!/usr/bin/env bash
################################################################################
# Component: Environment File Management
################################################################################
# PURPOSE: Set up .env file from template and load environment variables.
# REUSABLE: YES
# DEPENDENCIES: none
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable for any project using .env files.
# - It handles creating .env from .env.example template if missing.
# - It loads environment variables using load-env.sh script.
# - Adapt the warning messages to your project's specific needs.
################################################################################

# Component metadata

set -euo pipefail

COMPONENT_NAME="Environment configuration"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    if [ ! -f ".env" ]; then
      if [ -f ".env.example" ]; then
        print_info "Creating .env file from .env.example..."
        cp .env.example .env
        print_success ".env file created from template."
        print_warning "IMPORTANT: Edit .env and configure your AWS credentials and other settings"
      else
        print_warning ".env file not found and no .env.example template available"
        print_info "The .env file is optional for basic setup but required for:"
        print_info "  - AWS deployment and testing"
        print_info "  - Multi-tenant testing"
        print_info "  - Production deployments"
        print_info "You can create one later by copying .env.example"
      fi
    fi

    # Try to load environment variables if .env exists
    if [ -f ".env" ]; then
      if [ "$VERBOSE" = true ]; then
        # Verbose mode: show all output from load-env.sh
        if source "$REPO_ROOT/scripts/load-env.sh"; then
          : # Success message already printed by load-env.sh
        else
          print_warning "Failed to load .env file - some features may not work"
          print_info "Edit .env to fix any syntax errors or missing required variables"
        fi
      else
        # Compact mode: suppress output from load-env.sh
        section_update "Loading .env"
        if source "$REPO_ROOT/scripts/load-env.sh" >/dev/null 2>&1; then
          section_update ".env loaded ✓"
        else
          section_update "Failed to load .env"
          section_fail ".env"
        fi
      fi
    else
      print_info "Skipping .env load (file not present) - basic development will work"
    fi

    section_end
}
