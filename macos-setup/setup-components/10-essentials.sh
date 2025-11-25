#!/usr/bin/env bash
################################################################################
# Component: Essential Development Tools
################################################################################
# PURPOSE: Install essential development tools like Node, Go, and Xcode CLI.
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable.
# - It installs a common set of development tools.
# - You can comment out or remove installations you don't need.
################################################################################

# Component metadata

set -euo pipefail

COMPONENT_NAME="Essential development tools"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Install Node.js and npm
    if ! command -v node &> /dev/null; then
      check_installing "Node.js"
      brew install node > /dev/null 2>&1
      if ! command -v node &> /dev/null; then
        print_error "Node.js installation failed. Please install Node.js manually."
        die "Setup failed"
      fi
      check_done "Node.js"
    else
      check_exists "Node.js ($(node --version))"
    fi

    # Install TypeScript globally
    if ! command -v tsc &> /dev/null; then
      check_installing "TypeScript"
      timeout 180 npm install -g typescript > /dev/null 2>&1
      if ! command -v tsc &> /dev/null; then
        print_error "TypeScript installation failed. Please install TypeScript manually."
        die "Setup failed"
      fi
      check_done "TypeScript"
    else
      check_exists "TypeScript ($(tsc --version))"
    fi

    # Install AWS CDK globally
    if ! command -v cdk &> /dev/null; then
      check_installing "AWS CDK"
      timeout 180 npm install -g aws-cdk@2.87.0 > /dev/null 2>&1
      if ! command -v cdk &> /dev/null; then
        print_error "AWS CDK installation failed. Please install AWS CDK manually."
        die "Setup failed"
      fi
      check_done "AWS CDK"
    else
      check_exists "AWS CDK ($(cdk --version))"
    fi

    # Install Go
    if ! command -v go &> /dev/null; then
      check_installing "Go"
      brew install go > /dev/null 2>&1
      if ! command -v go &> /dev/null; then
        print_error "Go installation failed. Please install Go manually."
        die "Setup failed"
      fi
      check_done "Go"
    else
      check_exists "Go ($(go version | awk '{print $3}'))"
    fi

    # Install golangci-lint (Go linter)
    if ! command -v golangci-lint &> /dev/null; then
      check_installing "golangci-lint"
      brew install golangci-lint > /dev/null 2>&1
      if ! command -v golangci-lint &> /dev/null; then
        print_error "golangci-lint installation failed. Please install manually."
        die "Setup failed"
      fi
      check_done "golangci-lint"
    else
      check_exists "golangci-lint ($(golangci-lint --version | head -1 | awk '{print $4}'))"
    fi

    # Install Xcode CLI tools (required for iOS/Swift development)
    if ! xcode-select -p &> /dev/null; then
      if timed_confirm "Xcode CLI tools are required for iOS development. Install? (Large download ~500MB)"; then
        print_info "Installing Xcode CLI tools (follow on-screen prompts)..."
        xcode-select --install
        max_wait=300 # 5 minutes
        wait_interval=10
        waited=0
        while [ $waited -lt $max_wait ]; do
          if xcode-select -p &> /dev/null; then
            print_success "Xcode CLI tools installed"
            break
          fi
          sleep $wait_interval
          waited=$((waited + wait_interval))
        done
        if ! xcode-select -p &> /dev/null; then
          print_error "Xcode CLI tools installation timed out. Please complete the installation and run this script again."
          die "Setup failed"
        fi
      else
        print_warning "Skipping Xcode CLI tools - iOS development will not be available"
      fi
    else
      check_exists "Xcode CLI tools"
    fi

    section_end
}
