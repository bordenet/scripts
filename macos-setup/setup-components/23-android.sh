#!/usr/bin/env bash
################################################################################
# Component: Android Development Environment
################################################################################
# PURPOSE: Install and configure Android Studio, SDK, and command-line tools
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew, 21-java (REQUIRED)
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component requires Java to be installed first
# - Installs Android Studio and SDK command-line tools
# - Configures ANDROID_HOME and PATH
# - Accepts Android SDK licenses automatically
################################################################################

# Component metadata

set -euo pipefail

COMPONENT_NAME="Android development environment"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    android_setup_needed=false
    if [ ! -d "/Applications/Android Studio.app" ] || ! command -v sdkmanager &> /dev/null; then
      android_setup_needed=true
    fi

    if [ "$android_setup_needed" = true ]; then
      if timed_confirm "Set up Android development environment?"; then
      print_info "Setting up Android development..."

      # CRITICAL: Verify Java is available before proceeding with Android SDK
      if ! java -version &> /dev/null; then
        print_error "Java is required for Android development but is not available"
        print_error "This is a critical setup error - Java should have been installed earlier"
        die "Java installation failed - cannot proceed with Android setup"
      fi

      # Install Android Studio
      if [ ! -d "/Applications/Android Studio.app" ]; then
        if timed_confirm "Install Android Studio? (Large download ~2GB)"; then
          check_installing "Android Studio"
          brew install --cask android-studio > /dev/null 2>&1
          check_done "Android Studio"
        else
          print_warning "Skipping Android Studio installation. You can install it manually later."
        fi
      else
        check_exists "Android Studio"
      fi

      # Install Android SDK command-line tools
      if ! command -v sdkmanager &> /dev/null; then
        if timed_confirm "Install Android SDK command-line tools?"; then
          check_installing "Android SDK tools"
          brew install --cask android-commandlinetools > /dev/null 2>&1
          check_done "Android SDK tools"
        else
          print_warning "Skipping Android SDK installation. Android development will not be available."
        fi
      else
        check_exists "Android SDK tools"
      fi

      # Set up Android SDK environment variables
      ANDROID_HOME="$HOME/Library/Android/sdk"
      export ANDROID_HOME
      export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

      # Add to shell profile
      SHELL_PROFILE=""
      if [ -n "$ZSH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
      elif [ -n "$BASH_VERSION" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
      fi

      if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
        if ! grep -q "ANDROID_HOME" "$SHELL_PROFILE"; then
          cat >> "$SHELL_PROFILE" <<'EOF'

# Android Development
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH
EOF
          print_success "Added Android environment variables to $SHELL_PROFILE"
        fi
      fi

      # Install platform-tools and a system image
      if command -v sdkmanager &> /dev/null; then
        check_installing "Android platform-tools"
        timeout 300 sdkmanager "platform-tools" "system-images;android-33;google_apis;x86_64" > /dev/null 2>&1 || true
        check_done "Android platform-tools"
      fi

      # Install Android command-line tools and accept licenses
      if command -v sdkmanager &> /dev/null; then
        timeout 30 sdkmanager "cmdline-tools;latest" > /dev/null 2>&1 || true

        print_info "Accepting Android SDK licenses..."
        yes | flutter doctor --android-licenses > /dev/null 2>&1 || print_warning "Failed to accept Android licenses. Run 'flutter doctor --android-licenses' manually."
      fi

      print_success "Android development configured"
      print_warning "MANUAL STEP: Complete Android Studio setup if needed"
      print_info "1. Open Android Studio (first launch will complete SDK setup)"
      print_info "2. Follow setup wizard if prompted"
      print_info "3. Install additional SDK components as needed"
      else
        print_warning "Skipping Android setup - Android development will not be available"
      fi
    else
      check_exists "Android development"

      # Update Android SDK components (default YES)
      if command -v sdkmanager &> /dev/null; then
        # CRITICAL: Verify Java is available before running SDK operations
        if ! java -version &> /dev/null; then
          print_warning "Java is not available - skipping Android SDK updates"
        else
          # Set up environment for sdkmanager
          ANDROID_HOME="$HOME/Library/Android/sdk"
          export ANDROID_HOME
          export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

        # Fix cmdline-tools path inconsistency BEFORE prompting (Android Studio upgrade issue)
        CMDLINE_DIR="$ANDROID_HOME/cmdline-tools"
        if [ -d "$CMDLINE_DIR" ]; then
          # Find the actual latest version directory (latest-2, latest-3, etc.)
          LATEST_VERSION=$(find "$CMDLINE_DIR" -maxdepth 1 -type d \( -name "latest-*" -o -name "[0-9]*" \) | sort -V | tail -1)

          if [ -n "$LATEST_VERSION" ]; then
            EXPECTED_TARGET=$(basename "$LATEST_VERSION")

            # Check if 'latest' exists and what it is
            if [ -L "$CMDLINE_DIR/latest" ]; then
              # It's a symlink - verify it points to the right place
              CURRENT_TARGET=$(readlink "$CMDLINE_DIR/latest")
              if [ "$CURRENT_TARGET" != "$EXPECTED_TARGET" ]; then
                print_info "Updating cmdline-tools symlink: $CURRENT_TARGET -> $EXPECTED_TARGET"
                rm "$CMDLINE_DIR/latest"
                ln -s "$EXPECTED_TARGET" "$CMDLINE_DIR/latest"
                print_success "Command-line tools symlink updated"
              fi
            elif [ -d "$CMDLINE_DIR/latest" ]; then
              # It's a directory (Android Studio bug) - replace with symlink
              print_info "Replacing cmdline-tools directory with symlink: latest -> $EXPECTED_TARGET"
              rm -rf "$CMDLINE_DIR/latest"
              ln -s "$EXPECTED_TARGET" "$CMDLINE_DIR/latest"
              print_success "Command-line tools path fixed"
            elif [ ! -e "$CMDLINE_DIR/latest" ]; then
              # Doesn't exist - create symlink
              print_info "Creating cmdline-tools symlink: latest -> $EXPECTED_TARGET"
              ln -s "$EXPECTED_TARGET" "$CMDLINE_DIR/latest"
              print_success "Command-line tools symlink created"
            fi
          fi
        fi

          # Automatically update SDK components
          print_info "Updating Android SDK components..."

          # Update SDK manager itself
          UPDATE_OUTPUT=$(timeout 120 sdkmanager --update 2>&1 || true)
          if echo "$UPDATE_OUTPUT" | grep -q "Update available"; then
            print_info "Applying SDK updates..."
          fi

          # Update platform-tools, build-tools, and latest platform
          yes | sdkmanager "platform-tools" "build-tools;34.0.0" "platforms;android-34" > /dev/null 2>&1 || true

          # Update emulator
          timeout 120 sdkmanager "emulator" > /dev/null 2>&1 || true

          # Check if updates were applied
          if echo "$UPDATE_OUTPUT" | grep -q "No updates available"; then
            print_info "No SDK updates available"
          else
            print_success "Android SDK components updated"
          fi
        fi
      fi
    fi

    section_end
}
