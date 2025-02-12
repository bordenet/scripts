#!/bin/bash

# Script: passhog_simple.sh
# Purpose: Scan GitHub repository clones for potential secrets in source code.
# Description: In lieu of implementing something better, like https://trufflesecurity.com/trufflehog, 
#              we can start using (and extending) this dead-simple shell script. Thus the name. 
#              Tested on MacOS terminal and iterm2. Fixes/extensions welcomed to ensure it runs on 
#              Windows and Ubuntu, et al.
# Docs: https://emachines.atlassian.net/wiki/spaces/~71202069f0ca4c20614a21b017d991e75ff720/pages/4505600001/Secrets+in+Source
# Author: Matt Bordenet
# Usage: ./passhog_simple.sh <directory_path> [-t <file_types>]

# Ensure the script is run with at least one argument
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <directory_path> [-t <file_types (list of file suffixes)>]"
    exit 1
fi

start=$(date +%s)
TARGET_DIR="$1"
shift

# Default file types to scan
FILE_TYPES=(
    "*.js"
    "*.py"
    "*.cs"
    "*env"
    "*ENV"
    "*.go"
    "*.sh"
    "*.yml"
    "*.yaml"
    "*.json"
    "tf"
)

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -t|--types)
            IFS=',' read -r -a extensions <<< "$2"
            FILE_TYPES=()
            for ext in "${extensions[@]}"; do
                FILE_TYPES+=("*.$ext")
            done
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

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

# Count total number of top-level directories
TOTAL_DIRS=$(find "$TARGET_DIR" -maxdepth 1 -type d | wc -l)
TOTAL_DIRS=$((TOTAL_DIRS - 1))  # Subtract 1 to exclude the target directory itself

# Create temporary file for directory counter
DIR_COUNT_FILE="$(mktemp)"
trap 'rm -f "$DIR_COUNT_FILE"' EXIT
echo 0 > "$DIR_COUNT_FILE"

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
    printf "${BRIGHT_RED}[ERROR] %s${RESET}\n" "$1"
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
    "(PASSWORD|PASS|RABBITMQ_DEFAULT_PASS|POSTGRES_PASSWORD)=[\"\']?([^#\$\s\"\']+)"
    "AWS[ _-]?(SECRET|ACCESS)[ _-]?(KEY)=[\"\']?([^#\$\s\"\']+)"
    'AZURE[ _-]?(CLIENT|STORAGE|SUBSCRIPTION)[ _-]?(SECRET|KEY|ID)[=:\s]\(([A-Za-z0-9]{32,})\)'
    "(KEY|SECRET|PASSWORD)=[\"\']?([^#\$\s\"\']+)"
    "private[ _-]?key.*-----BEGIN PRIVATE KEY-----"
)

# Exclude patterns to avoid false positives
EXCLUDE_PATTERNS=(
    "Azure Key Vault"
)

# Function to format time in minutes and seconds
format_time() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    printf "%02d:%02d" $minutes $remaining_seconds
}

# Function to update the status display
update_status() {
    secrets_found=$(cat "$COUNT_FILE")
    dirs_processed=$(cat "$DIR_COUNT_FILE")
    extimated_time=""
    # Calculate estimated time after processing N directories
    if [ "$dirs_processed" -ge 10 ]; then
        current_time=$(date +%s)
        elapsed_time=$((current_time - start))
        time_per_dir=$((elapsed_time / dirs_processed))
        remaining_dirs=$((TOTAL_DIRS - dirs_processed))
        estimated_seconds=$((time_per_dir * remaining_dirs))
        if [ "$estimated_seconds" -ge 1 ]; then
            estimated_time=" | Est. remaining: $(format_time $estimated_seconds)"
        fi
    fi
    
    clear && printf "${CURSOR_UP}${CURSOR_HOME}${ERASE_LINE}Directories: ${LIGHT_BLUE}${dirs_processed}/${TOTAL_DIRS}${RESET} | Secrets detected: ${BRIGHT_RED}${secrets_found}${RESET}${DARK_GRAY}${estimated_time}${RESET}\r\n"
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
                    printf "${LIGHT_BLUE}$file:${match} (Value: ${BRIGHT_RED}$secret_value${LIGHT_BLUE})${RESET}\n" >> "$RESULTS_FILE"
                    secrets_found_in_file=true
                    secrets_found=$(($(cat "$COUNT_FILE") + 1))
                    echo "$secrets_found" > "$COUNT_FILE"
                    update_status
                fi
            fi
        done
    done

    if $secrets_found_in_file; then
        log_info_red "SECRETS DETECTED IN $file!"
    fi
}

export -f scan_file update_status format_time
export COUNT_FILE DIR_COUNT_FILE TOTAL_DIRS
export RESULTS_FILE start
export LIGHT_BLUE BRIGHT_RED DARK_RED DARK_GRAY RESET
export CURSOR_UP CURSOR_HOME ERASE_LINE
export SECRET_PATTERNS EXCLUDE_PATTERNS

find_expr=""

# Construct the find command for file types
construct_find_command() {
    local find_expr=""
    for file_type in "${FILE_TYPES[@]}"; do
        find_expr+=" -name \"$file_type\" -o"
    done
    # Remove the trailing -o
    find_expr=${find_expr% -o}
    echo "$find_expr"
}

# Process each top-level directory separately to track progress
find "$TARGET_DIR" -maxdepth 1 -type d | while read -r dir; do
    if [ "$dir" != "$TARGET_DIR" ]; then
        dirs_processed=$(($(cat "$DIR_COUNT_FILE") + 1))
        echo "$dirs_processed" > "$DIR_COUNT_FILE"
        update_status
        
        find_expr=$(construct_find_command)
        eval "find \"$dir\" -type f \( $find_expr \) 2>/dev/null" | while read -r file; do
            printf "\r${ERASE_LINE}Scanning: ${LIGHT_BLUE}$file${RESET}"
            scan_file "$file"
        done
    fi
done

# Process files in the root directory -- focus on git repos
find "$TARGET_DIR" -maxdepth 1 -type f \( -name ".git" \) 2>/dev/null | while read -r file; do
    printf "\rScanning: ${LIGHT_BLUE}$file${RESET}"
    scan_file "$file"
done

echo ""

end=$(date +%s)
runtime=$((end - start))
echo -e $(date)" | Done ${DARK_GRAY} Elapsed Time: $runtime seconds ${RESET}"

if [ -s "$RESULTS_FILE" ]; then
    log_info "Potential secrets found in the following files:"
    cat "$RESULTS_FILE"
elif [[ $(cat "$COUNT_FILE") -eq 0 ]]; then
    log_info "No secrets detected in the specified directory."
fi

exit 0
