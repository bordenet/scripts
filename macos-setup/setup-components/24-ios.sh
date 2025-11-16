#!/usr/bin/env bash
################################################################################
# Component: iOS Development Environment
################################################################################
# PURPOSE: Install and configure iOS development tools (Ruby, CocoaPods, SwiftLint)
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew, Xcode (manual install from App Store)
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component requires Xcode to be installed manually from the App Store
# - Installs modern Ruby via Homebrew (required for CocoaPods)
# - Installs CocoaPods for dependency management
# - Installs SwiftLint for code quality
################################################################################

# Component metadata
COMPONENT_NAME="iOS development environment"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    ios_setup_needed=false
    if [ ! -d "/Applications/Xcode.app" ] || ! command -v pod &> /dev/null; then
      ios_setup_needed=true
    fi

    if [ "$ios_setup_needed" = true ]; then
      if timed_confirm "Set up iOS development environment?"; then
      # Check if Xcode is installed
      if [ ! -d "/Applications/Xcode.app" ]; then
        print_warning "Xcode not found. Install from App Store and run script again."
      else
        check_exists "Xcode"

        # Install modern Ruby (required for CocoaPods)
        if ! brew list ruby &> /dev/null; then
          if timed_confirm "Install modern Ruby for CocoaPods?"; then
            check_installing "Ruby"
            brew install ruby > /dev/null 2>&1

            # Add Homebrew Ruby to PATH
            RUBY_PATH="/opt/homebrew/opt/ruby/bin"
            export PATH="$RUBY_PATH:$PATH"

            # Add to shell profile
            SHELL_PROFILE=""
            if [ -n "$ZSH_VERSION" ]; then
              SHELL_PROFILE="$HOME/.zshrc"
            elif [ -n "$BASH_VERSION" ]; then
              SHELL_PROFILE="$HOME/.bash_profile"
            fi

            if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
              if ! grep -q "export PATH=\"$RUBY_PATH:\$PATH\"" "$SHELL_PROFILE"; then
                echo "export PATH=\"$RUBY_PATH:\$PATH\"" >> "$SHELL_PROFILE"
              fi
            fi

            check_done "Ruby"
          else
            print_warning "Skipping Ruby installation. CocoaPods installation may fail."
          fi
        else
          check_exists "Ruby"
          export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
        fi

        # Install CocoaPods with modern Ruby
        if ! /opt/homebrew/opt/ruby/bin/gem list cocoapods | grep -q cocoapods; then
          if timed_confirm "Install CocoaPods for iOS development?"; then
            check_installing "CocoaPods"
            sudo gem install cocoapods > /dev/null 2>&1 || true
            /opt/homebrew/opt/ruby/bin/gem install cocoapods > /dev/null 2>&1 || true
            check_done "CocoaPods"

            # Add Ruby gems bin to PATH (where pod executable is installed)
            RUBY_GEMS_BIN="/opt/homebrew/lib/ruby/gems/3.4.0/bin"
            export PATH="$RUBY_GEMS_BIN:$PATH"

            # Add to shell profile for persistence
            SHELL_PROFILE=""
            if [ -n "$ZSH_VERSION" ]; then
              SHELL_PROFILE="$HOME/.zshrc"
            elif [ -n "$BASH_VERSION" ]; then
              SHELL_PROFILE="$HOME/.bash_profile"
            fi

            if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
              if ! grep -q "export PATH=\"$RUBY_GEMS_BIN:\$PATH\"" "$SHELL_PROFILE"; then
                echo "export PATH=\"$RUBY_GEMS_BIN:\$PATH\"" >> "$SHELL_PROFILE"
              fi
            fi

            # Verify 'pod' command is now available
            if ! command -v pod &> /dev/null; then
                print_error "CocoaPods installed but 'pod' command not found in PATH. Please restart your terminal."
                die "Setup failed"
            fi
          else
            brew install cocoapods > /dev/null 2>&1 || true
            print_warning "Skipping CocoaPods installation."
          fi
        else
          check_exists "CocoaPods"
          # Ensure gems bin is in PATH even if CocoaPods already installed
          RUBY_GEMS_BIN="/opt/homebrew/lib/ruby/gems/3.4.0/bin"
          export PATH="$RUBY_GEMS_BIN:$PATH"
        fi

        # Install SwiftLint for code quality
        if ! command -v swiftlint &> /dev/null; then
          if timed_confirm "Install SwiftLint for Swift code quality checks?"; then
            check_installing "SwiftLint"
            brew install swiftlint > /dev/null 2>&1
            check_done "SwiftLint"
          else
            print_warning "Skipping SwiftLint installation."
          fi
        else
          check_exists "SwiftLint"
        fi

        print_success "iOS development configured"
        print_warning "MANUAL: Configure Apple Developer account in Xcode (Preferences > Accounts)"
      fi
      fi
    fi

    section_end
}
