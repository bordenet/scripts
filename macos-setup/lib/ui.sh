#!/usr/bin/env bash
################################################################################
# macOS Setup UI Functions Library
################################################################################
# PURPOSE: User interface and output formatting for setup scripts
# USAGE: source "$(dirname "${BASH_SOURCE[0]}")/lib/ui.sh"
################################################################################

# Requires common.sh to be sourced first for color codes

# Global variables (set by main script)
: "${AUTO_YES:=false}"
: "${VERBOSE:=true}"
: "${CURRENT_SECTION:=}"
: "${SECTION_STATUS:=}"
declare -a SECTION_FAILURES

################################################################################
# Output Helper Functions
################################################################################

print_info()    { [ "$VERBOSE" = true ] && log_info "$1" || true; }
print_success() { [ "$VERBOSE" = true ] && log_success "$1" || true; }
print_warning() { [ "$VERBOSE" = true ] && log_warning "$1" || true; }
print_error()   { log_error "$1"; }  # Always show errors

################################################################################
# Section Management (Compact Mode)
################################################################################

section_start() {
    CURRENT_SECTION="$1"
    SECTION_STATUS="in_progress"
    SECTION_FAILURES=()
    if [ "$VERBOSE" = true ]; then
        echo ""
        print_info "$1"
    else
        printf "${COLOR_BLUE}[…]${COLOR_RESET} $1"
    fi
}

section_end() {
    if [ "$VERBOSE" = false ] && [ -n "$CURRENT_SECTION" ]; then
        if [ "${#SECTION_FAILURES[@]}" -gt 0 ]; then
            local failed_list="${SECTION_FAILURES[*]}"
            printf "\r\033[K${COLOR_RED}[✗]${COLOR_RESET} $CURRENT_SECTION ${COLOR_RED}($failed_list)${COLOR_RESET}\n"
        else
            printf "\r\033[K${COLOR_GREEN}[✓]${COLOR_RESET} $CURRENT_SECTION\n"
        fi
    fi
    CURRENT_SECTION=""
    SECTION_STATUS=""
    SECTION_FAILURES=()
}

section_update() {
    if [ "$VERBOSE" = false ] && [ -n "$CURRENT_SECTION" ]; then
        printf "\r\033[K${COLOR_BLUE}[…]${COLOR_RESET} $CURRENT_SECTION ${COLOR_DIM}($1)${COLOR_RESET}"
    fi
}

section_fail() {
    SECTION_STATUS="failed"
    if [ "$VERBOSE" = false ]; then
        SECTION_FAILURES+=("$1")
    fi
}

################################################################################
# Checklist-Style Output (Verbose Mode)
################################################################################

check_installing() {
    if [ "$VERBOSE" = true ]; then
        printf "[ ] Installing $1..."
    else
        section_update "$1"
    fi
}

check_done() {
    if [ "$VERBOSE" = true ]; then
        printf "\r[✓] Installed $1\n"
    fi
}

check_skip() {
    if [ "$VERBOSE" = true ]; then
        printf "\r[−] Skipped $1\n"
    else
        section_fail "$1 (skipped)"
    fi
}

check_exists() {
    if [ "$VERBOSE" = true ]; then
        printf "[✓] $1 already installed\n"
    fi
}

check_failed() {
    if [ "$VERBOSE" = true ]; then
        printf "\r[✗] Failed to install $1\n"
    else
        section_fail "$1"
    fi
    FAILED_INSTALLS+=("$1")
}

################################################################################
# User Confirmation
################################################################################

timed_confirm() {
    if [ "$AUTO_YES" = true ]; then
        return 0
    fi

    local prompt="$1"
    local timeout=10
    local response

    if [ "$VERBOSE" = true ]; then
        if ask_yes_no "$prompt" "y"; then
            return 0
        else
            return 1
        fi
    else
        if read -t $timeout -p "${prompt} (Y/n, ${timeout}s timeout): " response; then
            response=${response:-y}
            case "$response" in
                [yY]|[yY][eE][sS]) return 0 ;;
                *) return 1 ;;
            esac
        else
            echo "" # New line after timeout
            return 0  # Default to yes on timeout in compact mode
        fi
    fi
}
