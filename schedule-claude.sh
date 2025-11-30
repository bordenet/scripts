#!/usr/bin/env bash
#
# Script: schedule-claude.sh
# Description: This script schedules the execution of the 'resume-claude.sh' script
#              after a specified delay. It allows for setting a custom prompt to be
#              passed to 'resume-claude.sh' and includes a dry-run option.
#              On macOS, it uses 'caffeinate' to prevent the system from sleeping
#              during the waiting period.
# Usage: ./schedule-claude.sh [-h <hours>] [-m <minutes>] [-p <prompt>] [--dry-run]
# Arguments:
#   -h, --hours: Number of hours to wait before running 'resume-claude.sh'.
#   -m, --minutes: Number of minutes to wait before running 'resume-claude.sh'.
#   -p, --prompt: Prompt string to pass to 'resume-claude.sh'.
#   --dry-run: Show what would happen without executing the scheduled script.
# Dependencies: resume-claude.sh (must be in the same directory), date, caffeinate (macOS)
#
#!/bin/bash

# --- Configuration ---

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESUME_SCRIPT="$SCRIPT_DIR/resume-claude.sh"
DRY_RUN=false
VERBOSE=false
PROMPT=""
HOURS=0
MINUTES=0

log_verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

# --- Usage function ---
usage() {
  echo "Usage: $0 [-h hours] [-m minutes] [-p prompt] [--dry-run] [--verbose]"
  echo ""
  echo "Options:"
  echo "  -h, --hours     Number of hours to wait before running"
  echo "  -m, --minutes   Number of minutes to wait before running"
  echo "  -p, --prompt    Prompt string to pass to resume-claude.sh"
  echo "  --dry-run       Show what would happen without executing"
  echo "  -v, --verbose   Enable verbose logging"
  echo "  -?, --help      Show this help message"
  exit 1
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--hours) HOURS="$2"; shift 2 ;;
    -m|--minutes) MINUTES="$2"; shift 2 ;;
    -p|--prompt) PROMPT="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -\?|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# --- Calculate total seconds ---
TOTAL_MINUTES=$(( HOURS * 60 + MINUTES ))
TOTAL_SECONDS=$(( TOTAL_MINUTES * 60 ))

log_verbose "Parsed hours: $HOURS, minutes: $MINUTES"
log_verbose "Total delay: $TOTAL_SECONDS seconds"

if [[ $TOTAL_SECONDS -le 0 ]]; then
  echo "⚠️  No valid delay specified. Use -h or -m."
  usage
fi

# --- Compute target wall-clock time ---
#TARGET_TIME=$(date -v+${HOURS}H -v+${MINUTES}M +"%H:%M:%S %Z")
#TARGET_TIME=$(date -v+${HOURS}H -v+${MINUTES}M +"%H:%M:%S %Z")
# --- Compute target wall-clock time ---
if date -v+0H >/dev/null 2>&1; then
  # macOS BSD date supports -v
  TARGET_TIME=$(date -v+${HOURS}H -v+${MINUTES}M +"%H:%M:%S %Z")
else
  # GNU date (Linux or gdate on macOS with coreutils)
  TARGET_TIME=$(date -d "now + ${HOURS} hours + ${MINUTES} minutes" +"%H:%M:%S %Z")
fi

echo "⏳ Waiting ${HOURS} hours and ${MINUTES} minutes ($TOTAL_SECONDS seconds)..."
echo "Prompt: \"$PROMPT\""
echo "🕒 Will run at $TARGET_TIME"

# --- Dry run check ---
if $DRY_RUN; then
  echo "🔎 Dry run mode enabled. Would run: $RESUME_SCRIPT -p \"$PROMPT\""
  exit 0
fi

# --- Keep system awake while waiting ---
log_verbose "Starting caffeinate to prevent sleep during countdown"
echo "⚡ Using caffeinate to keep macOS awake..."
caffeinate -dimsu &
CAFFEINATE_PID=$!
log_verbose "Caffeinate PID: $CAFFEINATE_PID"

# --- Countdown ticker (per second) ---
SECONDS_LEFT=$TOTAL_SECONDS
while [[ $SECONDS_LEFT -gt 0 ]]; do
  HOURS_LEFT=$(( SECONDS_LEFT / 3600 ))
  MINUTES_LEFT=$(( (SECONDS_LEFT % 3600) / 60 ))
  SECS_LEFT=$(( SECONDS_LEFT % 60 ))

  # Get terminal width
  COLS=$(tput cols 2>/dev/null || echo 80)

  # Format timer text: [HH:MM:SS]
  TIMER_TEXT=$(printf "[%02d:%02d:%02d]" "$HOURS_LEFT" "$MINUTES_LEFT" "$SECS_LEFT")
  TIMER_POS=$((COLS - ${#TIMER_TEXT}))

  # Display countdown in main area and timer in top-right corner
  printf "\r\033[K⏳ Time left: %02d:%02d:%02d" "$HOURS_LEFT" "$MINUTES_LEFT" "$SECS_LEFT"

  # Save cursor, move to top-right, print timer (yellow on black), restore cursor
  echo -ne "\033[s\033[1;${TIMER_POS}H\033[33;40m${TIMER_TEXT}\033[0m\033[u"

  sleep 1
  SECONDS_LEFT=$(( SECONDS_LEFT - 1 ))
done
echo ""

# --- Execute resume script ---
log_verbose "Stopping caffeinate (PID: $CAFFEINATE_PID)"
kill $CAFFEINATE_PID >/dev/null 2>&1 || true

if [[ -x "$RESUME_SCRIPT" ]]; then
  log_verbose "Executing: $RESUME_SCRIPT -p \"$PROMPT\""
  echo "🚀 Running $RESUME_SCRIPT -p \"$PROMPT\"..."
  "$RESUME_SCRIPT" -p "$PROMPT"
else
  echo "❌ Error: $RESUME_SCRIPT not found or not executable."
  exit 1
fi

