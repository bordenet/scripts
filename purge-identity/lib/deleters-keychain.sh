#!/usr/bin/env bash
################################################################################
# Library: deleters.sh
################################################################################
# PURPOSE: Delete functions for purge-identity tool
# USAGE: Source this file from main script or lib/common.sh
# PLATFORM: macOS
################################################################################

# Delete keychain items for an identity
delete_keychain_items() {
    local identity="$1"
    local deleted_count=0
    local failed_count=0

    log "INFO" "Deleting keychain items for: $identity"
    echo "  Scanning keychain for items matching: $identity"

    # Delete generic passwords (apps, services)
    echo "    Searching for generic passwords..."
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local service
        service=$(echo "$line" | awk '{print $1}')
        local account
        account=$(echo "$line" | awk '{print $2}')

        if security delete-generic-password -s "$service" -a "$account" 2>/dev/null; then
            log "INFO" "Deleted generic password: $service ($account)"
            echo "      ✓ Deleted: $service"
            ((deleted_count++))
        else
            ((failed_count++))
            log "WARN" "Failed to delete generic password: $service ($account)"
        fi
    done < <(security dump-keychain 2>/dev/null | \
             awk -v email="$identity" '
                 /^keychain:/ { keychain=$0 }
                 /"acct"<blob>=/ {
                     if ($0 ~ email) {
                         acct=$0
                         getline
                         while (getline && !/^keychain:/ && !/^attributes:/) {
                             if (/"svce"<blob>=/) {
                                 gsub(/.*"svce"<blob>="/, "")
                                 gsub(/".*/, "")
                                 svce=$0
                                 gsub(/.*"acct"<blob>="/, "", acct)
                                 gsub(/".*/, "", acct)
                                 print svce, acct
                             }
                         }
                     }
                 }
             ')

    # Delete internet passwords (websites, email accounts)
    echo "    Searching for internet passwords..."
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local server
        server=$(echo "$line" | awk '{print $1}')
        local account
        account=$(echo "$line" | awk '{print $2}')

        if security delete-internet-password -s "$server" -a "$account" 2>/dev/null; then
            log "INFO" "Deleted internet password: $server ($account)"
            echo "      ✓ Deleted: $server"
            ((deleted_count++))
        else
            ((failed_count++))
            log "WARN" "Failed to delete internet password: $server ($account)"
        fi
    done < <(security dump-keychain 2>/dev/null | \
             awk -v email="$identity" '
                 /"acct"<blob>=/ {
                     if ($0 ~ email) {
                         acct=$0
                         gsub(/.*"acct"<blob>="/, "", acct)
                         gsub(/".*/, "", acct)
                         found=1
                     }
                 }
                 found && /"srvr"<blob>=/ {
                     gsub(/.*"srvr"<blob>="/, "")
                     gsub(/".*/, "")
                     print $0, acct
                     found=0
                 }
             ')

    # Delete certificates matching the email
    echo "    Searching for certificates..."
    while IFS= read -r cert_hash; do
        [[ -z "$cert_hash" ]] && continue

        if security delete-certificate -Z "$cert_hash" 2>/dev/null; then
            log "INFO" "Deleted certificate: $cert_hash"
            echo "      ✓ Deleted certificate: ${cert_hash:0:16}..."
            ((deleted_count++))
        else
            ((failed_count++))
            log "WARN" "Failed to delete certificate: $cert_hash"
        fi
    done < <(security find-certificate -a -e "$identity" -Z 2>/dev/null | \
             grep "^SHA-256 hash:" | awk '{print $3}')

    echo
    if [[ $deleted_count -eq 0 ]]; then
        if [[ $failed_count -gt 0 ]]; then
            echo "    ${YELLOW}⚠ Could not delete $failed_count keychain items (may require user interaction)${NC}"
            add_error "Keychain items for $identity require manual cleanup" \
                      "Open Keychain Access.app and search for: $identity"
        else
            echo "    ${GREEN}✓ No keychain items found for $identity${NC}"
        fi
    else
        echo "    ${GREEN}✓ Deleted $deleted_count keychain items${NC}"
        if [[ $failed_count -gt 0 ]]; then
            echo "    ${YELLOW}⚠ $failed_count items require manual deletion${NC}"
            add_error "Some keychain items for $identity require manual cleanup" \
                      "Open Keychain Access.app and search for: $identity"
        fi
        log "INFO" "Deleted $deleted_count keychain items, $failed_count failed"
    fi

    return 0
}

# Delete browser data for an identity
delete_browser_data() {
    local identity="$1"
    local deleted_count=0

    log "INFO" "Deleting browser data for: $identity"

    # Check which browsers have data for this identity
    local locations="${IDENTITY_LOCATIONS[$identity]}"

    # Chrome
    if [[ "$locations" =~ chrome ]]; then
        if is_app_running "Google Chrome"; then
            if ! prompt_quit_app "Google Chrome"; then
                add_error "Chrome is running" "Quit Chrome and manually delete profiles containing: $identity"
            else
                deleted_count=$((deleted_count + $(delete_chrome_profiles "$identity")))
            fi
        else
            deleted_count=$((deleted_count + $(delete_chrome_profiles "$identity")))
        fi
    fi

    # Edge
    if [[ "$locations" =~ edge ]]; then
        if is_app_running "Microsoft Edge"; then
            if ! prompt_quit_app "Microsoft Edge"; then
                add_error "Edge is running" "Quit Edge and manually delete profiles containing: $identity"
            else
                deleted_count=$((deleted_count + $(delete_edge_profiles "$identity")))
            fi
        else
            deleted_count=$((deleted_count + $(delete_edge_profiles "$identity")))
        fi
    fi

    # Firefox
    if [[ "$locations" =~ firefox ]]; then
        if is_app_running "Firefox"; then
            if ! prompt_quit_app "Firefox"; then
                add_error "Firefox is running" "Quit Firefox and manually delete profiles containing: $identity"
            else
                deleted_count=$((deleted_count + $(delete_firefox_profiles "$identity")))
            fi
        else
            deleted_count=$((deleted_count + $(delete_firefox_profiles "$identity")))
        fi
    fi

    # Safari (data in keychain, handled separately)
    if [[ "$locations" =~ safari ]]; then
        echo "  Safari data (cookies, history) cleared via keychain and cache cleanup"
    fi

    log "INFO" "Browser deletion complete: $deleted_count profiles/items removed"
    return 0
}

# Delete Chrome profiles for an identity
