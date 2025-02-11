#!/bin/bash

# Script: passhog_simple.sh
# Purpose: Scan GitHub repository clones for potential secrets in source code.
# Description: In lieu of implementing something better, like https://trufflesecurity.com/trufflehog, 
#              you can use (and extend) this dead-simple shell script. Thus the name. 
#
#              PRs welcome!
#
#              Tested on MacOS terminal and iterm2. Fixes/extensions welcomed to ensure it runs on 
#              Windows and Ubuntu, et al.
# Author: Matt Bordenet
# Usage: ./passhog_simple.sh <directory_path>

# Ensure the script is run with at least one argument
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <directory_path>"
    exit 1
fi

start=$(date +%s)
TARGET_DIR="$1"

# ANSI color codes 
LIGHT_BLUE='\033[1;34m'
BRIGHT_RED='\033[1;31m'
DARK_RED='\033[0;31m'
DARK_GRAY='\033[0;90m'
RESET='\033[0m'
CURSOR_UP='\033[1A'      # Move cursor up one line
CURSOR_HOME='\033[0G'    # Move cursor to beginning of line
ERASE_LINE='\033[2K'     # Erase current line

# Validate the directory
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

# Function to handle errors
die() {
    echo "[ERROR] $1"
    exit 1
}

# Dependencies check
command -v grep >/dev/null 2>&1 || die "grep is required but not installed."
command -v awk >/dev/null 2>&1 || die "awk is required but not installed."

# Logging function
log_info() {
    echo -e "${DARK_GRAY}[INFO] $1${RESET}"
}

log_info_red() {
    echo -e "${DARK_RED}[INFO] $1${RESET}"
}

log_error_red() {
    printf "${BRIGHT_RED}[ERROR] %s${RESET}\n" "$1" # Print error on a new line
}

# Status update
log_info "Starting secrets scan in directory: $TARGET_DIR"

# Temporary file for results
RESULTS_FILE="$(mktemp)"
trap 'rm -f "$RESULTS_FILE"' EXIT

# Temporary file for secret count
COUNT_FILE="$(mktemp)"
trap 'rm -f "$COUNT_FILE"' EXIT
echo 0 > "$COUNT_FILE"

# Patterns to detect secrets (PLEASE EXTEND!)
SECRET_PATTERNS=(
    "(PASSWORD|PASS|RABBITMQ_DEFAULT_PASS|POSTGRES_PASSWORD)=[\"\']?([^#\$\s\"\']+)"  # No $ or empty value
    "AWS[ _-]?(SECRET|ACCESS)[ _-]?(KEY)=[\"\']?([^#\$\s\"\']+)"  # No $ or empty value
    'AZURE[ _-]?(CLIENT|STORAGE|SUBSCRIPTION)[ _-]?(SECRET|KEY|ID)[=:\s]\(([A-Za-z0-9]{32,})\)'
    "(KEY|SECRET|PASSWORD)=[\"\']?([^#\$\s\"\']+)"  # No $ or empty value
    "private[ _-]?key.*-----BEGIN PRIVATE KEY-----"
)

# Exclude patterns to avoid false positives
EXCLUDE_PATTERNS=(
    "Azure Key Vault"
)

# Function to update the secrets count display
update_secret_count() {
    secrets_found=$(cat "$COUNT_FILE")
    clear && printf "${CURSOR_UP}${CURSOR_HOME}${ERASE_LINE}Number of secrets detected: ${BRIGHT_RED}${secrets_found}${RESET}\r\n"
}

# Function to scan a file for secrets
scan_file() {
    local file="$1"
    local secrets_found_in_file=false

    for pattern in "${SECRET_PATTERNS[@]}"; do
        grep -Eo "$pattern" "$file" | while IFS= read -r match; do
            exclude_match=false
            for exclude_pattern in "${EXCLUDE_PATTERNS[@]}"; do
                if [[ "$match" =~ $exclude_pattern ]]; then
                    exclude_match=true
                    break
                fi
            done

            if ! $exclude_match; then
                secret_value=$(echo "$match" | cut -d '=' -f 2-)
                secret_value="${secret_value//[\"\']}"

                if [[ "$secret_value" != "" && ! "$secret_value" =~ ^\$ && ! "$secret_value" =~ = ]]; then
                    printf "${LIGHT_BLUE}$file:${match} (Value: ${BRIGHT_RED}$secret_value${LIGHT_BLUE})${RESET}\n" >> "$RESULTS_FILE" # Newline here
                    secrets_found_in_file=true
                    secrets_found=$(($(cat "$COUNT_FILE") + 1))
                    echo "$secrets_found" > "$COUNT_FILE"  # Update the secret count in the file
                    update_secret_count  # Update the displayed count
                fi
            fi
        done
    done

    if $secrets_found_in_file; then
        log_info_red "SECRETS DETECTED IN $file!"
    fi
}

export -f scan_file
export COUNT_FILE
export RESULTS_FILE
export LIGHT_BLUE
export BRIGHT_RED
export DARK_RED
export DARK_GRAY
export RESET
export CURSOR_UP
export CURSOR_HOME
export ERASE_LINE
export SECRET_PATTERNS
export EXCLUDE_PATTERNS

# PLEASE EXTEND range of files scanned. These ones were the most obvious
find "$TARGET_DIR" -type f \( -name "*.js" -o -name "*.py" -o -name "*.cs" -o -name "*env" -o -name "*.go"  \
    -o -name "*.sh" -o -name "*.yml" -o -name "*.yaml" -o -name "*.json" -o -name "ENV" \) 2>/dev/null | while read -r file; do
    printf "\rScanning: ${LIGHT_BLUE}$file${RESET}"
    scan_file "$file"
done

echo "" # Final newline

end=$(date +%s)
echo -e $(date)" | Done ${GRAY} Elapsed Time: $(($end-$start)) seconds ${WHITE}"

if [ -s "$RESULTS_FILE" ]; then
    log_info "Potential secrets found in the following files:"
    cat "$RESULTS_FILE"
elif [[ $(cat "$COUNT_FILE") -eq 0 ]]; then # Corrected conditional
    log_info "No secrets detected in the specified directory."
fi

exit 0
