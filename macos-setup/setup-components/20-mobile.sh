#!/usr/bin/env bash
################################################################################
# Component: Mobile Development Environment
################################################################################
# PURPOSE: Install and configure tools for mobile development (Flutter, Android, iOS).
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew, 10-essentials
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component is reusable, but you may want to remove parts you don't need.
# - If you don't need Flutter, you can remove the Flutter installation.
# - If you don't need Android, you can remove the Android Studio and SDK installation.
# - If you don't need iOS, you can remove the CocoaPods and SwiftLint installation.
################################################################################

# Component metadata
COMPONENT_NAME="Mobile development environment"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Java Development Kit (required for Android)
    # MUST be installed BEFORE any Android SDK operations
    # Check if Java is actually working, not just if the command exists (macOS has a stub)
    java_working=false
    # The macOS stub at /usr/bin/java returns 0 but outputs an error message
    # Real Java outputs version info without errors
    if java -version 2>&1 | grep -q "openjdk\|java version"; then
      java_working=true
    fi

    if [ "$java_working" = false ]; then
      # Check if Java is installed but just needs configuration
      if [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
        # Java is installed, just needs PATH configuration
        check_exists "Java (needs PATH configuration)"
        JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
        export JAVA_HOME
        export PATH="$JAVA_HOME/bin:$PATH"
      else
        # Actually install Java
        check_installing "Java Development Kit"
        brew install openjdk@17 > /dev/null 2>&1

        # Add Java to PATH
        JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
        export JAVA_HOME
        export PATH="$JAVA_HOME/bin:$PATH"
        check_done "Java Development Kit"
      fi

      # Add to shell profile
      SHELL_PROFILE=""
      if [ -n "${ZSH_VERSION:-}" ]; then
        SHELL_PROFILE="$HOME/.zshrc"
      elif [ -n "${BASH_VERSION:-}" ]; then
        SHELL_PROFILE="$HOME/.bash_profile"
      fi

      if [ -n "$SHELL_PROFILE" ] && [ -f "$SHELL_PROFILE" ]; then
        if ! grep -q "JAVA_HOME" "$SHELL_PROFILE"; then
          cat >> "$SHELL_PROFILE" <<EOF

# Java Development
export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
export PATH=$JAVA_HOME/bin:$PATH
EOF
        fi
      fi
    else
      check_exists "Java ($(java -version 2>&1 | head -1 | awk -F '"' '{print $2}'))"

      # Ensure JAVA_HOME is set even if Java is already installed
      if [ -z "${JAVA_HOME:-}" ] && [ -d "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home" ]; then
        export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
        export PATH="$JAVA_HOME/bin:$PATH"
      fi
    fi

    # Flutter SDK Installation
    if ! command -v flutter &> /dev/null; then
      if timed_confirm "Flutter SDK is required for mobile app development. Install? (Large download ~1GB)"; then
        check_installing "Flutter SDK"
        brew install flutter > /dev/null 2>&1

        # Add Flutter to PATH (prioritize Flutter's Dart over Homebrew's)
        FLUTTER_PATH="/opt/homebrew/share/flutter/bin"
        export PATH="$FLUTTER_PATH:$PATH"

        # Configure Flutter to use correct Android SDK
        flutter config --android-sdk "$ANDROID_HOME" > /dev/null 2>&1 || true

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

    # Android Development Setup
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
          cat >> "$SHELL_PROFILE" <<EOF

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

    # iOS Development Setup
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
