#!/usr/bin/env bash
################################################################################
# Library: utils.sh
################################################################################
# PURPOSE: Utility functions for purge-identity tool (logging, timer, display)
# USAGE: Source this file from main script or lib/common.sh
# PLATFORM: macOS
################################################################################

init_logging() {
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S) || {
        echo "ERROR: Failed to get timestamp" >&2
        exit 1
    }
    LOG_FILE="${LOG_DIR}/purge-identity-${timestamp}.log"

    # Create log file
    touch "$LOG_FILE" || {
        echo "ERROR: Failed to create log file: $LOG_FILE" >&2
        exit 1
    }

    log "INFO" "Purge Identity Tool v${VERSION} started"
    log "INFO" "Command: $0 $*"
    log "INFO" "Platform: $(uname -s) $(uname -r)"
    log "INFO" "User: $(whoami)"

    # Cleanup old logs (>24 hours)
    find "$LOG_DIR" -name "purge-identity-*.log" -mtime +1 -delete 2>/dev/null || true

    # Set up trap for cleanup on exit
    trap 'cleanup_on_exit' EXIT INT TERM
}

# Log message to file and optionally to console
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${level}] ${message}" >> "$LOG_FILE" 2>/dev/null || true

    # Also echo to console if verbose mode
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo "[${level}] ${message}"
    fi
}

# Log and display error
log_error() {
    local message="$1"
    log "ERROR" "$message"
    echo -e "${RED}✗${NC} $message" >&2
}

# Log and display success
log_success() {
    local message="$1"
    log "INFO" "$message"
    echo -e "${GREEN}✓${NC} $message"
}

# Log and display info
log_info() {
    local message="$1"
    log "INFO" "$message"
    echo "$message"
}

# -----------------------------------------------------------------------------
# Timer Functions
# -----------------------------------------------------------------------------

# Start background timer display
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
    log "DEBUG" "Timer started (PID: $TIMER_PID)"
}

# Update timer display in top-right corner
update_timer_display() {
    local current_time
    current_time=$(date +%s)
    local elapsed
    elapsed=$((current_time - START_TIME))
    local hours
    hours=$((elapsed / 3600))
    local minutes
    minutes=$(((elapsed % 3600) / 60))
    local seconds
    seconds=$((elapsed % 60))

    # Only display if we're in an interactive terminal
    if [[ -t 1 ]]; then
        printf "${SAVE_CURSOR}${MOVE_TO_TOP_RIGHT}${YELLOW}[%02d:%02d:%02d]${NC}${RESTORE_CURSOR}" \
            "$hours" "$minutes" "$seconds"
    fi
}

# Stop timer
stop_timer() {
    if [[ -n "$TIMER_PID" ]] && ps -p "$TIMER_PID" > /dev/null 2>&1; then
        kill "$TIMER_PID" 2>/dev/null
        wait "$TIMER_PID" 2>/dev/null || true
        log "DEBUG" "Timer stopped"
    fi
}

# Get formatted elapsed time
get_elapsed_time() {
    local current_time
    current_time=$(date +%s)
    local elapsed
    elapsed=$((current_time - START_TIME))
    local hours
    hours=$((elapsed / 3600))
    local minutes
    minutes=$(((elapsed % 3600) / 60))
    local seconds
    seconds=$((elapsed % 60))
    printf "%02d:%02d:%02d" "$hours" "$minutes" "$seconds"
}

# -----------------------------------------------------------------------------
# Cleanup and Exit
# -----------------------------------------------------------------------------

cleanup_on_exit() {
    stop_timer
    log "INFO" "Script exiting (elapsed: $(get_elapsed_time))"
}

# -----------------------------------------------------------------------------
# Display Functions
# -----------------------------------------------------------------------------

# Display script header
display_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                                                               ║"
    echo "║            macOS Identity Purge Tool v${VERSION}               ║"
    echo "║                                                               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo

    if [[ "$WHAT_IF_MODE" == true ]]; then
        echo -e "${YELLOW}Running in WHAT-IF mode (dry-run - no deletions will occur)${NC}"
        echo
    fi
}

# Display section header
display_section_header() {
    local title="$1"
    echo
    echo -e "${CYAN}▶ ${title}${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..60})${NC}"
}
