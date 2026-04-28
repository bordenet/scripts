#!/usr/bin/env bash
################################################################################
# Library: processing.sh
################################################################################
# PURPOSE: Processing functions for purge-identity tool (discovery, execution, reporting)
# USAGE: Source this file from main script or lib/common.sh
# PLATFORM: macOS
################################################################################

add_discovered_identity() {
    local email="$1"
    local location="$2"

    # Skip empty emails
    [[ -z "$email" ]] && return

    # If TARGET_EMAIL is set, only process that specific email
    if [[ -n "$TARGET_EMAIL" ]] && [[ "$email" != "$TARGET_EMAIL" ]]; then
        return
    fi

    # Validate email format (basic sanitation - prevent command injection)
    if [[ ! "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        log "WARN" "Invalid email format detected, skipping: $email"
        return
    fi

    # Sanitize email (remove any shell metacharacters just in case)
    email="${email//[;<>\`\$\(\)]/}"

    # Increment total count
    if [[ -n "${DISCOVERED_IDENTITIES[$email]}" ]]; then
        DISCOVERED_IDENTITIES[$email]=$((DISCOVERED_IDENTITIES[$email] + 1))
    else
        DISCOVERED_IDENTITIES[$email]=1
    fi

    # Append location
    if [[ -n "${IDENTITY_LOCATIONS[$email]}" ]]; then
        IDENTITY_LOCATIONS[$email]="${IDENTITY_LOCATIONS[$email]},$location"
    else
        IDENTITY_LOCATIONS[$email]="$location"
    fi

    log "DEBUG" "Found $email in $location"
}

# Scanner functions now in purge-identity/lib/scanners.sh

# Discover a single specific identity
discover_single_identity() {
    local target="$1"

    # Initialize/reset global arrays
    DISCOVERED_IDENTITIES=()
    IDENTITY_LOCATIONS=()

    # Run all scan functions (add_discovered_identity will filter for target)
    scan_keychain
    scan_safari
    scan_chrome
    scan_edge
    scan_firefox
    scan_mail
    scan_application_support
    scan_ssh
    scan_internet_accounts
    scan_cloud_storage

    # Report findings
    local count=${DISCOVERED_IDENTITIES[$target]:-0}
    if [[ $count -gt 0 ]]; then
        echo -e "${GREEN}✓ Found $count occurrences of ${target}${NC}"
        echo
        return 0
    else
        return 1
    fi
}

# Orchestrate all discovery scans (unused in new single-email mode, kept for reference)
discover_all_identities() {
    display_section_header "Discovering Identities"

    # Initialize/reset global arrays
    DISCOVERED_IDENTITIES=()
    IDENTITY_LOCATIONS=()

    echo "Scanning system for email identities..."
    echo "(This may take 1-2 minutes depending on system size)"
    echo

    # Run all scan functions
    scan_keychain
    scan_safari
    scan_chrome
    scan_edge
    scan_firefox
    scan_mail
    scan_application_support
    scan_ssh
    scan_internet_accounts
    scan_cloud_storage

    # Count results
    local total_found=${#DISCOVERED_IDENTITIES[@]}

    echo
    if [[ $total_found -eq 0 ]]; then
        log_info "No email identities found on this system"
        return 1
    else
        log_success "Discovery complete: $total_found unique identities found"
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Menu and Selection Functions
# -----------------------------------------------------------------------------

# Display interactive menu of discovered identities
# UI functions now in purge-identity/lib/ui.sh

# Process a single identity (preview, confirm, delete)
process_identity() {
    local identity="$1"
    local index="$2"
    local total="$3"

    echo
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}Processing identity $index of $total: ${BOLD}$identity${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"

    # Generate preview
    generate_preview "$identity"

    # Display preview
    if ! display_preview "$identity"; then
        log_info "Skipping $identity (no items to delete)"
        return 0
    fi

    # In what-if mode, skip confirmation and deletion
    if [[ "$WHAT_IF_MODE" == true ]]; then
        echo -e "${YELLOW}(What-if mode: no deletion will occur)${NC}"
        return 0
    fi

    # Confirm deletion
    if ! confirm_deletion "ALL items for $identity"; then
        log_info "Skipped: $identity"
        return 0
    fi

    # Execute deletion
    execute_deletion "$identity"

    return 0
}

# -----------------------------------------------------------------------------
# Deletion Functions (Actual Deletion Logic)
# -----------------------------------------------------------------------------

# Delete functions now in purge-identity/lib/deleters.sh

# Execute deletion for an identity
execute_deletion() {
    local identity="$1"

    log "INFO" "Executing deletion for: $identity"

    echo
    echo -e "${CYAN}Deleting all data for: ${BOLD}$identity${NC}"
    echo

    # Delete from each category if present
    if [[ ${PREVIEW_DATA[keychain]:-0} -gt 0 ]]; then
        echo "▸ Keychain..."
        delete_keychain_items "$identity"
    fi

    if [[ ${PREVIEW_DATA[browsers]:-0} -gt 0 ]]; then
        echo "▸ Browsers..."
        delete_browser_data "$identity"
    fi

    if [[ ${PREVIEW_DATA[mail]:-0} -gt 0 ]]; then
        echo "▸ Mail..."
        delete_mail_account "$identity"
    fi

    if [[ ${PREVIEW_DATA[app_support]:-0} -gt 0 ]]; then
        echo "▸ Applications..."
        delete_app_support_data "$identity"
    fi

    if [[ ${PREVIEW_DATA[ssh]:-0} -gt 0 ]]; then
        echo "▸ SSH..."
        delete_ssh_data "$identity"
    fi

    if [[ ${PREVIEW_DATA[internet_accounts]:-0} -gt 0 ]]; then
        echo "▸ Internet Accounts..."
        delete_internet_account "$identity"
    fi

    if [[ ${PREVIEW_DATA[cloud_storage]:-0} -gt 0 ]]; then
        echo "▸ Cloud Storage..."
        delete_cloud_storage_config "$identity"
    fi

    echo
    log_success "Deletion complete for: $identity"

    return 0
}

# -----------------------------------------------------------------------------
# Exit Report
# -----------------------------------------------------------------------------

# Display comprehensive exit report
display_exit_report() {
    stop_timer

    local elapsed
    elapsed=$(get_elapsed_time)

    echo
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Purge Complete${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "Total time: ${YELLOW}$elapsed${NC}"
    echo

    # If there were errors, display them
    if [[ ${#ERROR_MESSAGES[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}ERRORS (${#ERROR_MESSAGES[@]}):${NC}"
        echo

        for i in "${!ERROR_MESSAGES[@]}"; do
            echo -e "${RED}  $((i+1)). ${ERROR_MESSAGES[$i]}${NC}"
            if [[ -n "${ERROR_REMEDIATION[$i]}" ]]; then
                echo -e "     ${YELLOW}→ ${ERROR_REMEDIATION[$i]}${NC}"
            fi
            echo
        done
    else
        echo -e "${GREEN}No errors encountered${NC}"
        echo
    fi

    # Display log location
    echo -e "Detailed log: ${CYAN}${LOG_FILE}${NC}"
    echo

    log "INFO" "Exit report displayed"
}
