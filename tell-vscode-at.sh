#!/usr/bin/env bash
################################################################################
# Script Name: tell-vscode-at.sh
# Description: Send messages to VS Code instances at specified times
# Platform: macOS only
# Author: Matt J Bordenet
# Last Updated: 2025-11-21
################################################################################

set -euo pipefail

# Display help information
show_help() {
    cat << EOF
NAME
    $(basename "$0") - Send messages to VS Code instances at specified times

SYNOPSIS
    $(basename "$0") --instance SUBTITLE --message TEXT --at TIME
    $(basename "$0") [OPTIONS]

DESCRIPTION
    Schedules a message to be sent to a specific VS Code window at a given time.
    Uses AppleScript to find the VS Code window by subtitle and sends keystrokes
    to simulate typing the message followed by Enter.

    The script waits until the specified time, then:
    1. Finds the VS Code window with matching subtitle
    2. Brings it to the front
    3. Types the message
    4. Presses Enter

OPTIONS
    --instance SUBTITLE
        The window subtitle to match (e.g., "codebase-reviewer")
        VS Code windows show subtitle after the dash in title

    --message TEXT
        The message to send (will be followed by Enter)

    --at TIME
        Time to send the message. Formats:
        - "1 AM", "1:00 AM", "01:00"
        - "13:00", "1:00 PM"
        - "HH:MM" in 24-hour format

    -h, --help
        Display this help message and exit

    -v, --verbose
        Enable verbose output

EXAMPLES
    # Send "Continue" to codebase-reviewer window at 1 AM
    $(basename "$0") --instance "codebase-reviewer" --message "Continue" --at "1 AM"

    # Send command at 2:30 PM
    $(basename "$0") --instance "my-project" --message "run tests" --at "14:30"

    # Verbose mode
    $(basename "$0") -v --instance "dev" --message "deploy" --at "3 PM"

EXIT STATUS
    0   Success
    1   Error (invalid arguments, window not found, etc.)
    2   Timeout waiting for scheduled time

NOTES
    - Requires macOS with AppleScript support
    - VS Code must be running
    - Window subtitle must match exactly (case-sensitive)
    - Script runs in foreground until scheduled time
    - Use Ctrl+C to cancel before execution

ENVIRONMENT
    VERBOSE=1
        Enable verbose output (same as -v flag)

SEE ALSO
    osascript(1), schedule-claude.sh(1)

EOF
    exit 0
}

# Variables
INSTANCE=""
MESSAGE=""
AT_TIME=""
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        --instance)
            INSTANCE="$2"
            shift 2
            ;;
        --message)
            MESSAGE="$2"
            shift 2
            ;;
        --at)
            AT_TIME="$2"
            shift 2
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$INSTANCE" ]]; then
    echo "Error: --instance is required" >&2
    exit 1
fi

if [[ -z "$MESSAGE" ]]; then
    echo "Error: --message is required" >&2
    exit 1
fi

if [[ -z "$AT_TIME" ]]; then
    echo "Error: --at is required" >&2
    exit 1
fi

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    fi
}

# Parse time string to target epoch
parse_time() {
    local time_str="$1"
    local target_hour target_min

    # Convert various formats to HH:MM 24-hour
    if [[ "$time_str" =~ ^([0-9]{1,2})[[:space:]]*(AM|PM|am|pm)$ ]]; then
        # Format: "1 AM", "12 PM"
        target_hour="${BASH_REMATCH[1]}"
        local ampm="${BASH_REMATCH[2]}"
        target_min="00"

        # Convert to 24-hour
        if [[ "${ampm,,}" == "pm" ]] && [[ "$target_hour" -ne 12 ]]; then
            target_hour=$((target_hour + 12))
        elif [[ "${ampm,,}" == "am" ]] && [[ "$target_hour" -eq 12 ]]; then
            target_hour=0
        fi
    elif [[ "$time_str" =~ ^([0-9]{1,2}):([0-9]{2})[[:space:]]*(AM|PM|am|pm)$ ]]; then
        # Format: "1:30 AM", "12:45 PM"
        target_hour="${BASH_REMATCH[1]}"
        target_min="${BASH_REMATCH[2]}"
        local ampm="${BASH_REMATCH[3]}"

        # Convert to 24-hour
        if [[ "${ampm,,}" == "pm" ]] && [[ "$target_hour" -ne 12 ]]; then
            target_hour=$((target_hour + 12))
        elif [[ "${ampm,,}" == "am" ]] && [[ "$target_hour" -eq 12 ]]; then
            target_hour=0
        fi
    elif [[ "$time_str" =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
        # Format: "13:30", "01:00"
        target_hour="${BASH_REMATCH[1]}"
        target_min="${BASH_REMATCH[2]}"
    else
        echo "Error: Invalid time format: $time_str" >&2
        echo "Use formats like: '1 AM', '1:30 PM', '13:30'" >&2
        exit 1
    fi

    # Pad with zeros
    target_hour=$(printf "%02d" "$target_hour")
    target_min=$(printf "%02d" "$target_min")

    # Get today's date and construct target time
    local today
    today=$(date '+%Y-%m-%d')
    local target_datetime="${today} ${target_hour}:${target_min}:00"

    # Convert to epoch
    local target_epoch
    target_epoch=$(date -j -f "%Y-%m-%d %H:%M:%S" "$target_datetime" "+%s" 2>/dev/null)

    # If target time is in the past, add 24 hours
    local now_epoch
    now_epoch=$(date +%s)
    if [[ "$target_epoch" -lt "$now_epoch" ]]; then
        target_epoch=$((target_epoch + 86400))
    fi

    echo "$target_epoch"
}

# Wait until target time
wait_until() {
    local target_epoch="$1"
    local now_epoch

    while true; do
        now_epoch=$(date +%s)
        local remaining=$((target_epoch - now_epoch))

        if [[ "$remaining" -le 0 ]]; then
            break
        fi

        if [[ "$VERBOSE" == true ]]; then
            local hours=$((remaining / 3600))
            local mins=$(( (remaining % 3600) / 60))
            local secs=$((remaining % 60))
            printf "\r[%s] Waiting... %02d:%02d:%02d remaining" "$(date '+%H:%M:%S')" "$hours" "$mins" "$secs"
        fi

        sleep 1
    done

    if [[ "$VERBOSE" == true ]]; then
        echo ""  # New line after progress
    fi
}

# Send message to VS Code window
send_to_vscode() {
    local subtitle="$1"
    local message="$2"

    log_verbose "Looking for VS Code window with subtitle: $subtitle"

    # AppleScript to find window and send keystrokes
    osascript <<EOF
tell application "System Events"
    set vscodeName to "Code"

    -- Check if VS Code is running
    if not (exists process vscodeName) then
        error "VS Code is not running"
    end if

    tell process vscodeName
        -- Find window with matching subtitle
        set foundWindow to missing value
        repeat with w in windows
            set windowTitle to name of w as string
            if windowTitle contains "$subtitle" then
                set foundWindow to w
                exit repeat
            end if
        end repeat

        if foundWindow is missing value then
            error "No VS Code window found with subtitle: $subtitle"
        end if

        -- Bring window to front
        set frontmost to true
        perform action "AXRaise" of foundWindow
        delay 0.5

        -- Type the message
        keystroke "$message"
        delay 0.1

        -- Press Enter
        keystroke return
    end tell
end tell
EOF

    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "Error: Failed to send message to VS Code" >&2
        return 1
    fi

    return 0
}

# Main execution
echo "Scheduled: Send '$MESSAGE' to VS Code window '$INSTANCE' at $AT_TIME"

# Parse target time
TARGET_EPOCH=$(parse_time "$AT_TIME")
log_verbose "Target time: $(date -r "$TARGET_EPOCH" '+%Y-%m-%d %H:%M:%S')"

# Wait until target time
wait_until "$TARGET_EPOCH"

# Send message
log_verbose "Sending message now..."
if send_to_vscode "$INSTANCE" "$MESSAGE"; then
    echo "✓ Message sent successfully to '$INSTANCE'"
    exit 0
else
    echo "✗ Failed to send message" >&2
    exit 1
fi

