#!/usr/bin/env bash
#
# Script: schedule-claude.sh
# Description: This script schedules the execution of the 'resume-claude.sh' script
#              after a specified delay. It allows for setting a custom prompt to be
#              passed to 'resume-claude.sh' and includes a dry-run option.
#              On macOS, it uses 'caffeinate' to prevent the system from sleeping
#              during the waiting period.
# Usage: ./schedule-claude.sh [--hours N] [-m <minutes>] [-p <prompt>] [--dry-run]
# Arguments:
#   --hours: Number of hours to wait before running 'resume-claude.sh'.
#   -m, --minutes: Number of minutes to wait before running 'resume-claude.sh'.
#   -p, --prompt: Prompt string to pass to 'resume-claude.sh'.
#   --dry-run: Show what would happen without executing the scheduled script.
#   -h, --help: Show help message.
# Dependencies: resume-claude.sh (must be in the same directory), date, caffeinate (macOS)

# --- Configuration ---

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESUME_SCRIPT="$SCRIPT_DIR/resume-claude.sh"
DRY_RUN=false
VERBOSE=false
PROMPT=""
PROJECT_PATH=""
HOURS=0
MINUTES=0

log_verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

# --- Usage function ---
usage() {
  echo "Usage: $0 --project <path> [--hours N] [--minutes N] [-p prompt] [--dry-run]"
  echo ""
  echo "Options:"
  echo "  --project PATH  Project path to pass to resume-claude.sh"
  echo "  --hours N       Number of hours to wait before running"
  echo "  -m, --minutes N Number of minutes to wait before running"
  echo "  -p, --prompt    Prompt string to pass to resume-claude.sh"
  echo "  --dry-run       Show what would happen without executing"
  echo "  -v, --verbose   Enable verbose logging"
  echo "  -h, --help      Show this help message"
  exit 0
}

# --- Argument parsing ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --hours)
      [[ $# -ge 2 ]] || { echo "Error: --hours requires a value" >&2; exit 1; }
      HOURS="$2"; shift 2 ;;
    -m|--minutes)
      [[ $# -ge 2 ]] || { echo "Error: --minutes requires a value" >&2; exit 1; }
      MINUTES="$2"; shift 2 ;;
    -p|--prompt)
      [[ $# -ge 2 ]] || { echo "Error: --prompt requires a value" >&2; exit 1; }
      PROMPT="$2"; shift 2 ;;
    --project)
      [[ $# -ge 2 ]] || { echo "Error: --project requires a value" >&2; exit 1; }
      PROJECT_PATH="$2"; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    -v|--verbose) VERBOSE=true; shift ;;
    -h|--help) usage ;;
    -*) echo "Error: Unknown option: $1" >&2; exit 1 ;;
    *) echo "Error: Unexpected argument: $1" >&2; exit 1 ;;
  esac
done

# --- Calculate total seconds ---
TOTAL_MINUTES=$(( HOURS * 60 + MINUTES ))
TOTAL_SECONDS=$(( TOTAL_MINUTES * 60 ))

log_verbose "Parsed hours: $HOURS, minutes: $MINUTES"
log_verbose "Total delay: $TOTAL_SECONDS seconds"

if [[ $TOTAL_SECONDS -le 0 ]]; then
  echo "⚠️  No valid delay specified. Use --hours or -m." >&2
  exit 1
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
CAFFEINATE_PID=""
if [[ "$(uname -s)" == "Darwin" ]] && command -v caffeinate >/dev/null 2>&1; then
  echo "⚡ Using caffeinate to keep macOS awake..."
  caffeinate -dimsu &
  CAFFEINATE_PID=$!
  log_verbose "Caffeinate PID: $CAFFEINATE_PID"
fi

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
if [[ -n "$CAFFEINATE_PID" ]]; then
  log_verbose "Stopping caffeinate (PID: $CAFFEINATE_PID)"
  kill "$CAFFEINATE_PID" >/dev/null 2>&1 || true
fi

RESUME_ARGS=(-p "$PROMPT")
if [[ -n "${PROJECT_PATH:-}" ]]; then
  RESUME_ARGS=(--project "$PROJECT_PATH" "${RESUME_ARGS[@]}")
fi

if [[ -x "$RESUME_SCRIPT" ]]; then
  log_verbose "Executing: $RESUME_SCRIPT ${RESUME_ARGS[*]}"
  echo "🚀 Running $RESUME_SCRIPT ${RESUME_ARGS[*]}..."
  "$RESUME_SCRIPT" "${RESUME_ARGS[@]}"
else
  echo "❌ Error: $RESUME_SCRIPT not found or not executable."
  exit 1
fi

