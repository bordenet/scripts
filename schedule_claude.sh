#!/bin/bash

# --- Defaults ---
HOURS=0
MINUTES=0
PROMPT=""
USE_JIGGLE=false
DRY_RUN=false

show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h, --hours <N>       Delay by N hours
  -m, --minutes <N>     Delay by N minutes
  -p, --prompt <text>   Prompt string to send to Claude
  --jiggle              Use mouse jiggle mode instead of caffeinate
  --dry-run             Show what would happen but don’t actually run Claude
  ?, --help             Show this help message

Examples:
  $0 -h 2 -m 30 -p "Resume where we left off"
  $0 -m 10 --jiggle
  $0 -m 1 --dry-run
EOF
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--hours)
      HOURS="$2"
      shift 2
      ;;
    -m|--minutes)
      MINUTES="$2"
      shift 2
      ;;
    -p|--prompt)
      PROMPT="$2"
      shift 2
      ;;
    --jiggle)
      USE_JIGGLE=true
      shift
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    \?|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# --- Compute total seconds ---
TOTAL_MINUTES=$(( HOURS * 60 + MINUTES ))
TOTAL_SECONDS=$(( TOTAL_MINUTES * 60 ))

if [[ $TOTAL_SECONDS -le 0 ]]; then
  echo "❌ No delay specified. Exiting."
  exit 1
fi

echo "⏳ Waiting $HOURS hours and $MINUTES minutes ($TOTAL_SECONDS seconds)..."

if $DRY_RUN; then
  echo "🟡 Dry run mode enabled. No commands will actually execute."
fi

if ! $DRY_RUN; then
  if $USE_JIGGLE; then
    echo "🖱️  Using mouse jiggle mode to keep macOS awake..."
    (
      while true; do
        osascript <<EOF
          tell application "System Events"
            set p to (get mouse location)
            set x to item 1 of p
            set y to item 2 of p
            set mouse location {x+1, y}
            delay 0.2
            set mouse location {x, y}
          end tell
EOF
        sleep 240   # every 4 minutes
      done
    ) &
    JIGGLE_PID=$!
    sleep "$TOTAL_SECONDS"
    kill $JIGGLE_PID 2>/dev/null
  else
    echo "⚡ Using caffeinate to keep macOS awake..."
    caffeinate -dimsu sleep "$TOTAL_SECONDS"
  fi
else
  echo "🟡 Skipping sleep because dry run is active."
fi

# --- Locate resume_claude.sh ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESUME_SCRIPT="$SCRIPT_DIR/resume_claude.sh"

if [[ ! -x "$RESUME_SCRIPT" ]]; then
  echo "❌ Error: resume_claude.sh not found or not executable in $SCRIPT_DIR"
  exit 1
fi

# --- Invoke resume_claude.sh ---
if $DRY_RUN; then
  echo "🟡 Would run: $RESUME_SCRIPT ${PROMPT:+-p \"$PROMPT\"}"
else
  "$RESUME_SCRIPT" ${PROMPT:+-p "$PROMPT"}
fi
