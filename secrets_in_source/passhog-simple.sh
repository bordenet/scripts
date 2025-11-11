#!/bin/bash
#
# Script: passhog-simple.sh
# Description: This script performs a simplified scan for sensitive information
#              (e.g., passwords, API keys) within files in a specified directory.
#              It uses 'grep' with predefined patterns to identify potential secrets.
# Platform: Cross-platform
# Usage: ./passhog-simple.sh <directory> [--dry-run]
# Arguments:
#   <directory>: The path to the directory to scan for secrets.
#   --dry-run: Optional. Perform a dry run without taking any action,
#              just showing what would be scanned.
# Dependencies: grep
#


echo "This script is deprecated and no longer maintained."
echo "Please use the successor project: https://github.com/bordenet/secrets-in-source"
exit 1

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <directory_path> [-t <file_suffixes>]"
  echo "Example 1: $0 . -t sh,yml,yaml"
  echo "Example 2: $0 ."
  exit 1
fi

# Dependencies check -- this script was tested on MacOS
command -v grep >/dev/null 2>&1 || die "grep is required but not installed."
command -v awk >/dev/null 2>&1 || die "awk is required but not installed."

start=$(date +%s)
TARGET_DIR="$1"
shift

# Default file types to scan (PLEASE EXTEND!)
FILE_TYPES=("*.js" "*.json" "*.py" "*.cs" "*.go" "*.sh" "*.tf" "*.yml" "*.yaml" "*.env" "*env" "*.ENV" "*ENV")

# Directories we do not want the tool traversing
EXCLUDE_DIRS=(".git" ".github" "node_modules" "vendor" ".idea" ".vscode" "stella_deploy" "secrets_in_source")

# Patterns to detect secrets-- used by first screening pass
SECRET_PATTERNS_FAST_EXPANDED=(
  "(PASS|PASSWORD|pass|password|KEY|SECRET|pwd)[:=][0-9a-zA-Z]+"
  "(PASS|PASSWORD|pass|password|KEY|SECRET|pwd)(:|=).*)"
  "\b([A-Za-z0-9_]*PASS(WORD)?)\b[=:][\"']?([^#\$\\s\"']+)"
  "(PASSWORD|PASS|KEY|SECRET)\s[=:][\"']?([^#\$\\s\"']+)"
  "private[ _-]?key.*-----BEGIN PRIVATE KEY-----"
  "AWS[ _-]? (SECRET|ACCESS)[ _-]?(KEY)=[\"']?([^#\$\\s\"']+)"
  "AZURE[ _-]?(CLIENT|STORAGE|SUBSCRIPTION)[ _-]?(SECRET|KEY|ID)[=:\s]\(([A-Za-z0-9]{32,})\)"
  "AWS_SECRET_ACCESS_KEY=[^[:space:]]+"  # Added pattern to match AWS_SECRET_ACCESS_KEY
)

# Slow--but more thorough-- used by second pass (PLEASE EXTEND!)
SECRET_PATTERNS_STRICT_EXPANDED=(
  "(PASS|PASSWORD|pass|password|KEY|SECRET|pwd)[:=][0-9a-zA-Z]+"
  "(PASS|PASSWORD|pass|password|KEY|SECRET|pwd)(:|=).*)"
  "\b([A-Za-z0-9_]*PASS(WORD)?)\b[=:][\"']?([^#\$\\s\"']+)"
  "(PASSWORD|PASS|KEY|SECRET)\s[=:][\"']?([^#\$\\s\"']+)"
  "private[ _-]?key.*-----BEGIN PRIVATE KEY-----"
  "AWS[ _-]?(SECRET|ACCESS)[ _-]?(KEY)=[\"']?([^#\$\\s\"']+)"
  "AZURE[ _-]?(CLIENT|STORAGE|SUBSCRIPTION)[ _-]?(SECRET|KEY|ID)[=:\s]\(([A-Za-z0-9]{32,})\)"
  ".*[_A-Z0-9]+PASS(WORD)\\s*=\\s*[^[:space:]\"']+.*"
  "[Pp]assword\\s*=\\s*[^[:space:]\"']+"
  "[Pp]assword\\s*[:=]\\s*\"[^\"]*\""
  "[Pp]assword\\s*[:=]\\s*'[^']*'"
  "[_A-Z0-9]+PASS(WORD)\\s*=\\s*[^[:space:]\"']+"
  "[_A-Z0-9]+PASS(WORD)\\s*[:=]\\s*\"[^\"]*\""
  "[_A-Z0-9]+PASS(WORD)\\s*[:=]\\s*'[^']*'"
  "[_A-Z0-9]+API_KEY\\s*=\\s*[^[:space:]\"']+"
  "[_A-Z0-9]+API_KEY\\s*[:=]\\s*\"[^\"]*\""
  "[_A-Z0-9]+API_KEY\\s*[:=]\\s*'[^']*'"
  "SECRET\\s*=\\s*[^[:space:]\"']+"
  "SECRET\\s*[:=]\\s*\"[^\"]*\""
  "SECRET\\s*[:=]\\s*'[^']*'"
  "AWS_SECRET_ACCESS_KEY=[^[:space:]]+"  # Added pattern to match AWS_SECRET_ACCESS_KEY
)

EXCLUDE_PATTERNS_EXPANDED=(
  ':\s*\$\{[^}]+\}'
  '\$\{[^}]+\}'                               # Matches ${VAR_NAME}
  '(PASS|PASSWORD|pass|password|KEY|SECRET):\s*str\s*=\s*None\)\:' # FP01
  'password\s*=\s*"\$' # FP49 -- first attempt
  'password\s*=\s*"\$[A-Za-z_][A-Za-z_0-9]*"' # FP49   TODO: FIX BUGBUG
  'HIDDEN' # FP48
  '\{\{[^\{\}]*\}\}|\{[^\{\}]*\}|\[\[[^\[\]]*\]\]|\[[^\[\]]*\]'  # FP41
  '(KEY|PASS|PASSWORD|TOKEN|SECRET)\s*[:=]\s*\$' #FP22, FP27, FP28, FP44
  '(pass|password|PASS|PASSWORD)\s*[:=]\s*([\'"'\"]{2})$'  # FP10, FP46
  'PASS\s*:\s*A\s*[a-z]+\s*can\s*be' # FP02
  '(KEY\s*=\s*[a-z\[]*\s*)?\(Value:' # FP03, FP04
  'pwd\s*=\s*getpass\.getpass\(' # FP05
  'Settings\s+take\s+the\s+form\s+KEY=VALUE\.' # FP42
  'password\s*=\s*get_pwd\(\)' # FP50
  'getpass\(prompt="tl\s+password:\s*"\)' # FP51
  'password\s*=\s*ENV\["'
  '(KEY|PASS|PASSWORD|TOKEN|SECRETpass|password).*getenv' # FP53  TODO: FIX BUGBUG
  '(pass|password|pwd|PWD|controller-client-secret)\=(REDISPW|REDIS_PW|REDIS_PASSWORD|CONTROLLER_PASSWORD)' # FP54
  'PASS\s*:\s*[A-Z][a-zA-Z]*\s+[a-zA-Z\s]{6,}' # FP57
  'password=\\\"\$[A-Z_]+' # FP58, FP59
  'password=self\.TEST_CONFIGURATION' # FP60
)

# Combine patterns into a single regex
combine_patterns() {
    local IFS="|"
    printf "%s" "$*"
}

# Combine regex patterns for speed
SECRET_PATTERN_FAST=$(combine_patterns "${SECRET_PATTERNS_FAST_EXPANDED[@]}")
SECRET_PATTERN_STRICT=$(combine_patterns "${SECRET_PATTERNS_STRICT_EXPANDED[@]}")
EXCLUDE_PATTERN=$(combine_patterns "${EXCLUDE_PATTERNS_EXPANDED[@]}")

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
  
  printf "${LIGHT_BLUE}[${RESET}"
  printf "${LIGHT_BLUE}%${filled}s${RESET}" | tr ' ' '='
  printf "%${empty}s" | tr ' ' ' '
  printf "${LIGHT_BLUE}]${RESET} %d%%" "$percentage"
}

# Logging function
log_info() { echo -e "${DARK_GRAY}[INFO] $1${RESET}"
}
log_info_red() {  echo -e "${DARK_RED}[INFO] $1${RESET}"
}
log_error_red() { printf "${BRIGHT_RED}[ERROR] %s${RESET}\n" "$1"
}
print_banner_line() {  printf "${DARK_GRAY}═══════════════════════════════════════════════════════════════════════════════${RESET}\n"
}

print_summary_banner() {
  local total_secrets=$1
  local runtime=$2
  local banner_width=79  # Adjust this value if needed to match the width of the banner line

  printf "${ERASE_LINE}${CURSOR_UP}${ERASE_LINE}${CURSOR_UP}${ERASE_LINE}${CURSOR_UP}${ERASE_LINE}"
  print_banner_line
  printf "${DARK_GRAY}║${RESET} PASSHOG SCAN SUMMARY ${DARK_GRAY}║${RESET}\n"
  print_banner_line

  # Print Total Secrets Detected line
  printf "${DARK_GRAY}║${RESET} Total Secrets Detected: ${DARK_RED}%d${RESET}" "$total_secrets"
  printf "\033[%dG${DARK_GRAY}║${RESET}\n" "$banner_width"

  # Print Scan Duration line
  printf "${DARK_GRAY}║${RESET} Scan Duration: %-50s" "$(format_time $runtime)"
  printf "\033[%dG${DARK_GRAY}║${RESET}\n" "$banner_width"

  # Print Timestamp line
  printf "${DARK_GRAY}║${RESET} Timestamp: %-52s" "$(date '+%Y-%m-%d %H:%M:%S')"
  printf "\033[%dG${DARK_GRAY}║${RESET}\n" "$banner_width"

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
  estimated_time="Estimating time remaining..."
  elapsed_time="Processing..."

  # Calculate estimated time after processing 20 directories -- sufficient to ascertain a guess
  if [ "$dirs_processed" -ge 20 ]; then
    current_time=$(date +%s)
    elapsed_seconds=$((current_time - start))
    elapsed_time="Elapsed: $(format_time $elapsed_seconds)"
    if [ "$dirs_processed" -gt 0 ]; then
      time_per_dir=$((elapsed_seconds / dirs_processed))
    else
      time_per_dir=0
    fi
    remaining_dirs=$((TOTAL_DIRS - dirs_processed))
    if [ "$remaining_dirs" -gt 0 ]; then
      estimated_seconds=$((time_per_dir * remaining_dirs))
    else
      estimated_seconds=0
    fi
    if [ "$estimated_seconds" -ge 1 ]; then
      estimated_time=" Remaining: $(format_time $estimated_seconds)"
    fi
  fi

  # Only show progress bar if there are more than 20 directories
  if [ "$TOTAL_DIRS" -gt 20 ]; then
    percentage=$((dirs_processed * 100 / TOTAL_DIRS))
    clear && printf "${CURSOR_UP}${CURSOR_HOME}${ERASE_LINE}Directories: ${LIGHT_BLUE}${dirs_processed}/${TOTAL_DIRS}${RESET} 	 Possible Secrets: ${BRIGHT_RED}${secrets_found}${RESET}${DARK_GRAY}	 ${elapsed_time}	${RESET}|${DARK_GRAY} ${estimated_time}${RESET}\n"
    printf "${CURSOR_HOME}${ERASE_LINE}Progress:    "
    draw_progress_bar "$percentage"
    printf "\n"
  else
    clear && printf "${CURSOR_UP}${CURSOR_HOME}${ERASE_LINE}Directories: ${LIGHT_BLUE}${dirs_processed}/${TOTAL_DIRS}${RESET} 	 Secrets detected: ${BRIGHT_RED}${secrets_found}${RESET}${DARK_GRAY}	 ${elapsed_time}	${RESET}|${DARK_GRAY} ${estimated_time}${RESET}\r\n"
  fi
}

#
# Function to scan a file for secrets
#
scan_file() {
    local file="$1"
    local secrets_found_in_file=false

    # First pass -- scan the file (fast)
    grep -Eno ".*($SECRET_PATTERN_FAST.*)" "$file" | while IFS= read -r match; do

        # Second pass -- run match through stricter filter (slow)
        if echo "$match" | grep -qE "$SECRET_PATTERN_STRICT"; then
            # Check exclusions, stripping nonprintable characters
            match=$(echo "$match" | sed 's/[^[:print:]\t]//g' | tr -cd '\11\12\15\40-\176') #sanitize
            if ! echo "$match" | grep -qE "$EXCLUDE_PATTERN"; then
                secret_value="$(echo "$match" | awk '{sub(/^[0-9]+:[^:=]*[:=]/, ""); print}')"
                if [[ -n "$secret_value" ]]; then
                    # Extra paranoid section -- included for compound statements in input which confuse the exclusion filter
                    # TODO: REMOVE and re-simplify
                    extra_pass_regex='^\s*\{*\$|^o$' #'^\s*\{*\$' and catch the annoying os.getenv case [FP53] and baffling [FP54]  TODO: FIX BUGBUG
                    escaped_secret_value=$secret_value
                    trimmed_secret_value=$(echo "$escaped_secret_value" | sed 's/^[[:space:]]*["'\'"]*//')
                    test_for_invalid_secret=$(echo $trimmed_secret_value | grep -E $extra_pass_regex)

                    if [[ -z "$test_for_invalid_secret" ]]; then
                        printf "${LIGHT_BLUE}$file:${match} (Value: ${BRIGHT_RED}$secret_value${LIGHT_BLUE})${RESET}\n" >> "$RESULTS_FILE"
                        secrets_found_in_file=true
                        secrets_found=$(($(cat "$COUNT_FILE") + 1))
                        echo "$secrets_found" > "$COUNT_FILE"
                        update_status
                    fi
                fi
            fi
        fi
    done

    if $secrets_found_in_file;
    then
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
eval "find \"$TARGET_DIR\" -maxdepth 1 -type f \( $find_expr \) 2>/dev/null" | while read -r file;
do
  if [[ ! " ${EXCLUDE_DIRS[@]} " =~ " $(basename "$file") " ]]; then
    printf "\r${ERASE_LINE}Scanning: ${LIGHT_BLUE}$file${RESET}"
    scan_file "$file"
  fi
done

# Process subdirectories
find -P "$TARGET_DIR" -maxdepth 1 -type d | while read -r dir;
do
    if [ "$dir" != "$TARGET_DIR" ] && [[ ! " ${EXCLUDE_DIRS[@]} " =~ " $(basename "$dir") " ]]; then
        dirs_processed=$(($(cat "$DIR_COUNT_FILE") + 1))
        echo "$dirs_processed" > "$DIR_COUNT_FILE"
        update_status

        find_expr=$(construct_find_command)
        eval "find -P \"$dir\" -type f \( $find_expr \) 2>/dev/null" | while read -r file;
        do
            printf "\r${ERASE_LINE}Scanning: ${LIGHT_BLUE}$file${RESET}"
            scan_file "$file"
        done
    fi
done

printf "\n"
end=$(date +%s)
runtime=$((end - start))

total_secrets=$(cat "$COUNT_FILE")

if [[ -z "$RESULTS_FILE" ]]; then
  print_summary_banner "$total_secrets" "$runtime"
  printf "\n"
fi
# Report detailed findings
if [ -s "$RESULTS_FILE" ]; then
  sort -t: -k1,1 -k2,2n "$RESULTS_FILE" | uniq > temp && mv temp "$RESULTS_FILE"
  total_secrets=$(wc -l < "$RESULTS_FILE" | awk '{print $1}')

  print_summary_banner "$total_secrets" "$runtime"

# Create the log file name
  log_file_friendly_name="${script_name}-${timestamp}.log"
  temp_file=$(mktemp)
  temp_dir=$(dirname "$temp_file")
  friendly_transcript_file_name="$(basename "$0")_$(date +%s).txt"
  friendly_transcript_path="$temp_dir/$friendly_transcript_file_name"
  mv "$temp_file" "$friendly_transcript_path"
  printf "$0 results\nRun by: $(whoami)\nDate: $(date \"+%A, %B %d, %Y\")\n" >> "$friendly_transcript_path"
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
  printf "\n\n${DARK_GRAY}Suggestion: this will make the text more readable ${RESET}sed 's/\\x1b\[[0-9;]*[mG]//g' $friendly_transcript_path > ./human_readable.txt"
  printf "\n ${DARK_GRAY}Just don't leave it lying around, or it will get picked up in subsequent runs of the tool!${CLEAR}"
elif [[ $total_secrets -eq 0 ]]; then
  log_info "No secrets detected in the specified directory."
fi

exit 0