#!/usr/bin/env bash
################################################################################
# Library: scanners-system.sh
################################################################################
# PURPOSE: Scanner functions for system apps (Mail, SSH, etc.) - purge-identity tool
# USAGE: Source this file from lib/common.sh
# PLATFORM: macOS
################################################################################

scan_mail() {
    log "INFO" "Scanning Mail.app accounts..."

    local mail_dir="$HOME/Library/Mail"
    [[ ! -d "$mail_dir" ]] && { log "DEBUG" "Mail directory not found"; return 0; }

    # Find Mail version directory (V9, V10, etc.)
    local mail_version_dir
    mail_version_dir=$(find "$mail_dir" -maxdepth 1 -type d -name "V*" 2>/dev/null | sort -r | head -n 1)

    if [[ -z "$mail_version_dir" ]]; then
        log "DEBUG" "No Mail version directory found"
        return 0
    fi

    local accounts_plist="${mail_version_dir}/MailData/Accounts.plist"

    if [[ -f "$accounts_plist" ]]; then
        # Convert plist to JSON and extract email addresses
        local accounts_json
        accounts_json=$(plutil -convert json -o - "$accounts_plist" 2>/dev/null)
        if [[ -n "$accounts_json" ]]; then
            local emails
            emails=$(echo "$accounts_json" | jq -r '.. | .EmailAddresses? // empty | .[]?' 2>/dev/null | sort -u)

            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "mail_account"
            done <<< "$emails"
        fi
    fi

    log "INFO" "Mail.app scan complete"
}

# Scan Application Support for identities
scan_application_support() {
    log "INFO" "Scanning Application Support (this may take a moment)..."

    local app_support="$HOME/Library/Application Support"
    [[ ! -d "$app_support" ]] && { log "DEBUG" "Application Support not found"; return 0; }

    # Whitelist of known apps to check specifically
    local known_apps=(
        "Microsoft"
        "com.microsoft.Office"
        "com.microsoft.Teams"
        "com.microsoft.OneDrive"
        "Slack"
        "Discord"
        "Zoom"
        "Code"
    )

    # Scan known apps
    for app in "${known_apps[@]}"; do
        local app_dir="${app_support}/${app}"
        [[ ! -d "$app_dir" ]] && continue

        log "DEBUG" "Scanning ${app}..."

        # Search for emails in plist, json, and text files (limited depth)
        while IFS= read -r -d '' file; do
            # Skip preserved files
            is_preserved_file "$file" && continue

            # Extract emails from file
            local emails
            emails=$(strings "$file" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "app_support:$app"
            done <<< "$emails"
        done < <(find "$app_dir" -maxdepth 3 -type f \( -name "*.plist" -o -name "*.json" -o -name "*.txt" \) -print0 2>/dev/null)
    done

    log "INFO" "Application Support scan complete"
}

# Scan SSH keys and configuration
scan_ssh() {
    log "INFO" "Scanning SSH keys and config..."

    local ssh_dir="$HOME/.ssh"
    [[ ! -d "$ssh_dir" ]] && { log "DEBUG" "SSH directory not found"; return 0; }

    # Scan public keys for email comments
    while IFS= read -r -d '' pubkey; do
        # Public keys often end with email as comment
        local comment
        comment=$(tail -c 200 "$pubkey" 2>/dev/null | grep -oE "$EMAIL_PATTERN")
        if [[ -n "$comment" ]]; then
            add_discovered_identity "$comment" "ssh_key:$(basename "$pubkey")"
        fi
    done < <(find "$ssh_dir" -name "*.pub" -type f -print0 2>/dev/null)

    # Check SSH config for potential identity hints
    local ssh_config="${ssh_dir}/config"
    if [[ -f "$ssh_config" ]]; then
        local emails
        emails=$(grep -oE "$EMAIL_PATTERN" "$ssh_config" 2>/dev/null | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "ssh_config"
        done <<< "$emails"
    fi

    log "INFO" "SSH scan complete"
}

# Scan Internet Accounts (System Preferences)
scan_internet_accounts() {
    log "INFO" "Scanning Internet Accounts..."

    local accounts_dir="$HOME/Library/Accounts"
    [[ ! -d "$accounts_dir" ]] && { log "DEBUG" "Accounts directory not found"; return 0; }

    # Accounts are stored in Accounts3.sqlite
    local accounts_db="${accounts_dir}/Accounts3.sqlite"

    if [[ -f "$accounts_db" ]]; then
        local temp_db="/tmp/accounts_$$.db"
        cp "$accounts_db" "$temp_db" 2>/dev/null || true

        if [[ -f "$temp_db" ]]; then
            # Extract account identifiers
            local accounts
            accounts=$(sqlite3 "$temp_db" "SELECT ZUSERNAME FROM ZACCOUNT WHERE ZUSERNAME LIKE '%@%';" 2>/dev/null | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "internet_account"
            done <<< "$accounts"
            rm -f "$temp_db"
        fi
    fi

    log "INFO" "Internet Accounts scan complete"
}

# Scan cloud storage configurations
scan_cloud_storage() {
    log "INFO" "Scanning cloud storage configurations..."

    # OneDrive preferences
    local onedrive_prefs="$HOME/Library/Preferences/com.microsoft.OneDrive.plist"
    if [[ -f "$onedrive_prefs" ]]; then
        local emails
        emails=$(plutil -convert json -o - "$onedrive_prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "onedrive_config"
        done <<< "$emails"
    fi

    # Google Drive (if installed)
    local gdrive_prefs="$HOME/Library/Application Support/Google/Drive"
    if [[ -d "$gdrive_prefs" ]]; then
        while IFS= read -r -d '' file; do
            local emails
            emails=$(strings "$file" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "google_drive_config"
            done <<< "$emails"
        done < <(find "$gdrive_prefs" \( -name "*.json" -o -name "*.db" \) -print0 2>/dev/null)
    fi

    log "INFO" "Cloud storage scan complete"
}
