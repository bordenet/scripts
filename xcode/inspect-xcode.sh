#!/usr/bin/env bash

# ==============================================================================
#
#          FILE:  inspect-xcode.sh
#
#         USAGE:  ./inspect-xcode.sh /path/to/your/project
#
#   DESCRIPTION:  This script analyzes an Xcode project for common issues,
#                 including project structure, Info.plist, build settings,
#                 and deprecated API usage.
#
#       OPTIONS:  ---
#  REQUIREMENTS:  macOS, Xcode Command Line Tools, Homebrew
#          BUGS:  ---
#         NOTES:  This script is intended to be a general-purpose tool for
#                 inspecting Xcode projects. It is not a replacement for
#                 more specialized tools like SwiftLint or OCLint.
#        AUTHOR:  Gemini
#       COMPANY:  Google
#       VERSION:  2.0
#       CREATED:  2025-10-29
#      REVISION:  ---
#
# ==============================================================================

# --- Colors for output ---

set -euo pipefail

# Display help information
show_help() {
    cat << EOF
NAME
    $(basename "$0") - Script functionality

SYNOPSIS
    $(basename "$0") [OPTIONS]

DESCRIPTION
    Script functionality

OPTIONS
    -h, --help
        Display this help message and exit

EXIT STATUS
    0   Success
    1   Error

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        *)
            break
            ;;
    esac
done


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Global Variables ---
PROJECT_DIR=""
PROJECT_FILE=""
WORKSPACE_FILE=""
INFO_PLIST=""

# --- Helper functions ---

# Check if running on macOS
check_os() {
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}Error: This script requires macOS.${NC}"
        exit 1
    fi
}

# Check for Homebrew
check_homebrew() {
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew not found. We recommend installing it for package management.${NC}"
    fi
}

# Check for required tools
check_required_tools() {
    local missing_tools=()
    for tool in "xcodebuild" "plutil" "git"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}Error: Missing required tools: ${missing_tools[*]}${NC}"
        echo "Please install them to continue. 'xcodebuild' and 'plutil' are part of the Xcode Command Line Tools."
        exit 1
    fi
}

# --- Main functions ---

# Function to set up global variables
setup_project_vars() {
    PROJECT_DIR=$(cd "$1" && pwd)
    PROJECT_FILE=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.xcodeproj" | head -n 1)
    WORKSPACE_FILE=$(find "$PROJECT_DIR" -maxdepth 1 -name "*.xcworkspace" | head -n 1)

    if [ -z "$PROJECT_FILE" ] && [ -z "$WORKSPACE_FILE" ]; then
        echo -e "${RED}Error: No .xcodeproj or .xcworkspace file found in '$PROJECT_DIR'.${NC}"
        exit 1
    fi

    INFO_PLIST=$(find "$PROJECT_DIR" -name "Info.plist" | head -n 1)
}

# Function to check Xcode project structure
check_project_structure() {
    echo -e "\n${BLUE}=== Project Structure Checks ===${NC}"

    if [ -n "$PROJECT_FILE" ]; then
        echo -e "${GREEN}✓ Xcode project file found: $(basename "$PROJECT_FILE")${NC}"
    elif [ -n "$WORKSPACE_FILE" ]; then
        echo -e "${GREEN}✓ Xcode workspace file found: $(basename "$WORKSPACE_FILE")${NC}"
    fi

    if [ -f "$PROJECT_DIR/Podfile" ]; then
        echo -e "${GREEN}✓ Podfile found${NC}"
        if [ -d "$PROJECT_DIR/Pods" ]; then
            echo -e "${GREEN}✓ Pods directory found${NC}"
        else
            echo -e "${YELLOW}⚠ Podfile exists but Pods directory not found. Run 'pod install' to install dependencies.${NC}"
        fi
    else
        echo -e "${YELLOW}✓ No Podfile found. This might be expected if you are not using CocoaPods.${NC}"
    fi
}

# Function to analyze Info.plist
analyze_info_plist() {
    if [ -z "$INFO_PLIST" ] || [ ! -f "$INFO_PLIST" ]; then
        echo -e "\n${YELLOW}⚠ Could not locate Info.plist. Skipping Info.plist analysis.${NC}"
        echo -e "  Please ensure that the INFOPLIST_FILE build setting is correctly configured in your project."
        return
    fi

    echo -e "\n${BLUE}=== Info.plist Analysis ===${NC}"
    echo -e "Found Info.plist at: $INFO_PLIST"

    local required_keys=(
        "CFBundleIdentifier"
        "CFBundleShortVersionString"
        "CFBundleVersion"
        "UILaunchStoryboardName"
    )
    local missing_keys=()
    for key in "${required_keys[@]}"; do
        if ! plutil -extract "$key" xml1 -o - "$INFO_PLIST" &> /dev/null; then
            missing_keys+=("$key")
        fi
    done

    if [ ${#missing_keys[@]} -gt 0 ]; then
        echo -e "${YELLOW}⚠ Missing required keys in Info.plist: ${missing_keys[*]}${NC}"
        echo -e "  These keys are essential for your app to function correctly."
    else
        echo -e "${GREEN}✓ All required Info.plist keys are present.${NC}"
    fi

    local bundle_id
    bundle_id=$(plutil -extract "CFBundleIdentifier" xml1 -o - "$INFO_PLIST" | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p')
    if [[ "$bundle_id" =~ ^[A-Za-z][A-Za-z0-9]*(\.[A-Za-z][A-Za-z0-9]*)+$ ]]; then
        echo -e "${GREEN}✓ CFBundleIdentifier format looks good: $bundle_id${NC}"
    else
        echo -e "${YELLOW}⚠ CFBundleIdentifier format might be invalid: $bundle_id${NC}"
        echo -e "  A typical bundle ID is a reverse-DNS string, e.g., com.yourcompany.yourapp."
    fi
}

# Function to check build settings
check_build_settings() {
    if [ -z "$PROJECT_FILE" ]; then
        echo -e "\n${YELLOW}⚠ No .xcodeproj file found. Skipping build settings analysis.${NC}"
        return
    fi

    echo -e "\n${BLUE}=== Build Settings Checks ===${NC}"
    local build_settings
    build_settings=$(xcodebuild -project "$PROJECT_FILE" -showBuildSettings 2>/dev/null)

    local deployment_target
    deployment_target=$(echo "$build_settings" | grep -m 1 'IPHONEOS_DEPLOYMENT_TARGET' | awk -F '= ' '{print $2}')
    if [[ "$deployment_target" =~ ^[0-9]+(\.[0-9]+)*$ ]] && (( $(echo "$deployment_target < 12.0" | bc -l) )); then
        echo -e "${YELLOW}⚠ Older deployment target: $deployment_target. Consider updating to a more recent iOS version for better performance and security.${NC}"
    else
        echo -e "${GREEN}✓ Modern deployment target: $deployment_target${NC}"
    fi

    local swift_version
    swift_version=$(echo "$build_settings" | grep "SWIFT_VERSION" | head -n 1 | awk -F "= " '{print $2}')
    if [ -n "$swift_version" ]; then
        echo -e "${GREEN}✓ Swift version: $swift_version${NC}"
    else
        echo -e "${YELLOW}⚠ Swift version not specified. It's recommended to set a specific Swift version in your build settings.${NC}"
    fi
}

# Function to check for deprecated APIs
check_deprecated_apis() {
    echo -e "\n${BLUE}=== Deprecated API Checks ===${NC}"
    local deprecated_found=0

    if grep -r "UIWebView" "$PROJECT_DIR" --include='*.swift' --include='*.m' --include='*.h' &> /dev/null; then
        echo -e "${RED}✗ UIWebView usage detected. UIWebView is deprecated and should be replaced with WKWebView.${NC}"
        deprecated_found=1
    fi

    if grep -r "OpenGL" "$PROJECT_DIR" --include='*.swift' --include='*.m' --include='*.h' &> /dev/null; then
        echo -e "${YELLOW}⚠ OpenGL ES usage detected. OpenGL ES is deprecated and should be replaced with Metal.${NC}"
        deprecated_found=1
    fi

    if [ $deprecated_found -eq 0 ]; then
        echo -e "${GREEN}✓ No usage of UIWebView or OpenGL ES detected.${NC}"
    fi
}

# --- Main execution ---
main() {
    check_os
    check_homebrew
    check_required_tools

    if [ $# -eq 0 ]; then
        echo -e "${RED}Usage: $0 <path-to-xcode-project-directory>${NC}"
        exit 1
    fi

    if [ ! -d "$1" ]; then
        echo -e "${RED}Error: Directory '$1' does not exist.${NC}"
        exit 1
    fi

    setup_project_vars "$1"

    echo -e "\n${BLUE}=== Xcode Inspector Deluxe ===${NC}"
    echo -e "Analyzing project at: $PROJECT_DIR\n"

    check_project_structure
    analyze_info_plist
    check_build_settings
    check_deprecated_apis

    echo -e "\n${BLUE}=== Analysis Complete ===${NC}"
    echo -e "For more detailed analysis, consider using:"
    echo -e "- SwiftLint for code style analysis"
    echo -e "- OCLint for static code analysis"
    echo -e "- Xcode's built-in Analyze tool (Product > Analyze)"
}

main "$@"
