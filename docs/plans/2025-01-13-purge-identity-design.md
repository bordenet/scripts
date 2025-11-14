# Identity Purge Tool - Design Document

**Document Version:** 1.0
**Date:** 2025-01-13
**Status:** Design Phase
**Implementation Target:** Shell script (bash), pivot to Go if complexity exceeds maintainability threshold

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Module Design](#module-design)
3. [Data Structures](#data-structures)
4. [Discovery Engine](#discovery-engine)
5. [Deletion Engine](#deletion-engine)
6. [User Interface](#user-interface)
7. [Error Handling](#error-handling)
8. [Security & Safety](#security--safety)
9. [Testing Strategy](#testing-strategy)
10. [Implementation Roadmap](#implementation-roadmap)

---

## Architecture Overview

### High-Level Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        STARTUP                               │
│  - Parse arguments (--what-if, --verbose)                   │
│  - Initialize logging                                        │
│  - Cleanup old logs (>24hrs)                                │
│  - Display header with timer                                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                   DISCOVERY PHASE                            │
│  - Scan keychain for email patterns                         │
│  - Scan browsers (Safari, Chrome, Edge, Firefox)            │
│  - Scan Mail.app accounts                                   │
│  - Scan Application Support comprehensively                 │
│  - Scan SSH keys/config                                     │
│  - Scan Internet Accounts                                   │
│  - Deduplicate and sort results                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    MENU DISPLAY                              │
│  - Show numbered list of identities                         │
│  - Option to add manual identity                            │
│  - If --what-if: exit here                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                  USER SELECTION                              │
│  - Parse input (single, multi-select, range, "all")         │
│  - Validate selection                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│            PER-IDENTITY PROCESSING LOOP                      │
│                                                              │
│  For each selected identity:                                │
│    1. Deep scan for all traces                              │
│    2. Generate detailed preview                             │
│    3. Display preview with warnings                         │
│    4. Prompt for confirmation                               │
│    5. If confirmed: execute deletion                        │
│    6. Collect errors                                        │
│    7. Move to next identity                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│                    EXIT REPORT                               │
│  - Total execution time                                      │
│  - Summary of deletions per identity                        │
│  - Error section with actionable remediation                │
│  - Log file path                                            │
└─────────────────────────────────────────────────────────────┘
```

### Modular Design

The script will be organized into logical modules (functions):

**Core Modules:**
- `main()` - Entry point, orchestration
- `init_logging()` - Set up logging, cleanup old logs
- `parse_arguments()` - Handle command-line flags
- `display_header()` - Show banner, start timer
- `update_timer()` - Background timer update (every 5s)

**Discovery Modules:**
- `discover_all_identities()` - Orchestrate all discovery functions
- `scan_keychain()` - Extract emails from keychain
- `scan_browsers()` - Scan Safari, Chrome, Edge, Firefox
- `scan_mail()` - Scan Mail.app accounts
- `scan_application_support()` - Deep scan of Application Support
- `scan_ssh()` - Scan SSH keys and config
- `scan_internet_accounts()` - Scan system Internet Accounts
- `scan_cloud_storage()` - Scan OneDrive, Google Drive configs

**Menu & Selection Modules:**
- `display_menu()` - Show numbered identity list
- `parse_selection()` - Parse user input (multi-select, ranges)
- `add_manual_identity()` - Prompt for custom identity

**Preview Modules:**
- `generate_preview()` - Deep scan for specific identity
- `display_preview()` - Format and show preview
- `check_warnings()` - Identify one-way door operations

**Deletion Modules:**
- `delete_identity()` - Orchestrate deletion for one identity
- `delete_keychain_items()` - Remove keychain entries
- `delete_browser_data()` - Handle browser profiles/data
- `delete_mail_account()` - Remove Mail.app account and mailbox
- `delete_app_support_data()` - Remove application-specific data
- `delete_ssh_data()` - Remove SSH keys and config entries
- `delete_cloud_storage_config()` - Remove cloud storage accounts
- `delete_internet_account()` - Remove system Internet Account

**Safety & Utility Modules:**
- `require_sudo()` - Smart privilege escalation
- `check_browser_running()` - Detect running browsers
- `prompt_quit_app()` - Ask to quit application
- `is_preserved_file()` - Check if file should never be touched
- `log()` - Write to log file
- `error_handler()` - Collect and format errors
- `display_exit_report()` - Final summary

---

## Module Design

### 1. Initialization Module

**Function:** `init_logging()`

**Purpose:** Set up logging infrastructure and cleanup old logs.

**Implementation:**
```bash
init_logging() {
    local log_dir="/tmp"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    LOG_FILE="${log_dir}/purge-identity-${timestamp}.log"

    # Create log file
    touch "$LOG_FILE"
    log "INFO" "Purge Identity Tool started"
    log "INFO" "Command: $0 $*"

    # Cleanup old logs (>24 hours)
    find "$log_dir" -name "purge-identity-*.log" -mtime +1 -delete 2>/dev/null

    # Set up trap for cleanup on exit
    trap 'cleanup_on_exit' EXIT
}
```

**Function:** `parse_arguments()`

**Purpose:** Parse command-line flags.

**Implementation:**
```bash
parse_arguments() {
    WHAT_IF_MODE=false
    VERBOSE_MODE=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --what-if)
                WHAT_IF_MODE=true
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -h|--help)
                display_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                display_help
                exit 1
                ;;
        esac
    done
}
```

### 2. Timer Module

**Function:** `start_timer()`

**Purpose:** Display and maintain running timer in top-right corner.

**Implementation:**
```bash
# Global timer variables
START_TIME=$(date +%s)
TIMER_PID=""

start_timer() {
    START_TIME=$(date +%s)

    # Background timer update process
    (
        while true; do
            update_timer_display
            sleep 5
        done
    ) &

    TIMER_PID=$!
}

update_timer_display() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))

    # ANSI escape codes
    local YELLOW='\033[0;33m'
    local NC='\033[0m'
    local SAVE_CURSOR='\033[s'
    local RESTORE_CURSOR='\033[u'
    local MOVE_TO_TOP_RIGHT='\033[1;60H'  # Line 1, column 60

    printf "${SAVE_CURSOR}${MOVE_TO_TOP_RIGHT}${YELLOW}[Elapsed: %02d:%02d:%02d]${NC}${RESTORE_CURSOR}" \
        "$hours" "$minutes" "$seconds"
}

stop_timer() {
    if [[ -n "$TIMER_PID" ]]; then
        kill "$TIMER_PID" 2>/dev/null
    fi
}

get_elapsed_time() {
    local current_time=$(date +%s)
    local elapsed=$((current_time - START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
}
```

---

## Data Structures

### Identity Record

Each discovered identity is stored as an associative array (or JSON in Go version):

```bash
# Bash approach: Use indexed arrays with conventions
# identity_emails[0]="matt.bordenet@telepathy.ai"
# identity_counts[0]=47
# identity_locations[0]="keychain:3,safari:12,chrome:1,mail:1,..."

# Go approach (if we pivot):
type Identity struct {
    Email      string
    TotalCount int
    Locations  map[string]int  // category -> count
}
```

### Preview Data

For detailed preview before deletion:

```bash
# Bash approach: Global arrays populated by generate_preview()
declare -A PREVIEW_KEYCHAIN
declare -A PREVIEW_BROWSERS
declare -A PREVIEW_MAIL
declare -A PREVIEW_APP_SUPPORT
declare -A PREVIEW_SSH
declare -A PREVIEW_WARNINGS

# Example:
# PREVIEW_KEYCHAIN["passwords"]=3
# PREVIEW_KEYCHAIN["certificates"]=1
# PREVIEW_WARNINGS[0]="Large mailbox: 2.3GB will be deleted"
```

### Error Collection

Errors collected during execution:

```bash
# Global arrays
declare -a ERROR_MESSAGES
declare -a ERROR_REMEDIATION

# Example:
# ERROR_MESSAGES[0]="Chrome profile locked"
# ERROR_REMEDIATION[0]="Close Chrome and run: rm -rf ~/Library/Application Support/Google/Chrome/Profile 2"
```

---

## Discovery Engine

### Email Pattern Matching

**Regular expression for email detection:**
```bash
EMAIL_PATTERN='[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'
```

**Strategy:**
- Use `grep -E` with pattern across text files
- Use `security dump-keychain` and parse output for keychain
- Use `sqlite3` for browser databases
- Use `plutil -convert json` for plist files, then `jq` for parsing

### Keychain Discovery

**Function:** `scan_keychain()`

**Implementation:**
```bash
scan_keychain() {
    log "INFO" "Scanning keychain for identities..."

    # May need sudo for some operations
    require_sudo_if_needed "keychain access"

    # Dump keychain and extract emails
    local keychain_dump=$(security dump-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null)

    # Extract email addresses from dump
    local emails=$(echo "$keychain_dump" | grep -oE "$EMAIL_PATTERN" | sort -u)

    # Store in global discovery array
    while IFS= read -r email; do
        [[ -n "$email" ]] && add_discovered_identity "$email" "keychain"
    done <<< "$emails"

    log "INFO" "Keychain scan complete"
}
```

### Browser Discovery

**Function:** `scan_browsers()`

**Strategy:**
- Detect browser profile directories
- Parse `Preferences` JSON files for sync emails
- Parse `Login Data` SQLite databases for saved usernames
- Parse cookies databases for domains

**Implementation (Safari example):**
```bash
scan_safari() {
    log "INFO" "Scanning Safari..."

    local safari_dir="$HOME/Library/Safari"

    # Check if Safari data exists
    [[ ! -d "$safari_dir" ]] && return

    # Scan cookies database
    local cookies_db="${safari_dir}/Cookies/Cookies.binarycookies"
    if [[ -f "$cookies_db" ]]; then
        # Use cfurl to extract domains from binarycookies
        # (macOS-specific binary format)
        local domains=$(strings "$cookies_db" | grep -oE "$EMAIL_PATTERN" | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "safari_cookies"
        done <<< "$domains"
    fi

    # Scan saved passwords (Keychain integration)
    # Safari uses Keychain, already covered in scan_keychain()

    log "INFO" "Safari scan complete"
}
```

**Implementation (Chrome example):**
```bash
scan_chrome() {
    log "INFO" "Scanning Chrome..."

    local chrome_dir="$HOME/Library/Application Support/Google/Chrome"

    [[ ! -d "$chrome_dir" ]] && return

    # Iterate through profiles
    for profile_dir in "$chrome_dir"/*/; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name=$(basename "$profile_dir")
        log "DEBUG" "Scanning Chrome profile: $profile_name"

        # Parse Preferences JSON for sync email
        local prefs="${profile_dir}/Preferences"
        if [[ -f "$prefs" ]]; then
            local sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ -n "$sync_email" ]] && add_discovered_identity "$sync_email" "chrome_profile:$profile_name"
        fi

        # Parse Login Data (SQLite) for saved usernames
        local login_db="${profile_dir}/Login Data"
        if [[ -f "$login_db" ]]; then
            # Copy to temp (file might be locked)
            local temp_db="/tmp/chrome_login_$$.db"
            cp "$login_db" "$temp_db" 2>/dev/null

            if [[ -f "$temp_db" ]]; then
                local usernames=$(sqlite3 "$temp_db" "SELECT username_value FROM logins WHERE username_value LIKE '%@%';" 2>/dev/null | sort -u)
                while IFS= read -r email; do
                    [[ -n "$email" ]] && add_discovered_identity "$email" "chrome_saved_password:$profile_name"
                done <<< "$usernames"
                rm -f "$temp_db"
            fi
        fi
    done

    log "INFO" "Chrome scan complete"
}
```

### Mail.app Discovery

**Function:** `scan_mail()`

**Implementation:**
```bash
scan_mail() {
    log "INFO" "Scanning Mail.app accounts..."

    local mail_dir="$HOME/Library/Mail"

    # Find Mail version directory (V9, V10, etc.)
    local mail_version_dir=$(find "$mail_dir" -maxdepth 1 -type d -name "V*" | sort -r | head -n 1)

    [[ ! -d "$mail_version_dir" ]] && return

    local accounts_plist="${mail_version_dir}/MailData/Accounts.plist"

    if [[ -f "$accounts_plist" ]]; then
        # Convert plist to JSON and extract email addresses
        local accounts_json=$(plutil -convert json -o - "$accounts_plist" 2>/dev/null)
        local emails=$(echo "$accounts_json" | jq -r '.. | .EmailAddresses? // empty | .[]' 2>/dev/null | sort -u)

        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "mail_account"
        done <<< "$emails"
    fi

    log "INFO" "Mail.app scan complete"
}
```

### Application Support Discovery

**Function:** `scan_application_support()`

**Strategy:**
- Comprehensive scan of `~/Library/Application Support/`
- Focus on known identity-storing apps (whitelist)
- Also do broad search for email patterns

**Implementation:**
```bash
scan_application_support() {
    log "INFO" "Scanning Application Support (this may take a moment)..."

    local app_support="$HOME/Library/Application Support"

    # Whitelist of known apps to check specifically
    local known_apps=(
        "Microsoft"
        "com.microsoft.Office"
        "com.microsoft.Teams"
        "com.microsoft.OneDrive"
        "Slack"
        "Discord"
        "Zoom"
        "Code"  # VS Code
    )

    # Scan known apps
    for app in "${known_apps[@]}"; do
        local app_dir="${app_support}/${app}"
        [[ ! -d "$app_dir" ]] && continue

        log "DEBUG" "Scanning ${app}..."
        scan_directory_for_emails "$app_dir" "app_support:$app"
    done

    # Broad scan for other apps (limit depth to avoid performance issues)
    log "DEBUG" "Performing broad Application Support scan..."

    # Search .plist, .json, .sqlite files for email patterns
    find "$app_support" -maxdepth 3 \( -name "*.plist" -o -name "*.json" \) -type f 2>/dev/null | while read -r file; do
        # Skip preserved files
        is_preserved_file "$file" && continue

        # Extract emails from file
        local emails=$(strings "$file" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "app_support:$(basename "$(dirname "$file")")"
        done <<< "$emails"
    done

    log "INFO" "Application Support scan complete"
}

scan_directory_for_emails() {
    local dir="$1"
    local source_label="$2"

    # Use find + strings to extract emails from various file types
    find "$dir" -type f \( -name "*.plist" -o -name "*.json" -o -name "*.db" -o -name "*.sqlite" \) 2>/dev/null | while read -r file; do
        is_preserved_file "$file" && continue

        local emails=$(strings "$file" 2>/dev/null | grep -oE "$EMAIL_PATTERN" | sort -u)
        while IFS= read -r email; do
            [[ -n "$email" ]] && add_discovered_identity "$email" "$source_label"
        done <<< "$emails"
    done
}
```

### SSH Discovery

**Function:** `scan_ssh()`

**Implementation:**
```bash
scan_ssh() {
    log "INFO" "Scanning SSH keys and config..."

    local ssh_dir="$HOME/.ssh"
    [[ ! -d "$ssh_dir" ]] && return

    # Scan public keys for email comments
    find "$ssh_dir" -name "*.pub" -type f 2>/dev/null | while read -r pubkey; do
        # Public keys often end with email as comment
        local comment=$(tail -c 200 "$pubkey" | grep -oE "$EMAIL_PATTERN")
        [[ -n "$comment" ]] && add_discovered_identity "$comment" "ssh_key:$(basename "$pubkey")"
    done

    # Scan SSH config for host entries with company domains
    local ssh_config="${ssh_dir}/config"
    if [[ -f "$ssh_config" ]]; then
        # Extract host entries (could contain company identifiers)
        # This is more heuristic - look for Host entries that match known domains
        # Will be more useful in deletion phase
        log "DEBUG" "SSH config found, will check during deletion phase"
    fi

    log "INFO" "SSH scan complete"
}
```

### Internet Accounts Discovery

**Function:** `scan_internet_accounts()`

**Implementation:**
```bash
scan_internet_accounts() {
    log "INFO" "Scanning Internet Accounts..."

    local accounts_dir="$HOME/Library/Accounts"
    [[ ! -d "$accounts_dir" ]] && return

    # Accounts are stored in Accounts3.sqlite
    local accounts_db="${accounts_dir}/Accounts3.sqlite"

    if [[ -f "$accounts_db" ]]; then
        local temp_db="/tmp/accounts_$$.db"
        cp "$accounts_db" "$temp_db" 2>/dev/null

        if [[ -f "$temp_db" ]]; then
            # Extract account identifiers (username column)
            local accounts=$(sqlite3 "$temp_db" "SELECT ZUSERNAME FROM ZACCOUNT WHERE ZUSERNAME LIKE '%@%';" 2>/dev/null | sort -u)
            while IFS= read -r email; do
                [[ -n "$email" ]] && add_discovered_identity "$email" "internet_account"
            done <<< "$accounts"
            rm -f "$temp_db"
        fi
    fi

    log "INFO" "Internet Accounts scan complete"
}
```

### Discovery Orchestration

**Function:** `discover_all_identities()`

**Implementation:**
```bash
discover_all_identities() {
    display_section_header "Scanning for identities"

    # Initialize global arrays
    declare -g -A DISCOVERED_IDENTITIES  # email -> total count
    declare -g -A IDENTITY_LOCATIONS     # email -> "location1:count1,location2:count2,..."

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

    # Deduplicate and sort
    local total_found=${#DISCOVERED_IDENTITIES[@]}
    log "INFO" "Discovery complete: $total_found unique identities found"

    return 0
}

add_discovered_identity() {
    local email="$1"
    local location="$2"

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
```

---

## Deletion Engine

### Keychain Deletion

**Function:** `delete_keychain_items()`

**Implementation:**
```bash
delete_keychain_items() {
    local identity="$1"
    local deleted_count=0

    log "INFO" "Deleting keychain items for $identity"

    # Require sudo for keychain operations
    require_sudo "keychain deletion"

    # Find and delete internet passwords
    while IFS= read -r item; do
        [[ -z "$item" ]] && continue

        # Parse security output to extract service and account
        local service=$(echo "$item" | awk -F'"' '/svce/ {print $4}')
        local account=$(echo "$item" | awk -F'"' '/acct/ {print $4}')

        if security delete-internet-password -s "$service" -a "$account" 2>/dev/null; then
            log "INFO" "Deleted internet password: $service ($account)"
            ((deleted_count++))
        else
            add_error "Failed to delete keychain item: $service ($account)" \
                      "Manually delete in Keychain Access.app"
        fi
    done < <(security dump-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null | \
             grep -B 4 "$identity" | grep "keychain:")

    # Find and delete generic passwords
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue

        if security delete-generic-password -s "$service" -a "$identity" 2>/dev/null; then
            log "INFO" "Deleted generic password: $service"
            ((deleted_count++))
        fi
    done < <(security dump-keychain ~/Library/Keychains/login.keychain-db 2>/dev/null | \
             grep -A 4 "$identity" | grep "svce" | awk -F'"' '{print $4}')

    # Find and delete certificates
    local certs=$(security find-certificate -a -c "$identity" ~/Library/Keychains/login.keychain-db 2>/dev/null | \
                  grep "SHA-1 hash:" | awk '{print $3}')

    while IFS= read -r cert_hash; do
        [[ -z "$cert_hash" ]] && continue

        if security delete-certificate -Z "$cert_hash" 2>/dev/null; then
            log "INFO" "Deleted certificate: $cert_hash"
            ((deleted_count++))
        fi
    done <<< "$certs"

    log "INFO" "Keychain deletion complete: $deleted_count items removed"
    return $deleted_count
}
```

### Browser Profile Deletion

**Function:** `delete_browser_data()`

**Strategy:**
- Detect which browsers are running
- Prompt to quit if necessary
- Delete entire profiles associated with identity
- For shared profiles (Default), selectively delete identity-specific data

**Implementation (Chrome example):**
```bash
delete_chrome_data() {
    local identity="$1"
    local deleted_count=0

    log "INFO" "Deleting Chrome data for $identity"

    # Check if Chrome is running
    if pgrep -x "Google Chrome" > /dev/null; then
        if ! prompt_quit_app "Google Chrome"; then
            add_error "Chrome is running" "Quit Chrome and manually delete profiles"
            return 1
        fi
    fi

    local chrome_dir="$HOME/Library/Application Support/Google/Chrome"

    # Scan profiles for association with identity
    for profile_dir in "$chrome_dir"/*/; do
        [[ ! -d "$profile_dir" ]] && continue

        local profile_name=$(basename "$profile_dir")
        local prefs="${profile_dir}/Preferences"

        # Check if profile is associated with identity
        local is_associated=false

        if [[ -f "$prefs" ]]; then
            # Check sync email
            local sync_email=$(jq -r '.account_info[0].email // empty' "$prefs" 2>/dev/null)
            [[ "$sync_email" == "$identity" ]] && is_associated=true

            # Check profile name contains identity
            [[ "$profile_name" =~ $identity ]] && is_associated=true
        fi

        if [[ "$is_associated" == true ]]; then
            # Warn before deleting profile
            local profile_size=$(du -sh "$profile_dir" 2>/dev/null | awk '{print $1}')

            if confirm_deletion "Chrome profile '$profile_name' ($profile_size)"; then
                if rm -rf "$profile_dir"; then
                    log "INFO" "Deleted Chrome profile: $profile_name"
                    ((deleted_count++))
                else
                    add_error "Failed to delete Chrome profile: $profile_name" \
                              "Manually delete: rm -rf \"$profile_dir\""
                fi
            else
                log "INFO" "Skipped Chrome profile: $profile_name"
            fi
        fi
    done

    return $deleted_count
}
```

### Mail Account Deletion

**Function:** `delete_mail_account()`

**Implementation:**
```bash
delete_mail_account() {
    local identity="$1"
    local deleted_count=0

    log "INFO" "Deleting Mail account for $identity"

    # Check if Mail is running
    if pgrep -x "Mail" > /dev/null; then
        if ! prompt_quit_app "Mail"; then
            add_error "Mail.app is running" "Quit Mail and re-run script"
            return 1
        fi
    fi

    local mail_dir="$HOME/Library/Mail"
    local mail_version_dir=$(find "$mail_dir" -maxdepth 1 -type d -name "V*" | sort -r | head -n 1)

    [[ ! -d "$mail_version_dir" ]] && return 0

    local accounts_plist="${mail_version_dir}/MailData/Accounts.plist"

    if [[ -f "$accounts_plist" ]]; then
        # Convert to JSON
        local accounts_json=$(plutil -convert json -o - "$accounts_plist" 2>/dev/null)

        # Find account ID for identity
        local account_id=$(echo "$accounts_json" | jq -r --arg email "$identity" \
            '.Accounts[] | select(.EmailAddresses[]? == $email) | .AccountID' 2>/dev/null)

        if [[ -n "$account_id" ]]; then
            # Find mailbox directory
            local mailbox_dir="${mail_version_dir}/${account_id}"

            if [[ -d "$mailbox_dir" ]]; then
                local mailbox_size=$(du -sh "$mailbox_dir" 2>/dev/null | awk '{print $1}')

                # Warn about mailbox deletion
                if confirm_deletion "Mail account with ${mailbox_size} of data (PERMANENT)"; then
                    # Remove mailbox directory
                    if rm -rf "$mailbox_dir"; then
                        log "INFO" "Deleted mailbox: $mailbox_dir ($mailbox_size)"
                        ((deleted_count++))
                    else
                        add_error "Failed to delete mailbox" \
                                  "Manually delete: rm -rf \"$mailbox_dir\""
                    fi

                    # Remove account from Accounts.plist
                    # This is complex - need to edit plist
                    # Easier to use PlistBuddy
                    local account_index=$(echo "$accounts_json" | jq -r --arg email "$identity" \
                        '[.Accounts[]] | to_entries | .[] | select(.value.EmailAddresses[]? == $email) | .key' 2>/dev/null)

                    if [[ -n "$account_index" ]]; then
                        /usr/libexec/PlistBuddy -c "Delete :Accounts:$account_index" "$accounts_plist" 2>/dev/null
                        log "INFO" "Removed account from Accounts.plist"
                    fi
                else
                    log "INFO" "Skipped Mail account deletion"
                fi
            fi
        fi
    fi

    return $deleted_count
}
```

### Application Support Deletion

**Function:** `delete_app_support_data()`

**Strategy:**
- For known apps (Microsoft Office, Slack, Teams), use specific deletion logic
- For other apps, generic file/directory deletion based on identity string

**Implementation (Microsoft Office example):**
```bash
delete_office_data() {
    local identity="$1"

    log "INFO" "Checking Microsoft Office data for $identity"

    local office_group_container="$HOME/Library/Group Containers/UBF8T346G9.Office"
    local office_containers="$HOME/Library/Containers/com.microsoft"

    # Check if Office data exists for this identity
    local has_office_data=false

    if [[ -d "$office_group_container" ]]; then
        if grep -r "$identity" "$office_group_container" >/dev/null 2>&1; then
            has_office_data=true
        fi
    fi

    if [[ "$has_office_data" == true ]]; then
        # Offer surgical vs. full reset
        echo ""
        echo "Microsoft Office data found for $identity"
        echo ""
        echo "Options:"
        echo "  1) Surgical removal (attempt to remove only this identity)"
        echo "  2) Full Office reset (remove ALL Office identity/license data)"
        echo "  3) Skip Office deletion"
        echo ""
        read -p "Choose option [1/2/3]: " office_choice

        case $office_choice in
            1)
                # Surgical - try to find and delete identity-specific files
                log "INFO" "Attempting surgical Office identity removal"
                # This is complex and might not be fully effective
                # Search for plist/json files containing identity
                find "$office_group_container" -type f \( -name "*.plist" -o -name "*.json" \) 2>/dev/null | while read -r file; do
                    if grep -q "$identity" "$file" 2>/dev/null; then
                        log "INFO" "Found identity in: $file"
                        # Could try to edit plist, but safer to just report
                        add_error "Office file contains identity: $(basename "$file")" \
                                  "Manually review and edit: $file"
                    fi
                done
                ;;
            2)
                # Full reset
                if confirm_deletion "ALL Office identity/license data (requires re-activation)"; then
                    log "INFO" "Performing full Office reset"

                    # Remove Office identity data
                    rm -rf "$office_group_container" 2>/dev/null
                    find "$HOME/Library/Containers" -name "com.microsoft.*" -type d -exec rm -rf {} + 2>/dev/null

                    # Remove Office preferences
                    find "$HOME/Library/Preferences" -name "com.microsoft.*.plist" -delete 2>/dev/null

                    log "INFO" "Office reset complete"
                else
                    log "INFO" "Skipped Office reset"
                fi
                ;;
            3)
                log "INFO" "Skipped Office deletion"
                ;;
            *)
                log "WARN" "Invalid choice, skipping Office"
                ;;
        esac
    fi
}
```

---

## User Interface

### ANSI Color Definitions

```bash
# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[0;37m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'  # No Color

# Symbols
readonly CHECK_MARK="${GREEN}✓${NC}"
readonly CROSS_MARK="${RED}✗${NC}"
readonly ARROW="${CYAN}→${NC}"
```

### Display Functions

**Function:** `display_section_header()`

```bash
display_section_header() {
    local title="$1"
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $title${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo ""
}
```

**Function:** `display_menu()`

```bash
display_menu() {
    display_section_header "Found Identities"

    # Sort identities by count (descending)
    local sorted_identities=()
    while IFS= read -r email; do
        sorted_identities+=("$email")
    done < <(for email in "${!DISCOVERED_IDENTITIES[@]}"; do
        echo "${DISCOVERED_IDENTITIES[$email]} $email"
    done | sort -rn | awk '{print $2}')

    # Display numbered list
    local index=1
    for email in "${sorted_identities[@]}"; do
        local count=${DISCOVERED_IDENTITIES[$email]}
        printf "%3d) %-50s ${YELLOW}(%d locations)${NC}\n" "$index" "$email" "$count"
        ((index++))
    done

    echo ""
    echo "  m) Manually add identity"
    echo "  q) Quit"
    echo ""
}
```

**Function:** `display_preview()`

```bash
display_preview() {
    local identity="$1"

    display_section_header "Preview: $identity"

    # Keychain section
    if [[ ${PREVIEW_KEYCHAIN["total"]} -gt 0 ]]; then
        echo -e "${BOLD}Keychain:${NC}"
        [[ ${PREVIEW_KEYCHAIN["passwords"]} -gt 0 ]] && \
            echo "  • ${PREVIEW_KEYCHAIN["passwords"]} passwords"
        [[ ${PREVIEW_KEYCHAIN["certificates"]} -gt 0 ]] && \
            echo "  • ${PREVIEW_KEYCHAIN["certificates"]} certificates"
        [[ ${PREVIEW_KEYCHAIN["keys"]} -gt 0 ]] && \
            echo "  • ${PREVIEW_KEYCHAIN["keys"]} private keys"
        echo ""
    fi

    # Browsers section
    if [[ ${PREVIEW_BROWSERS["total"]} -gt 0 ]]; then
        echo -e "${BOLD}Browsers:${NC}"
        for browser_item in "${PREVIEW_BROWSERS[@]}"; do
            echo "  • $browser_item"
        done
        echo ""
    fi

    # Mail section
    if [[ ${PREVIEW_MAIL["exists"]} == "true" ]]; then
        echo -e "${BOLD}Mail:${NC}"
        echo "  • Account config + ${PREVIEW_MAIL["size"]} mailbox ${RED}(PERMANENT)${NC}"
        echo ""
    fi

    # Application Support section
    if [[ ${#PREVIEW_APP_SUPPORT[@]} -gt 0 ]]; then
        echo -e "${BOLD}Application Support:${NC}"
        for app_item in "${PREVIEW_APP_SUPPORT[@]}"; do
            echo "  • $app_item"
        done
        echo ""
    fi

    # SSH section
    if [[ ${#PREVIEW_SSH[@]} -gt 0 ]]; then
        echo -e "${BOLD}SSH:${NC}"
        for ssh_item in "${PREVIEW_SSH[@]}"; do
            echo "  • $ssh_item"
        done
        echo ""
    fi

    # Warnings section
    if [[ ${#PREVIEW_WARNINGS[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}WARNINGS:${NC}"
        for warning in "${PREVIEW_WARNINGS[@]}"; do
            echo -e "  ${RED}⚠${NC}  $warning"
        done
        echo ""
    fi
}
```

### Progress Indicators

**Function:** `show_progress()`

```bash
show_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    local status="$4"  # "scanning", "deleting", "done"

    local bar_width=40
    local progress=$((current * bar_width / total))
    local percentage=$((current * 100 / total))

    printf "\r[%3d/%3d] %-30s " "$current" "$total" "$task"

    case $status in
        scanning)
            printf "${YELLOW}scanning...${NC}"
            ;;
        deleting)
            printf "${RED}deleting...${NC}"
            ;;
        done)
            printf "${GREEN}✓${NC}"
            ;;
    esac
}
```

---

## Error Handling

### Error Collection

```bash
# Global error tracking
declare -a ERROR_MESSAGES
declare -a ERROR_REMEDIATION

add_error() {
    local message="$1"
    local remediation="$2"

    ERROR_MESSAGES+=("$message")
    ERROR_REMEDIATION+=("$remediation")

    log "ERROR" "$message - Remediation: $remediation"
}
```

### Exit Report

**Function:** `display_exit_report()`

```bash
display_exit_report() {
    stop_timer
    local elapsed=$(get_elapsed_time)

    display_section_header "Purge Complete"

    echo -e "${BOLD}Total time:${NC} $elapsed"
    echo ""

    # Summary of deletions
    if [[ ${#DELETION_SUMMARY[@]} -gt 0 ]]; then
        echo -e "${BOLD}Deleted:${NC}"
        for identity in "${!DELETION_SUMMARY[@]}"; do
            echo "  $identity: ${DELETION_SUMMARY[$identity]} items"
        done
        echo ""
    fi

    # Errors section
    if [[ ${#ERROR_MESSAGES[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}ERRORS (${#ERROR_MESSAGES[@]}):${NC}"
        for i in "${!ERROR_MESSAGES[@]}"; do
            local num=$((i + 1))
            echo -e "  ${RED}$num.${NC} ${ERROR_MESSAGES[$i]}"
            echo "     ${ARROW} ${ERROR_REMEDIATION[$i]}"
            echo ""
        done
    else
        echo -e "${GREEN}No errors encountered${NC}"
        echo ""
    fi

    # Log file reference
    echo -e "${BOLD}Log:${NC} $LOG_FILE"
    echo ""
}
```

---

## Security & Safety

### File Preservation Check

**Function:** `is_preserved_file()`

```bash
is_preserved_file() {
    local file_path="$1"

    # Never touch .psafe3 files
    [[ "$file_path" =~ \.psafe3$ ]] && return 0

    # Never touch .git directories
    [[ "$file_path" =~ /\.git/ ]] && return 0

    # Never touch cloud storage file directories (but configs are OK)
    if [[ "$file_path" =~ /CloudStorage/ ]]; then
        # Preserve files in OneDrive-*, GoogleDrive-*, etc.
        [[ "$file_path" =~ /CloudStorage/(OneDrive|GoogleDrive|Dropbox)-[^/]+/ ]] && return 0
    fi

    # Not preserved
    return 1
}
```

### Sudo Management

**Function:** `require_sudo()`

```bash
require_sudo() {
    local reason="$1"

    if ! sudo -n true 2>/dev/null; then
        echo ""
        echo -e "${YELLOW}Requesting elevated privileges for: $reason${NC}"
        echo ""
        sudo -v
    fi

    # Keep sudo alive in background
    (
        while true; do
            sudo -n true
            sleep 50
        done
    ) &

    SUDO_KEEPALIVE_PID=$!
}

cleanup_sudo() {
    [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
}
```

### Confirmation Prompts

**Function:** `confirm_deletion()`

```bash
confirm_deletion() {
    local item_description="$1"

    echo ""
    echo -e "${RED}WARNING:${NC} About to delete: $item_description"
    read -p "Continue? [y/N]: " response

    [[ "$response" =~ ^[Yy]$ ]] && return 0
    return 1
}
```

**Function:** `prompt_quit_app()`

```bash
prompt_quit_app() {
    local app_name="$1"

    echo ""
    echo -e "${YELLOW}$app_name is running and will block deletion.${NC}"
    read -p "Quit $app_name now? [y/N]: " response

    if [[ "$response" =~ ^[Yy]$ ]]; then
        osascript -e "quit app \"$app_name\"" 2>/dev/null
        sleep 2

        # Verify app actually quit
        if pgrep -x "$app_name" > /dev/null; then
            echo -e "${RED}$app_name did not quit${NC}"
            return 1
        fi
        return 0
    fi

    return 1
}
```

---

## Testing Strategy

### Unit Testing (for Go version)

If we pivot to Go, use standard Go testing:

```go
// Test email pattern matching
func TestExtractEmails(t *testing.T) {
    input := "Contact: matt.bordenet@telepathy.ai or admin@example.com"
    expected := []string{"matt.bordenet@telepathy.ai", "admin@example.com"}

    result := extractEmails(input)

    if !reflect.DeepEqual(result, expected) {
        t.Errorf("Expected %v, got %v", expected, result)
    }
}

// Test file preservation logic
func TestIsPreservedFile(t *testing.T) {
    tests := []struct {
        path     string
        expected bool
    }{
        {"/Users/test/Documents/passwords.psafe3", true},
        {"/Users/test/Projects/repo/.git/config", true},
        {"/Users/test/Library/CloudStorage/OneDrive-Personal/file.txt", true},
        {"/Users/test/Library/Preferences/com.example.plist", false},
    }

    for _, tt := range tests {
        result := isPreservedFile(tt.path)
        if result != tt.expected {
            t.Errorf("isPreservedFile(%s) = %v, expected %v", tt.path, result, tt.expected)
        }
    }
}
```

### Integration Testing

**Manual test plan:**

1. **Discovery testing:**
   - Create test accounts in Keychain, browsers, Mail.app
   - Run with `--what-if`
   - Verify all test identities discovered

2. **Deletion testing (on test VM):**
   - Run full deletion on test identity
   - Verify all traces removed
   - Verify preserved files untouched
   - Check error handling

3. **Safety testing:**
   - Test with running browsers (should prompt)
   - Test with locked keychain (should handle gracefully)
   - Test with permission denied scenarios

4. **Edge cases:**
   - Empty Mail.app (no accounts)
   - No Safari/Chrome/Edge installed
   - Identity that doesn't exist anywhere (should handle gracefully)

---

## Implementation Roadmap

### Phase 1: Core Infrastructure (Days 1-2)

- [ ] Set up script structure with modular functions
- [ ] Implement logging system
- [ ] Implement argument parsing
- [ ] Implement timer system
- [ ] Implement ANSI color/display functions
- [ ] Test basic flow with stub functions

### Phase 2: Discovery Engine (Days 3-5)

- [ ] Implement keychain scanning
- [ ] Implement Safari scanning
- [ ] Implement Chrome scanning
- [ ] Implement Edge scanning
- [ ] Implement Firefox scanning
- [ ] Implement Mail.app scanning
- [ ] Implement Application Support scanning (basic)
- [ ] Implement SSH scanning
- [ ] Implement Internet Accounts scanning
- [ ] Test discovery with real data

### Phase 3: Menu & Selection (Day 6)

- [ ] Implement menu display
- [ ] Implement selection parsing (single, multi, range)
- [ ] Implement manual identity entry
- [ ] Test user interaction flows

### Phase 4: Preview System (Day 7)

- [ ] Implement deep scan for specific identity
- [ ] Implement preview data collection
- [ ] Implement preview display
- [ ] Implement warning detection
- [ ] Test preview accuracy

### Phase 5: Deletion Engine (Days 8-12)

- [ ] Implement keychain deletion
- [ ] Implement Safari deletion
- [ ] Implement Chrome/Edge/Firefox deletion
- [ ] Implement Mail.app deletion
- [ ] Implement Application Support deletion
- [ ] Implement Microsoft Office handling
- [ ] Implement SSH deletion
- [ ] Implement Internet Accounts deletion
- [ ] Implement cloud storage config deletion
- [ ] Test deletion (on VM!)

### Phase 6: Safety & Error Handling (Days 13-14)

- [ ] Implement file preservation checks
- [ ] Implement browser process detection/quit
- [ ] Implement sudo management
- [ ] Implement confirmation prompts
- [ ] Implement error collection
- [ ] Test error scenarios

### Phase 7: Polish & Testing (Days 15-17)

- [ ] Implement exit report
- [ ] Comprehensive testing on test VM
- [ ] Performance optimization
- [ ] Code cleanup and commenting
- [ ] Documentation

### Phase 8: Go Migration (If Needed)

**Trigger:** Script exceeds 1000 lines or performance issues

- [ ] Set up Go project structure
- [ ] Port core logic to Go
- [ ] Implement TUI with lipgloss/bubbles
- [ ] Port all discovery functions
- [ ] Port all deletion functions
- [ ] Add comprehensive testing
- [ ] Build and distribute binary

---

## Go Implementation Design (If Needed)

### Project Structure

```
purge-identity/
├── cmd/
│   └── purge-identity/
│       └── main.go
├── internal/
│   ├── discovery/
│   │   ├── keychain.go
│   │   ├── browsers.go
│   │   ├── mail.go
│   │   ├── appsupport.go
│   │   └── ssh.go
│   ├── deletion/
│   │   ├── keychain.go
│   │   ├── browsers.go
│   │   ├── mail.go
│   │   └── appsupport.go
│   ├── ui/
│   │   ├── menu.go
│   │   ├── preview.go
│   │   ├── progress.go
│   │   └── report.go
│   ├── models/
│   │   └── identity.go
│   └── utils/
│       ├── logging.go
│       ├── safety.go
│       └── sudo.go
├── go.mod
└── README.md
```

### Key Dependencies

```go
require (
    github.com/charmbracelet/bubbles v0.16.1
    github.com/charmbracelet/bubbletea v0.24.2
    github.com/charmbracelet/lipgloss v0.9.1
    github.com/spf13/cobra v1.8.0
    github.com/mattn/go-sqlite3 v1.14.18
)
```

### TUI with Bubble Tea

```go
package ui

import (
    "github.com/charmbracelet/bubbles/list"
    tea "github.com/charmbracelet/bubbletea"
    "github.com/charmbracelet/lipgloss"
)

type model struct {
    identities []Identity
    list       list.Model
    selected   map[int]bool
    timer      time.Time
}

func (m model) Init() tea.Cmd {
    return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
    switch msg := msg.(type) {
    case tea.KeyMsg:
        switch msg.String() {
        case "q", "ctrl+c":
            return m, tea.Quit
        case " ":
            // Toggle selection
            idx := m.list.Index()
            m.selected[idx] = !m.selected[idx]
        }
    }

    var cmd tea.Cmd
    m.list, cmd = m.list.Update(msg)
    return m, cmd
}

func (m model) View() string {
    // Render with lipgloss styling
    return lipgloss.JoinVertical(
        lipgloss.Left,
        headerStyle.Render("Found Identities"),
        m.list.View(),
        timerStyle.Render(formatElapsed(time.Since(m.timer))),
    )
}
```

---

## File Naming Convention

**Script name:** `purge-identity.sh` (bash version) or `purge-identity` (Go binary)

**Log files:** `/tmp/purge-identity-YYYYMMDD-HHMMSS.log`

**Config file (future):** `~/.purge-identities.conf`

---

## Performance Considerations

### Expected Performance

**Discovery phase:**
- Keychain: < 5 seconds
- Browsers: < 10 seconds
- Mail.app: < 2 seconds
- Application Support: 30-60 seconds (depends on size)
- SSH: < 1 second
- Total discovery: 1-2 minutes typical

**Deletion phase:**
- Keychain: < 10 seconds
- Browsers: < 30 seconds
- Mail: < 10 seconds
- Application Support: varies
- Total deletion: 1-3 minutes typical

### Optimization Strategies

**For bash:**
- Use `find` with `-maxdepth` to limit recursion
- Use `grep -m 1` when only first match needed
- Parallelize independent scans with background jobs
- Cache results to avoid re-scanning

**For Go (if we pivot):**
- Use goroutines for parallel scanning
- Use worker pools for directory traversal
- Implement progress streaming for real-time feedback
- Use efficient data structures (maps for deduplication)

---

## Security Considerations

### Sensitive Data Handling

**Logging:**
- Log identity strings (they're being deleted anyway)
- DO NOT log keychain passwords or certificate contents
- DO NOT log SSH private keys
- Log file permissions: 600 (owner read/write only)

**Temporary files:**
- Use secure temp directory (`/tmp` with unique names)
- Clean up temp files on exit (trap handler)
- Never write sensitive data to temp files

### Privilege Escalation

**Sudo usage:**
- Only request when necessary
- Clear messaging about why sudo is needed
- Time-limited (keep-alive with 50s refresh)
- Clean up sudo keep-alive on exit

---

## Error Recovery

### Partial Failure Handling

**Strategy:** Continue on error, collect all errors, report at end

**Example scenario:**
1. Delete keychain items: SUCCESS (3 items)
2. Delete Safari data: SUCCESS
3. Delete Chrome profile: FAILED (browser running)
4. Delete Mail account: SUCCESS
5. Script continues to next identity
6. Exit report shows Chrome failure with remediation

**Rationale:** User can manually fix failures and re-run script to clean up remaining items.

---

## Maintenance & Evolution

### Adding New Discovery Locations

To add support for a new application:

1. Create `scan_<appname>()` function
2. Add call to `discover_all_identities()`
3. Update `delete_app_support_data()` with app-specific logic
4. Test discovery and deletion
5. Update documentation

### Handling macOS Updates

When macOS changes paths or formats:

1. Update path constants at top of script
2. Update database schema queries if needed
3. Test on new macOS version
4. Document version compatibility

---

## Documentation Plan

### User-Facing Documentation

**README.md:**
- Quick start guide
- What the tool does (and doesn't do)
- Safety warnings
- Usage examples
- Troubleshooting common errors

**Inline help:**
- `--help` flag with full usage
- Examples of multi-select syntax

### Developer Documentation

**Code comments:**
- Function headers with purpose, parameters, return values
- Complex logic explained inline
- External dependencies documented

**This design document:**
- Comprehensive reference for implementation
- Rationale for design decisions
- Future extension points

---

## Success Metrics

### Functional Success

- [ ] Discovers >95% of identity traces across common apps
- [ ] Deletes all discovered traces without system breakage
- [ ] Handles errors gracefully (no crashes)
- [ ] Provides actionable error messages for manual fixes

### User Experience Success

- [ ] What-if mode builds user confidence
- [ ] Multi-select reduces repetitive work
- [ ] Progress indicators show activity (not stuck)
- [ ] Exit report provides closure and next steps

### Code Quality Success

- [ ] Well-commented and maintainable
- [ ] Modular design allows easy extension
- [ ] Comprehensive error handling
- [ ] Follows shell scripting best practices (or Go best practices)

---

**End of Design Document**
