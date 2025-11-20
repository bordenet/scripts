#!/usr/bin/env bash
################################################################################
# Library: scanners.sh
################################################################################
# PURPOSE: Scanner functions for purge-identity tool
# USAGE: Source this file from main script or lib/common.sh
# PLATFORM: macOS
################################################################################

# Scan keychain for identities
scan_keychain() {
    log "INFO" "Scanning keychain for identities..."

    # Dump login keychain
    local keychain_dump
    keychain_dump=$(security dump-keychain 2>/dev/null)

    if [[ -z "$keychain_dump" ]]; then
        log "WARN" "Could not dump keychain (may require unlock)"
        return 0
    fi

    # Extract emails from ACCOUNT fields only (what we can actually delete)
    # This matches what delete_keychain_items does
    local emails
    emails=$(echo "$keychain_dump" | \
             grep '"acct"<blob>=' | \
             sed -E 's/.*"acct"<blob>="([^"]+)".*/\1/' | \
             grep -E "$EMAIL_PATTERN" | \
             sort -u)

    # Also check certificates (deletable via security delete-certificate)
    local cert_emails
    cert_emails=$(security find-certificate -a -p 2>/dev/null | \
                  openssl x509 -noout -email 2>/dev/null | \
                  grep -E "^$EMAIL_PATTERN$" | sort -u)

    # Combine and deduplicate
    local all_emails
    all_emails=$(printf "%s\n%s\n" "$emails" "$cert_emails" | grep -E "$EMAIL_PATTERN" | sort -u)

    # Store in global discovery array
    while IFS= read -r email; do
        [[ -n "$email" ]] && add_discovered_identity "$email" "keychain"
    done <<< "$all_emails"

    local count
    count=$(echo "$all_emails" | grep -c . 2>/dev/null || echo "0")
    log "INFO" "Keychain scan complete: $count unique emails found"
}

# Scan Safari for identities
scan_safari() {
    log "INFO" "Scanning Safari..."

    local safari_dir="$HOME/Library/Safari"
    [[ ! -d "$safari_dir" ]] && { log "DEBUG" "Safari directory not found"; return 0; }

    # Scan history database
    local history_db="${safari_dir}/History.db"
    if [[ -f "$history_db" ]]; then
        local temp_db="/tmp/safari_history_$$.db"
        cp "$history_db" "$temp_db" 2>/dev/null || true

        if [[ -f "$temp_db" ]]; then
            # Extract emails from history URLs and titles
            local emails
            emails=$(sqlite3 "$temp_db" "SELECT url FROM history_items;" 2>/dev/null | \
                          grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "safari_history"
            done <<< "$emails"
            rm -f "$temp_db"
        fi
    fi

    # Check Safari preferences
    local prefs="${safari_dir}/Preferences/com.apple.Safari.plist"
    if [[ -f "$prefs" ]]; then
        local emails
        emails=$(plutil -convert json -o - "$prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "safari_prefs"
        done <<< "$emails"
    fi

    log "INFO" "Safari scan complete"
}

# Scan Chrome for identities
scan_chrome() {
    log "INFO" "Scanning Chrome..."

    local chrome_dir="$HOME/Library/Application Support/Google/Chrome"
    [[ ! -d "$chrome_dir" ]] && { log "DEBUG" "Chrome directory not found"; return 0; }

    # Scan all Chrome profiles
    local profile_count=0
    for profile_dir in "$chrome_dir"/*/ "$chrome_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        log "DEBUG" "Scanning Chrome profile: $profile_name"

        # Parse Preferences JSON for sync email
        local prefs="${profile_dir}/Preferences"
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ -n "$sync_email" ]] && add_discovered_identity "$sync_email" "chrome_profile:$profile_name"

            # Extract any emails from preferences
            local emails
            emails=$(jq -r '.. | strings' "$prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "chrome_prefs:$profile_name"
            done <<< "$emails"
        fi

        # Parse Login Data (SQLite) for saved usernames
        local login_db="${profile_dir}/Login Data"
        if [[ -f "$login_db" ]]; then
            local temp_db="/tmp/chrome_login_$$.db"
            cp "$login_db" "$temp_db" 2>/dev/null || true

            if [[ -f "$temp_db" ]]; then
                local usernames
                usernames=$(sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value LIKE '%@%';" 2>/dev/null | sort -u)
                while IFS= read -r email; do
                    [[ -n "$email" ]] && add_discovered_identity "$email" "chrome_passwords:$profile_name"
                done <<< "$usernames"
                rm -f "$temp_db"
            fi
        fi

        ((profile_count++))
    done

    log "INFO" "Chrome scan complete: $profile_count profiles scanned"
}

# Scan Microsoft Edge for identities
scan_edge() {
    log "INFO" "Scanning Microsoft Edge..."

    local edge_dir="$HOME/Library/Application Support/Microsoft Edge"
    [[ ! -d "$edge_dir" ]] && { log "DEBUG" "Edge directory not found"; return 0; }

    # Scan all Edge profiles (same structure as Chrome)
    local profile_count=0
    for profile_dir in "$edge_dir"/*/ "$edge_dir/Default"; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        log "DEBUG" "Scanning Edge profile: $profile_name"

        # Parse Preferences JSON
        local prefs="${profile_dir}/Preferences"
        if [[ -f "$prefs" ]]; then
            local sync_email
            sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ -n "$sync_email" ]] && add_discovered_identity "$sync_email" "edge_profile:$profile_name"

            local emails
            emails=$(jq -r '.. | strings' "$prefs" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "edge_prefs:$profile_name"
            done <<< "$emails"
        fi

        # Parse Login Data
        local login_db="${profile_dir}/Login Data"
        if [[ -f "$login_db" ]]; then
            local temp_db="/tmp/edge_login_$$.db"
            cp "$login_db" "$temp_db" 2>/dev/null || true

            if [[ -f "$temp_db" ]]; then
                local usernames
                usernames=$(sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value LIKE '%@%';" 2>/dev/null | sort -u)
                while IFS= read -r email; do
                    [[ -n "$email" ]] && add_discovered_identity "$email" "edge_passwords:$profile_name"
                done <<< "$usernames"
                rm -f "$temp_db"
            fi
        fi

        ((profile_count++))
    done

    log "INFO" "Edge scan complete: $profile_count profiles scanned"
}

# Scan Firefox for identities
scan_firefox() {
    log "INFO" "Scanning Firefox..."

    local firefox_dir="$HOME/Library/Application Support/Firefox/Profiles"
    [[ ! -d "$firefox_dir" ]] && { log "DEBUG" "Firefox directory not found"; return 0; }

    # Scan all Firefox profiles
    local profile_count=0
    for profile_dir in "$firefox_dir"/*/ ; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name
        profile_name=$(basename "$profile_dir")
        log "DEBUG" "Scanning Firefox profile: $profile_name"

        # Scan logins.json for saved usernames
        local logins_json="${profile_dir}/logins.json"
        if [[ -f "$logins_json" ]]; then
            local emails
            emails=$(jq -r '.logins[].username // empty' "$logins_json" 2>/dev/null | \
                          grep -E "$EMAIL_PATTERN" | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "firefox_logins:$profile_name"
            done <<< "$emails"
        fi

        # Scan places.sqlite (history/bookmarks)
        local places_db="${profile_dir}/places.sqlite"
        if [[ -f "$places_db" ]]; then
            local temp_db="/tmp/firefox_places_$$.db"
            cp "$places_db" "$temp_db" 2>/dev/null || true

            if [[ -f "$temp_db" ]]; then
                local emails
                emails=$(sqlite3 "$temp_db" "SELECT url FROM moz_places;" 2>/dev/null | \
                              grep -oE "$EMAIL_PATTERN" | sort -u)
                while IFS= read -r email; do
                    [[ -n "$email" ]] && add_discovered_identity "$email" "firefox_history:$profile_name"
                done <<< "$emails"
                rm -f "$temp_db"
            fi
        fi

        ((profile_count++))
    done

    log "INFO" "Firefox scan complete: $profile_count profiles scanned"
}

# Scan Mail.app for account identities
