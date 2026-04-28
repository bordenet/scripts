#!/usr/bin/env bash
################################################################################
# Library: ui.sh
################################################################################
# PURPOSE: UI functions for purge-identity tool
# USAGE: Source this file from main script or lib/common.sh
# PLATFORM: macOS
################################################################################

display_menu() {
    display_section_header "Select Identities to Purge"

    echo "Discovered identities:"
    echo

    # Sort identities by count (descending)
    local sorted_identities
    sorted_identities=$(for email in "${!DISCOVERED_IDENTITIES[@]}"; do
        echo "${DISCOVERED_IDENTITIES[$email]} $email"
    done | sort -rn)

    # Display numbered list
    local index=1
    declare -g -A MENU_INDEX_TO_EMAIL  # Map menu number to email

    while IFS= read -r line; do
        local count
        count=$(echo "$line" | awk '{print $1}')
        local email
        email=$(echo "$line" | cut -d' ' -f2-)

        printf "  ${CYAN}%2d.${NC} %-40s ${YELLOW}(%d occurrences)${NC}\n" "$index" "$email" "$count"

        MENU_INDEX_TO_EMAIL[$index]="$email"
        ((index++))
    done <<< "$sorted_identities"

    echo
    echo "  ${CYAN} 0.${NC} Add a custom identity (manual entry)"
    echo

    return 0
}

# Parse user selection input
parse_selection() {
    local input="$1"
    local -a selected_emails=()

    # Trim whitespace
    input=$(echo "$input" | xargs)

    # Handle special cases
    if [[ "$input" == "all" ]]; then
        # Select all identities
        for email in "${!DISCOVERED_IDENTITIES[@]}"; do
            selected_emails+=("$email")
        done
        echo "${selected_emails[@]}"
        return 0
    fi

    # Parse comma-separated and range inputs
    IFS=',' read -ra parts <<< "$input"

    for part in "${parts[@]}"; do
        part=$(echo "$part" | xargs)  # Trim whitespace

        if [[ "$part" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Range (e.g., "1-4")
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"

            for ((i=start; i<=end; i++)); do
                if [[ -n "${MENU_INDEX_TO_EMAIL[$i]}" ]]; then
                    selected_emails+=("${MENU_INDEX_TO_EMAIL[$i]}")
                fi
            done
        elif [[ "$part" =~ ^[0-9]+$ ]]; then
            # Single number
            local num="$part"

            if [[ "$num" == "0" ]]; then
                # Manual entry
                add_manual_identity
                # Note: This returns the email directly
                return $?
            elif [[ -n "${MENU_INDEX_TO_EMAIL[$num]}" ]]; then
                selected_emails+=("${MENU_INDEX_TO_EMAIL[$num]}")
            else
                log_error "Invalid selection: $num"
            fi
        else
            log_error "Invalid selection format: $part"
        fi
    done

    # Remove duplicates
    local unique_emails
    unique_emails=$(printf '%s\n' "${selected_emails[@]}" | sort -u)

    echo "$unique_emails"
    return 0
}

# Add a manual identity (not auto-discovered)
add_manual_identity() {
    echo
    echo -e "${CYAN}Add Custom Identity${NC}"
    echo "Enter an email address or identity string to purge:"
    echo "(This will be added to the purge list even if not discovered)"
    echo

    read -p "Identity: " manual_identity

    # Trim whitespace
    manual_identity=$(echo "$manual_identity" | xargs)

    if [[ -z "$manual_identity" ]]; then
        log_error "No identity entered"
        return 1
    fi

    # Validate it looks like an email (basic check)
    if [[ ! "$manual_identity" =~ @ ]]; then
        echo -e "${YELLOW}Warning: '$manual_identity' doesn't look like an email address${NC}"
        read -p "Continue anyway? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Manual identity cancelled"
            return 1
        fi
    fi

    # Add to discovered identities
    DISCOVERED_IDENTITIES[$manual_identity]=0  # Mark as manual (0 occurrences in discovery)
    IDENTITY_LOCATIONS[$manual_identity]="manual_entry"

    log_info "Added manual identity: $manual_identity"
    echo "$manual_identity"
    return 0
}

# Get user selection from menu
get_user_selection() {
    echo "Selection options:"
    echo "  • Single: 3"
    echo "  • Multiple: 1,3,5"
    echo "  • Range: 1-4"
    echo "  • All: all"
    echo "  • Manual entry: 0"
    echo

    read -p "Select identities to purge: " user_input

    # Parse selection
    local selected
    selected=$(parse_selection "$user_input")

    if [[ -z "$selected" ]]; then
        log_error "No valid selections made"
        return 1
    fi

    echo "$selected"
    return 0
}

# -----------------------------------------------------------------------------
# Preview and Deletion Functions
# -----------------------------------------------------------------------------

# Generate detailed preview for a specific identity
generate_preview() {
    local identity="$1"

    # Preview data stored in global associative array
    declare -g -A PREVIEW_DATA
    PREVIEW_DATA=()

    log "INFO" "Generating preview for: $identity"

    # This will be a deep scan to find ALL occurrences
    # For now, use the location data from discovery
    local locations="${IDENTITY_LOCATIONS[$identity]}"

    # Count items by category
    local keychain_count=0
    local browser_count=0
    local mail_count=0
    local app_count=0
    local ssh_count=0
    local internet_account_count=0
    local cloud_count=0

    IFS=',' read -ra locs <<< "$locations"
    for loc in "${locs[@]}"; do
        case "$loc" in
            keychain*) ((keychain_count++)) ;;
            safari*|chrome*|edge*|firefox*) ((browser_count++)) ;;
            mail*) ((mail_count++)) ;;
            app_support*) ((app_count++)) ;;
            ssh*) ((ssh_count++)) ;;
            internet_account*) ((internet_account_count++)) ;;
            onedrive*|google_drive*) ((cloud_count++)) ;;
        esac
    done

    # Store in preview data
    PREVIEW_DATA[keychain]=$keychain_count
    PREVIEW_DATA[browsers]=$browser_count
    PREVIEW_DATA[mail]=$mail_count
    PREVIEW_DATA[app_support]=$app_count
    PREVIEW_DATA[ssh]=$ssh_count
    PREVIEW_DATA[internet_accounts]=$internet_account_count
    PREVIEW_DATA[cloud_storage]=$cloud_count

    log "DEBUG" "Preview generated: keychain=$keychain_count, browsers=$browser_count, mail=$mail_count"

    return 0
}

# Display preview of what will be deleted
display_preview() {
    local identity="$1"

    echo
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  Preview: What will be deleted for ${identity}${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════${NC}"
    echo

    local total=0

    if [[ ${PREVIEW_DATA[keychain]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Keychain:${NC} ${PREVIEW_DATA[keychain]} items (passwords, certificates, keys)"
        ((total+=PREVIEW_DATA[keychain]))
    fi

    if [[ ${PREVIEW_DATA[browsers]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Browsers:${NC} ${PREVIEW_DATA[browsers]} items (profiles, saved passwords, cookies)"
        echo -e "    ${RED}⚠ Browser profiles may include bookmarks and settings${NC}"
        ((total+=PREVIEW_DATA[browsers]))
    fi

    if [[ ${PREVIEW_DATA[mail]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Mail:${NC} ${PREVIEW_DATA[mail]} accounts (configuration and downloaded email)"
        echo -e "    ${RED}⚠ Downloaded email will be PERMANENTLY deleted${NC}"
        ((total+=PREVIEW_DATA[mail]))
    fi

    if [[ ${PREVIEW_DATA[app_support]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Applications:${NC} ${PREVIEW_DATA[app_support]} app-specific credentials"
        ((total+=PREVIEW_DATA[app_support]))
    fi

    if [[ ${PREVIEW_DATA[ssh]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}SSH:${NC} ${PREVIEW_DATA[ssh]} keys/config entries"
        echo -e "    ${RED}⚠ SSH key deletion is permanent${NC}"
        ((total+=PREVIEW_DATA[ssh]))
    fi

    if [[ ${PREVIEW_DATA[internet_accounts]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Internet Accounts:${NC} ${PREVIEW_DATA[internet_accounts]} system accounts"
        ((total+=PREVIEW_DATA[internet_accounts]))
    fi

    if [[ ${PREVIEW_DATA[cloud_storage]:-0} -gt 0 ]]; then
        echo -e "  ${YELLOW}Cloud Storage:${NC} ${PREVIEW_DATA[cloud_storage]} account configs (files preserved)"
        ((total+=PREVIEW_DATA[cloud_storage]))
    fi

    echo
    echo -e "${BOLD}Total items to delete: ${total}${NC}"
    echo

    if [[ $total -eq 0 ]]; then
        echo -e "${YELLOW}No items to delete for this identity${NC}"
        return 1
    fi

    return 0
}
