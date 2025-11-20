#!/usr/bin/env bash
################################################################################
# Library: helpers.sh
################################################################################
# PURPOSE: Helper functions for purge-identity tool
# USAGE: Source this file from main script or lib/common.sh
# PLATFORM: macOS
################################################################################

is_preserved_file() {
    local filepath="$1"

    # Check against preserved patterns
    for pattern in "${PRESERVED_PATTERNS[@]}"; do
        case "$filepath" in
            *$pattern*)
                log "DEBUG" "Preserved file detected: $filepath (matched: $pattern)"
                return 0  # File is preserved
                ;;
        esac
    done

    # Additional safety checks
    # Preserve files in cloud storage directories
    if [[ "$filepath" =~ /CloudStorage/ ]]; then
        log "DEBUG" "Preserved file in CloudStorage: $filepath"
        return 0
    fi

    return 1  # File is not preserved
}

# Add error to collection
add_error() {
    local message="$1"
    local remediation="$2"

    ERROR_MESSAGES+=("$message")
    ERROR_REMEDIATION+=("$remediation")

    log "ERROR" "$message"
    log "ERROR" "Remediation: $remediation"
}

# Check if sudo is required and request if needed
require_sudo() {
    local reason="$1"

    # Check if we already have sudo cached
    if sudo -n true 2>/dev/null; then
        return 0
    fi

    # Request sudo with clear messaging
    echo -e "${YELLOW}Requesting elevated privileges for ${reason}...${NC}"
    if sudo -v; then
        log "INFO" "Sudo granted for: $reason"
        return 0
    else
        log "ERROR" "Sudo denied for: $reason"
        return 1
    fi
}

# Check if an app is running
is_app_running() {
    local app_name="$1"
    pgrep -x "$app_name" > /dev/null 2>&1
}

# Prompt to quit an application
prompt_quit_app() {
    local app_name="$1"

    if ! is_app_running "$app_name"; then
        return 0  # App not running
    fi

    echo
    echo -e "${YELLOW}⚠ ${app_name} is currently running.${NC}"
    echo "  Browser databases are locked while the app is open."
    echo

    read -p "Quit ${app_name} now? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "User chose to quit $app_name"

        # Try to quit gracefully
        osascript -e "tell application \"$app_name\" to quit" 2>/dev/null || true

        # Wait up to 10 seconds for app to quit
        local count=0
        while is_app_running "$app_name" && [[ $count -lt 20 ]]; do
            sleep 0.5
            ((count++))
        done

        if is_app_running "$app_name"; then
            log_error "${app_name} did not quit. Please quit manually and re-run."
            return 1
        else
            log_success "${app_name} quit successfully"
            return 0
        fi
    else
        log "INFO" "User chose not to quit $app_name"
        return 1
    fi
}

# Confirm a potentially dangerous deletion
confirm_deletion() {
    local description="$1"

    echo
    echo -e "${YELLOW}⚠ WARNING:${NC} About to delete: ${description}"
    echo -e "${YELLOW}  This operation is PERMANENT and cannot be undone.${NC}"
    echo

    read -p "Continue with deletion? [y/N]: " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "INFO" "User confirmed deletion: $description"
        return 0
    else
        log "INFO" "User cancelled deletion: $description"
        return 1
    fi
}
