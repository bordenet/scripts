#!/usr/bin/env bash
################################################################################
# Component: Flutter SDK
################################################################################
# PURPOSE: Install and configure Flutter SDK for mobile development
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew, 21-java (optional, for Android)
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component installs Flutter via Homebrew
# - Configures Flutter to use Android SDK if available
# - Adds Flutter to PATH
################################################################################

# Component metadata
COMPONENT_NAME="Flutter SDK"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    if ! command -v flutter &> /dev/null; then
      if timed_confirm "Flutter SDK is required for mobile app development. Install? (Large download ~1GB)"; then
        check_installing "Flutter SDK"
        brew install flutter > /dev/null 2>&1

        # Add Flutter to PATH (prioritize Flutter's Dart over Homebrew's)
        FLUTTER_PATH="/opt/homebrew/share/flutter/bin"
        export PATH="$FLUTTER_PATH:$PATH"

        # Configure Flutter to use correct Android SDK
        flutter config --android-sdk "${ANDROID_HOME:-$HOME/Library/Android/sdk}" > /dev/null 2>&1 || true

        # Add to shell profile
        SHELL_PROFILE=""
        if [ -n "${ZSH_VERSION:-}" ]; then
          SHELL_PROFILE="$HOME/.zshrc"
        elif [ -n "${BASH_VERSION:-}" ]; then
          SHELL_PROFILE="$HOME/.bash_profile"
        fi

        if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
          if ! grep -q "export PATH=\"/opt/homebrew/share/flutter/bin:\$PATH\"" "$SHELL_PROFILE"; then
            echo "export PATH=\"/opt/homebrew/share/flutter/bin:\$PATH\"" >> "$SHELL_PROFILE"
          fi
        fi

        check_done "Flutter SDK"
      else
        print_warning "Skipping Flutter - mobile development will not be available"
      fi
    else
      # Get Flutter version quietly by suppressing verbose output
      FLUTTER_VERSION=$(flutter --version 2>&1 | grep "Flutter" | head -1 | awk '{print $2}' || echo "")
      if [ -n "$FLUTTER_VERSION" ]; then
        check_exists "Flutter ($FLUTTER_VERSION)"
      else
        check_exists "Flutter"
      fi

      # Ensure Flutter is configured correctly even if already installed
      FLUTTER_PATH="/opt/homebrew/share/flutter/bin"
      export PATH="$FLUTTER_PATH:$PATH"

      # Set ANDROID_HOME if it exists
      ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
      if [ -d "$ANDROID_HOME" ]; then
        export ANDROID_HOME
        flutter config --android-sdk "$ANDROID_HOME" > /dev/null 2>&1 || true
      fi
    fi

    section_end
}
