#!/usr/bin/env bash
################################################################################
# Component: Java Development Kit
################################################################################
# PURPOSE: Install and configure Java JDK for development
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This component installs OpenJDK 17 via Homebrew
# - Required for Android development
# - Configures JAVA_HOME automatically
################################################################################

# Component metadata
COMPONENT_NAME="Java Development Kit"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

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
          cat >> "$SHELL_PROFILE" <<'EOF'

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

    section_end
}
