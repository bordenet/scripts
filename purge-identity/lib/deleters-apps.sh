#!/usr/bin/env bash
################################################################################
# Library: deleters-apps.sh
################################################################################
# PURPOSE: Delete functions for browser and app data (purge-identity tool)
# USAGE: Source this file from lib/common.sh
# PLATFORM: macOS
################################################################################

delete_chrome_profiles() {
    local identity="$1"
    local deleted=0

    local chrome_dir="$HOME/Library/Application Support/Google/Chrome"
    [[ ! -d "$chrome_dir" ]] && { echo "0"; return; }

    for profile_dir in "$chrome_dir"/*/ "$chrome_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        local prefs="${profile_dir}/Preferences"

        # Check if this profile contains the identity in ANY location
        local is_match=false

        # Check 1: Sync email
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ "$sync_email" == "$identity" ]] && is_match=true

            # Check 2: Any occurrence in Preferences JSON
            if [[ "$is_match" == false ]]; then
                if jq -r '.. | strings' "$prefs" 2>/dev/null | grep -qF "$identity"; then
                    is_match=true
                    log "DEBUG" "Found $identity in Chrome prefs: $profile_name"
                fi
            fi
        fi

        # Check 3: Saved passwords
        if [[ "$is_match" == false ]]; then
            local login_db="${profile_dir}/Login Data"
            if [[ -f "$login_db" ]]; then
                local temp_db="/tmp/chrome_login_check_$$.db"
                if cp "$login_db" "$temp_db" 2>/dev/null; then
                    if sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value = '$identity';" 2>/dev/null | grep -q .; then
                        is_match=true
                        log "DEBUG" "Found $identity in Chrome passwords: $profile_name"
                    fi
                    rm -f "$temp_db"
                fi
            fi
        fi

        if [[ "$is_match" == true ]]; then
            echo "      Deleting Chrome profile: $profile_name"
            if rm -rf "$profile_dir" 2>/dev/null; then
                echo "      ✓ Deleted Chrome profile: $profile_name"
                log "INFO" "Deleted Chrome profile: $profile_name"
                ((deleted++))
            else
                echo "      ✗ Failed to delete: $profile_name"
                add_error "Failed to delete Chrome profile: $profile_name" \
                          "Manually delete: $profile_dir"
            fi
        fi
    done

    echo "$deleted"
}

# Delete Edge profiles for an identity
delete_edge_profiles() {
    local identity="$1"
    local deleted=0

    local edge_dir="$HOME/Library/Application Support/Microsoft Edge"
    [[ ! -d "$edge_dir" ]] && { echo "0"; return; }

    for profile_dir in "$edge_dir"/*/ "$edge_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        local prefs="${profile_dir}/Preferences"

        # Check if this profile contains the identity in ANY location
        local is_match=false

        # Check 1: Sync email
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ "$sync_email" == "$identity" ]] && is_match=true

            # Check 2: Any occurrence in Preferences JSON
            if [[ "$is_match" == false ]]; then
                if jq -r '.. | strings' "$prefs" 2>/dev/null | grep -qF "$identity"; then
                    is_match=true
                    log "DEBUG" "Found $identity in Edge prefs: $profile_name"
                fi
            fi
        fi

        # Check 3: Saved passwords
        if [[ "$is_match" == false ]]; then
            local login_db="${profile_dir}/Login Data"
            if [[ -f "$login_db" ]]; then
                local temp_db="/tmp/edge_login_check_$$.db"
                if cp "$login_db" "$temp_db" 2>/dev/null; then
                    if sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value = '$identity';" 2>/dev/null | grep -q .; then
                        is_match=true
                        log "DEBUG" "Found $identity in Edge passwords: $profile_name"
                    fi
                    rm -f "$temp_db"
                fi
            fi
        fi

        if [[ "$is_match" == true ]]; then
            echo "      Deleting Edge profile: $profile_name"
            if rm -rf "$profile_dir" 2>/dev/null; then
                echo "      ✓ Deleted Edge profile: $profile_name"
                log "INFO" "Deleted Edge profile: $profile_name"
                ((deleted++))
            else
                echo "      ✗ Failed to delete: $profile_name"
                add_error "Failed to delete Edge profile: $profile_name" \
                          "Manually delete: $profile_dir"
            fi
        fi
    done

    echo "$deleted"
}

# Delete Firefox profiles for an identity
delete_firefox_profiles() {
    local identity="$1"
    local deleted=0

    local firefox_dir="$HOME/Library/Application Support/Firefox/Profiles"
    [[ ! -d "$firefox_dir" ]] && { echo "0"; return; }

    for profile_dir in "$firefox_dir"/*/ ; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")

        # Check if profile contains the identity in ANY location
        local is_match=false

        # Check 1: logins.json (saved passwords)
        local logins_json="${profile_dir}/logins.json"
        if [[ -f "$logins_json" ]]; then
            if jq -r '.logins[].username // empty' "$logins_json" 2>/dev/null | grep -qF "$identity"; then
                is_match=true
                log "DEBUG" "Found $identity in Firefox logins: $profile_name"
            fi
        fi

        # Check 2: places.sqlite (history/bookmarks)
        if [[ "$is_match" == false ]]; then
            local places_db="${profile_dir}/places.sqlite"
            if [[ -f "$places_db" ]]; then
                local temp_db="/tmp/firefox_places_check_$$.db"
                if cp "$places_db" "$temp_db" 2>/dev/null; then
                    if sqlite3 "$temp_db" "SELECT url FROM moz_places WHERE url LIKE '%$identity%';" 2>/dev/null | grep -q .; then
                        is_match=true
                        log "DEBUG" "Found $identity in Firefox history: $profile_name"
                    fi
                    rm -f "$temp_db"
                fi
            fi
        fi

        if [[ "$is_match" == true ]]; then
            echo "      Deleting Firefox profile: $profile_name"
            if rm -rf "$profile_dir" 2>/dev/null; then
                echo "      ✓ Deleted Firefox profile: $profile_name"
                log "INFO" "Deleted Firefox profile: $profile_name"
                ((deleted++))
            else
                echo "      ✗ Failed to delete: $profile_name"
                add_error "Failed to delete Firefox profile: $profile_name" \
                          "Manually delete: $profile_dir"
            fi
        fi
    done

    echo "$deleted"
}

# Delete Mail.app account for an identity
delete_mail_account() {
    local identity="$1"

    log "INFO" "Deleting Mail.app account for: $identity"

    if is_app_running "Mail"; then
        if ! prompt_quit_app "Mail"; then
            add_error "Mail.app is running" "Quit Mail and manually remove account: $identity"
            return 1
        fi
    fi

    local mail_dir="$HOME/Library/Mail"
    local mail_version_dir
    mail_version_dir=$(find "$mail_dir" -maxdepth 1 -type d -name "V*" 2>/dev/null | sort -r | head -n 1)

    [[ ! -d "$mail_version_dir" ]] && { echo "  No Mail data found"; return 0; }

    local accounts_plist="${mail_version_dir}/MailData/Accounts.plist"

    if [[ ! -f "$accounts_plist" ]]; then
        echo "  No Mail accounts found"
        return 0
    fi

    # Convert to JSON and find account
    # This is complex - for now, report that manual removal may be needed
    local accounts_json
    # shellcheck disable=SC2034
    accounts_json=$(plutil -convert json -o - "$accounts_plist" 2>/dev/null)

    echo "  ${YELLOW}Mail.app account removal requires manual cleanup${NC}"
    echo "  ${YELLOW}Open Mail.app > Preferences > Accounts and remove: $identity${NC}"

    add_error "Mail.app account for $identity requires manual removal" \
              "Open Mail.app > Preferences > Accounts > Remove account: $identity"

    return 0
}

# Delete application support data for an identity
delete_app_support_data() {
    local identity="$1"

    log "INFO" "Deleting application support data for: $identity"

    local app_support="$HOME/Library/Application Support"

    # Known apps that might need cleanup
    local apps_to_check=("Microsoft" "Slack" "Discord" "Zoom" "Code")

    for app in "${apps_to_check[@]}"; do
        local app_dir="${app_support}/${app}"
        [[ ! -d "$app_dir" ]] && continue

        # Check if this app has data for the identity
        if grep -r "$identity" "$app_dir" >/dev/null 2>&1; then
            echo "  ${YELLOW}Found $app data containing: $identity${NC}"
            echo "  ${YELLOW}App-specific data cleanup requires manual review${NC}"

            add_error "$app contains data for $identity" \
                      "Manually review and clean up: $app_dir"
        fi
    done

    return 0
}

# Delete SSH keys and config for an identity
delete_ssh_data() {
    local identity="$1"

    log "INFO" "Deleting SSH data for: $identity"

    local ssh_dir="$HOME/.ssh"
    [[ ! -d "$ssh_dir" ]] && { echo "  No SSH directory found"; return 0; }

    local deleted_count=0

    # Find public keys with this identity as comment
    while IFS= read -r -d '' pubkey; do
        if grep -q "$identity" "$pubkey" 2>/dev/null; then
            local privkey="${pubkey%.pub}"

            # Confirm before deleting SSH key
            if confirm_deletion "SSH key pair: $(basename "$pubkey")"; then
                # Delete both public and private key
                if rm -f "$pubkey" "$privkey" 2>/dev/null; then
                    echo "    ✓ Deleted SSH key: $(basename "$pubkey")"
                    log "INFO" "Deleted SSH key: $pubkey"
                    ((deleted_count++))
                else
                    add_error "Failed to delete SSH key: $pubkey" \
                              "Manually delete: rm -f \"$pubkey\" \"$privkey\""
                fi
            else
                log "INFO" "Skipped SSH key: $pubkey"
            fi
        fi
    done < <(find "$ssh_dir" -name "*.pub" -type f -print0 2>/dev/null)

    # Remove entries from SSH config
    local ssh_config="${ssh_dir}/config"
    if [[ -f "$ssh_config" ]]; then
        if grep -q "$identity" "$ssh_config" 2>/dev/null; then
            echo "  ${YELLOW}SSH config contains references to: $identity${NC}"
            echo "  ${YELLOW}Please manually review and edit: $ssh_config${NC}"

            add_error "SSH config contains $identity" \
                      "Manually edit: $ssh_config"
        fi
    fi

    return 0
}

# Delete Internet Account (System Preferences)
delete_internet_account() {
    local identity="$1"

    log "INFO" "Checking Internet Accounts for: $identity"

    echo "  ${YELLOW}Internet Accounts (System Preferences) require manual removal${NC}"
    echo "  ${YELLOW}Open System Settings > Internet Accounts and remove: $identity${NC}"

    add_error "Internet Account for $identity requires manual removal" \
              "Open System Settings > Internet Accounts > Remove account: $identity"

    return 0
}

# Delete cloud storage configurations
delete_cloud_storage_config() {
    local identity="$1"

    log "INFO" "Deleting cloud storage configs for: $identity"

    # OneDrive
    local onedrive_prefs="$HOME/Library/Preferences/com.microsoft.OneDrive.plist"
    if [[ -f "$onedrive_prefs" ]]; then
        if grep -q "$identity" "$onedrive_prefs" 2>/dev/null || \
           plutil -convert json -o - "$onedrive_prefs" 2>/dev/null | grep -q "$identity"; then

            echo "  ${YELLOW}OneDrive configuration contains: $identity${NC}"
            echo "  ${YELLOW}Quit OneDrive and sign out of this account manually${NC}"

            add_error "OneDrive config for $identity requires manual cleanup" \
                      "Quit OneDrive, then sign out of account: $identity"
        fi
    fi

    # Google Drive
    # Similar approach - flag for manual cleanup

    return 0
}
