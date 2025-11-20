#!/usr/bin/env bash
################################################################################
# Component: Browser Automation and Testing Tools
################################################################################
# PURPOSE: Install and configure tools for browser automation and testing.
# REUSABLE: YES
# DEPENDENCIES: 10-essentials (for npm)
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable.
# - It installs Playwright browsers and Jest.
# - If you don't need browser automation, you can skip this component.
################################################################################

# Component metadata
COMPONENT_NAME="Browser automation and testing tools"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Check if Playwright browsers are already installed
    playwright_browsers_installed=false
    if [ -d "$HOME/Library/Caches/ms-playwright" ] && [ -n "$(ls -A "$HOME/Library/Caches/ms-playwright" 2>/dev/null)" ]; then
      playwright_browsers_installed=true
    fi

    if [ "$playwright_browsers_installed" = true ]; then
      check_exists "Playwright browsers"
    else
      if timed_confirm "Install Playwright browsers? (~500MB download)" 10 "N"; then
        check_installing "Playwright browsers"
        if npx playwright install > /dev/null 2>&1; then
          check_done "Playwright browsers"
        else
          check_failed "Playwright browsers"
        fi
      else
        print_warning "Skipping Playwright browsers."
      fi
    fi

    # Install Jest testing framework globally (for compatibility)
    if ! command -v jest &> /dev/null; then
      check_installing "Jest"
      npm install -g jest@^29.5.0 > /dev/null 2>&1
      check_done "Jest"
    else
      check_exists "Jest"
    fi

    section_end
}
