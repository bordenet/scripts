#!/usr/bin/env bash
################################################################################
# Component: Mobile Development Environment (Coordinator)
################################################################################
# PURPOSE: Coordinates installation of all mobile development components
# REUSABLE: YES
# DEPENDENCIES: 00-homebrew, 10-essentials
#
# COMPONENTS:
#   - 21-java.sh: Java JDK (required for Android)
#   - 22-flutter.sh: Flutter SDK
#   - 23-android.sh: Android Studio and SDK
#   - 24-ios.sh: iOS tools (CocoaPods, SwiftLint)
#   - 25-cloud-tools.sh: AWS CLI and cloud provider tools
#
# ADOPTION NOTES FOR FUTURE REPOS:
# - This is a coordinator that runs sub-components
# - Enable/disable components by commenting out source calls below
# - Each component can be run independently
################################################################################

# Component metadata

set -euo pipefail

COMPONENT_NAME="Mobile development environment"

# Get the directory where this script lives
COMPONENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Installation function (called by main script)
install_component() {
    section_start "$COMPONENT_NAME"

    # Source and run Java component (required for Android)
    if [ -f "$COMPONENT_DIR/21-java.sh" ]; then
        # shellcheck source=/dev/null
        source "$COMPONENT_DIR/21-java.sh"
        install_component
    fi

    # Source and run Flutter component
    if [ -f "$COMPONENT_DIR/22-flutter.sh" ]; then
        # shellcheck source=/dev/null
        source "$COMPONENT_DIR/22-flutter.sh"
        install_component
    fi

    # Source and run Android component
    if [ -f "$COMPONENT_DIR/23-android.sh" ]; then
        # shellcheck source=/dev/null
        source "$COMPONENT_DIR/23-android.sh"
        install_component
    fi

    # Source and run iOS component
    if [ -f "$COMPONENT_DIR/24-ios.sh" ]; then
        # shellcheck source=/dev/null
        source "$COMPONENT_DIR/24-ios.sh"
        install_component
    fi

    # Source and run cloud tools component
    if [ -f "$COMPONENT_DIR/25-cloud-tools.sh" ]; then
        # shellcheck source=/dev/null
        source "$COMPONENT_DIR/25-cloud-tools.sh"
        install_component
    fi

    section_end
}
