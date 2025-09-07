#!/bin/bash

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESUME_SCRIPT="$SCRIPT_DIR/resume_claude.sh"
DRY_RUN=false
PROMPT=""
HOURS=0
MINUTES=0

# --- Usage function ---
usage() {
  echo "Usage: $0 [-h hours] [-m minutes] [-p prompt] [--dry-run]"
  echo ""
  echo "Options:"
  echo "  -h, --hours     Number of hours to wait before running"
  echo "  -m, --minutes   Number of minutes to wait before running"
  echo "  -p, --prompt    Prompt string to pass to resume_claude.sh"
  echo "  --dry-run       Show what would happen without executing"
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
    -\?|--help) usage ;;
    *) echo "Unknown option: $1"; usage ;;
  esac
done

# --- Calculate total seconds ---
TOTAL_MINUTES=$(( HOURS * 60 + MINUTES ))
TOTAL_SECONDS=$(( TOTAL_MINUTES * 60 ))

if [[ $TOTAL_SECONDS -le 0 ]]; then
  echo "⚠️  No valid delay specified. Use -h or -m."
  usage
fi

# --- Compute target wall-clock time ---
TARGET_TIME=$(date -v+${HOURS}H -v+${MINUTES}M +"%H:%M:%S %Z")

echo "⏳ Waiting ${HOURS} hours and ${MINUTES} minutes ($TOTAL_SECONDS seconds)..."
echo "🕒 Will run at $TARGET_TIME"

# --- Dry run check ---
if $DRY_RUN; then
  echo "🔎 Dry run mode enabled. Would run: $RESUME_SCRIPT -p \"$PROMPT\""
  exit 0
fi

# --- Keep system awake while waiting ---
echo "⚡ Using caffeinate to keep macOS awake..."
caffeinate -dimsu sleep $TOTAL_SECONDS &

# --- Sleep until time ---
sleep $TOTAL_SECONDS

# --- Execute resume script ---
if [[ -x "$RESUME_SCRIPT" ]]; then
  echo "🚀 Running $RESUME_SCRIPT -p \"$PROMPT\"..."
  "$RESUME_SCRIPT" -p "$PROMPT"
else
  echo "❌ Error: $RESUME_SCRIPT not found or not executable."
  exit 1
fi
