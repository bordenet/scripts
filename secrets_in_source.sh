#!/bin/bash

# Script: passhog_simple.sh
# Purpose: Scan #!/bin/bash
# Script: passhog_simple.sh
# Purpose: Scan GitHub repository clones for potential secrets in source code.
# Description: In lieu of implementing something better, like https://trufflesecurity.com/trufflehog, 
#              we can start using (and extending) this dead-simple shell script. Thus the name. 
#              Tested on MacOS terminal and iterm2. Fixes/extensions welcomed to ensure it runs on 
#              Windows and Ubuntu, et al.
# Docs: https://emachines.atlassian.net/wiki/spaces/~71202069f0ca4c20614a21b017d991e75ff720/pages/4505600001/Secrets+in+Source
# Author: Matt Bordenet
# Usage: ./passhog_simple.sh <directory_path> [-t <file_types>]
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <directory_path> [-t <file_types (list of file suffixes)>]"
  exit 1
fi

# Dependencies check -- this script was tested on MacOS
command -v grep >/dev/null 2>&1 || die "grep is required but not installed."
command -v awk >/dev/null 2>&1 || die "awk is required but not installed."

start=$(date +%s)
TARGET_DIR="$1"
shift

# Default file types to scan (PLEASE EXTEND!)
FILE_TYPES=(
  "*.js" "*.json" "*.py" "*.cs" "*.go" "*.sh" "*.tf" "*.yml" "*.yaml" "*.env" "*env" "*.ENV" "*ENV" "*.txt"
)

# Directories we don't want the tool pursuing
EXCLUDE_DIRS=(
  ".git" ".github" "node_modules" "vendor" ".idea" ".vscode"
)

# Patterns to detect secrets-- used by first screening pass
SECRET_PATTERNS_FAST=(
    "\b([A-Za-z0-9_]*PASS(WORD)?)\b[=:][\"\']?([^#\$\s\"\']+)"
    "(PASSWORD|PASS|KEY|SECRET)[=:][\"\']?([^#\$\s\"\']+)"
    "private[ _-]?key.*-----BEGIN PRIVATE KEY-----"
    "AWS[ _-]?(SECRET|ACCESS)[ _-]?(KEY)=[\"\']?([^#\$\s\"\']+)"
    'AZURE[ _-]?(CLIENT|STORAGE|SUBSCRIPTION)[ _-]?(SECRET|KEY|ID)[=:\s]\(([A-Za-z0-9]{32,})\)'
)

# Slow--but more thorough-- used by second pass (PLEASE EXTEND!)
SECRET_PATTERNS_STRICT=(
  "[Pp]assword\\s*=\\s*[^[:space:]\"']+"
  "[Pp]assword\\s*[:=]\\s*\"[^\"]*\""
  "[Pp]assword\\s*[:=]\\s*'[^']*'"

  "[_A-Z0-9]+PASSWORD\\s*=\\s*[^[:space:]\"']+"
  "[_A-Z0-9]+PASSWORD\\s*[:=]\\s*\"[^\"]*\""
  "[_A-Z0-9]+PASSWORD\\s*[:=]\\s*'[^']*'"

  "[_A-Z0-9]+PASS\\s*=\\s*[^[:space:]\"']+"
  "[_A-Z0-9]+PASS\\s*[:=]\\s*\"[^\"]*\""
  "[_A-Z0-9]+PASS\\s*[:=]\\s*'[^']*'"

  "[_A-Z0-9]+API_KEY\\s*=\\s*[^[:space:]\"']+"
  "[_A-Z0-9]+API_KEY\\s*[:=]\\s*\"[^\"]*\""
  "[_A-Z0-9]+API_KEY\\s*[:=]\\s*'[^']*'"

  "SECRET\\s*=\\s*[^[:space:]\"']+"
  "SECRET\\s*[:=]\\s*\"[^\"]*\""
  "SECRET\\s*[:=]\\s*'[^']*'"
)

EXCLUDE_PATTERNS=(
  '\${[^}]+}'                               # Matches ${VAR_NAME}
  '\$\{{[^}]+}\}'                           # Matches ${{ secrets.SOMETHING }}
  '\b(password|argocdServerAdminPassword)\s*[:=]\s*""'  # Matches password: ""
  'export\s+[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$[A-Z_]+'  # Matches export VAR=$OTHER_VAR
  'export\s+[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$\{[A-Z_]+\}'
  'export\s+[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$\(\s*cat\s+.*\s*\)'  # Matches password stored in files
  'kubectl\s+get\s+secret'                  # Matches kubectl secret retrieval
  '\b--env="[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$[A-Z_]+"'  # Match CLI --env=
  '\b--build-arg\s+[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$\(\s*yarn\s+get:[a-zA-Z0-9:_-]+\s*\)'  # Matches --build-arg in Docker
  'sed\s+-i\s+"s/^[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=.*/[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$[A-Z_]+/"'
  '^[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$[0-9]+$'
  '^[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$\(\s*echo\s+\$[A-Z_]+\s*\|\s*jq\s+--raw-output\s+.*\)$'
  '^[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$\(\s*aws\s+secretsmanager\s+get-secret-value\s+--secret-id\s+\$[A-Z_]+\s+--region\s+\$[A-Z_]+\s+--query\s+SecretString\s+--output\s+text\s*\)$'
  'sed\s+-i\s+".*PASSWORD=.*\$[A-Z_]+.*"'
  'SECRET=\$\(\s*aws\s+secretsmanager\s+get-secret-value\s+--secret-id\s+".*"\s+--output\s+text\s+--query\s+"SecretString"\s*\)'
  'kubectl\s+run\b.*--env\s+[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$[A-Z_]+'
  'docker\s+build\b.*--build-arg\s+[A-Z_]*(KEY|PASS|PASSWORD|TOKEN|SECRET)=\$\(\s*yarn\s+get:[a-zA-Z0-9:_-]+\s*\)'
)

# ANSI color codes -- feel free to customize
LIGHT_BLUE='\033[1;34m'
BRIGHT_RED='\033[1;31m'
DARK_RED='\033[0;31m'
DARK_GRAY='\033[0;90m'
RESET='\033[0m'
CURSOR_UP='\033[1A' # Move cursor up one line
CURSOR_HOME='\033[0G' # Move cursor to beginning of line
ERASE_LINE='\033[2K' # Erase current line

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

# Validate the directory
if [ ! -d "$TARGET_DIR" ]; then
  echo "Error: Directory '$TARGET_DIR' does not exist."
  exit 1
fi

# Count total number of top-level directories
TOTAL_DIRS=$(find "$TARGET_DIR" -maxdepth 1 -type d | wc -l)
TOTAL_DIRS=$((TOTAL_DIRS - 1)) # Subtract 1 to exclude the target directory itself

# Create temporary file for directory counter
DIR_COUNT_FILE="$(mktemp)"
trap 'rm -f "$DIR_COUNT_FILE"' EXIT
echo 0 > "$DIR_COUNT_FILE"

# Function to handle errors
die() {
  echo "[ERROR] $1"
  exit 1
}

# Function to draw progress bar
draw_progress_bar() {
  local percentage=$1
  local width=50
  local filled=$((percentage * width / 100))
  local empty=$((width - filled))
  
  printf "["
  printf "%${filled}s" | tr ' ' '='
  printf "%${empty}s" | tr ' ' ' '
  printf "] %d%%" "$percentage"
}

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

print_banner_line() {
  printf "${DARK_GRAY}═══════════════════════════════════════════════════════════════════════════════${RESET}\n"
}

print_summary_banner() {
  local total_secrets=$1
  local runtime=$2
  
  print_banner_line
  printf "${DARK_GRAY}║${RESET} PASSHOG SCAN SUMMARY ${DARK_GRAY}║${RESET}\n"
  print_banner_line
  printf "${DARK_GRAY}║${RESET} Total Secrets Detected: ${DARK_RED}%-43d${RESET}${DARK_GRAY}║${RESET}\n" "$total_secrets"
  printf "${DARK_GRAY}║${RESET} Scan Duration: %-50s${DARK_GRAY}║${RESET}\n" "$(format_time $runtime)"
  printf "${DARK_GRAY}║${RESET} Timestamp: %-52s${DARK_GRAY}║${RESET}\n" "$(date '+%Y-%m-%d %H:%M:%S')"
  print_banner_line
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
  estimated_time=""
  
  # Calculate estimated time after processing N directories
  if [ "$dirs_processed" -ge 10 ]; then
    current_time=$(date +%s)
    elapsed_time=$((current_time - start))
    time_per_dir=$((elapsed_time / dirs_processed))
    remaining_dirs=$((TOTAL_DIRS - dirs_processed))
    estimated_seconds=$((time_per_dir * remaining_dirs))
    if [ "$estimated_seconds" -ge 1 ]; then
      estimated_time=" \n Est. remaining: $(format_time $estimated_seconds)"
    fi
  fi
  
  # Only show progress bar if there are more than 20 directories
  if [ "$TOTAL_DIRS" -gt 20 ]; then
    percentage=$((dirs_processed * 100 / TOTAL_DIRS))
    clear && printf "${CURSOR_UP}${CURSOR_HOME}${ERASE_LINE}Directories: ${LIGHT_BLUE}${dirs_processed}/${TOTAL_DIRS}${RESET} \n Secrets: ${BRIGHT_RED}${secrets_found}${RESET}${DARK_GRAY}${estimated_time}${RESET}\n"
    printf "${CURSOR_HOME}${ERASE_LINE}Progress: "
    draw_progress_bar "$percentage"
    printf "\n"
  else
    clear && printf "${CURSOR_UP}${CURSOR_HOME}${ERASE_LINE}Directories: ${LIGHT_BLUE}${dirs_processed}/${TOTAL_DIRS}${RESET} \n Secrets detected: ${BRIGHT_RED}${secrets_found}${RESET}${DARK_GRAY}${estimated_time}${RESET}\r\n"
  fi
}

#
# Function to scan a file for secrets
#
scan_file() {
    local file="$1"
    local secrets_found_in_file=false
 
    # First pass -- scan the file (fast)
    for pattern in "${SECRET_PATTERNS_FAST[@]}"; do
        possible_match=false
        grep -Eno ".*($pattern.*)" "$file" | while IFS= read -r match; do

            # Second pass -- run match through stricter filter (slow)
            for pattern_strict in "${SECRET_PATTERNS_STRICT[@]}"; do
              if echo "$match" | grep -qE "$pattern_strict"; then
                  possible_match=true
                  break
              fi
            done

            if [[ $possible_match ]]; then
                  # Check exclusions
                  for exclude_pattern in "${EXCLUDE_PATTERNS[@]}"; do
                    if [[ possible_match ]] && echo "$match" | grep -qE "$exclude_pattern"; then
                      possible_match=false
                      break
                    fi
                  done
            fi
 
            if [[ $possible_match == true ]]; then
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

# Construct the find command for file types -- first pass
construct_find_command() {
    local find_expr=""
    for file_type in "${FILE_TYPES[@]}"; do
        find_expr+=" -name \"$file_type\" -o"
    done
    # Remove the trailing -o
    find_expr=${find_expr% -o}
    echo "$find_expr"
}

export -f scan_file update_status format_time
export COUNT_FILE DIR_COUNT_FILE TOTAL_DIRS
export RESULTS_FILE start end
export LIGHT_BLUE BRIGHT_RED DARK_RED DARK_GRAY RESET
export CURSOR_UP CURSOR_HOME ERASE_LINE
export SECRET_PATTERNS_FAST SECRET_PATTERNS_STRICT EXCLUDE_PATTERNS
export EXCLUDE_DIRS

# Process files in the root search directory
find_expr=$(construct_find_command)
# For root directory scan:
eval "find \"$TARGET_DIR\" -maxdepth 1 $find_expr 2>/dev/null" | while read -r file; do
  printf "\r${ERASE_LINE}Scanning: ${LIGHT_BLUE}$file${RESET}"
  scan_file "$file"
done

# Process subdirectories
find -P "$TARGET_DIR" -maxdepth 1 -type d | while read -r dir; do
    if [ "$dir" != "$TARGET_DIR" ]; then
        dirs_processed=$(($(cat "$DIR_COUNT_FILE") + 1))
        echo "$dirs_processed" > "$DIR_COUNT_FILE"
        update_status
         
        find_expr=$(construct_find_command)
        eval "find -P \"$dir\" -type f \( $find_expr \) 2>/dev/null" | while read -r file; do
            printf "\r${ERASE_LINE}Scanning: ${LIGHT_BLUE}$file${RESET}"
            scan_file "$file"
        done
    fi
done

printf "\n"
end=$(date +%s)
runtime=$((end - start))
total_secrets=$(cat "$COUNT_FILE")
print_summary_banner "$total_secrets" "$runtime"
printf "\n"

# Report detailed findings
if [ -s "$RESULTS_FILE" ]; then
  # Create the log file name
  log_file_friendly_name="${script_name}-${timestamp}.log"
  temp_file=$(mktemp)
  temp_dir=$(dirname "$temp_file")
  friendly_transcript_file_name="$(basename "$0")_$(date +%s).txt"
  friendly_transcript_path="$temp_dir/$friendly_transcript_file_name"
  mv "$temp_file" "$friendly_transcript_path"
  printf "$0 results\nRun by: $(whoami)\nDate: $(date "+%A, %B %d, %Y")\n" >> "$friendly_transcript_path"
  printf "Execution time: $runtime seconds\nTotal secrets: $total_secrets\n\n" >> "$friendly_transcript_path"
  cat $RESULTS_FILE >> "$friendly_transcript_path"
  log_info "Detailed findings:"
  echo ""
  while IFS= read -r line; do
    file=$(echo "$line" | cut -d ':' -f 1)
    match=$(echo "$line" | cut -d ':' -f 2-)
    line_number=$(echo "$match" | cut -d ':' -f 1)
    match_content=$(echo "$match" | cut -d ':' -f 2-)
    printf "${LIGHT_BLUE}$file${DARK_GRAY}:$line_number${RESET}: $match_content\n"
  done < "$RESULTS_FILE"
  printf "\n\n\n${BRIGHT_RED}Transcript available: $friendly_transcript_path${RESET}"
  printf "\n\n${DARK_GRAY}Suggestion: this will make the text more readable ${RESET}sed 's/\\x1b\\[[0-9;]*[mG]//g' $friendly_transcript_path > ./human_readable.txt"
  printf "\n ${DARK_GRAY}Just don't leave it lying around, or it will get picked up in subsequent runs of the tool!${CLEAR}"
elif [[ $total_secrets -eq 0 ]]; then
  log_info "No secrets detected in the specified directory."
fi

exit 0
