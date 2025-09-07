#!/bin/bash

# --- Defaults ---
HOURS=0
MINUTES=0
PROMPT=""

show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -h, --hours <N>       Number of hours to wait
  -m, --minutes <M>     Number of minutes to wait
  -p, --prompt <text>   Prompt string to forward to resume-claude.sh
  ?, --help             Show this help message

Examples:
  $0 -h 2 -m 30 -p "Resume where we left off"
  $0 --minutes 45
  $0 --hours 1 --prompt "Kick off nightly run"
EOF
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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

# --- Convert to total seconds ---
TOTAL_MINUTES=$(( HOURS * 60 + MINUTES ))
TOTAL_SECONDS=$(( TOTAL_MINUTES * 60 ))

if [[ $TOTAL_SECONDS -le 0 ]]; then
  echo "⚠️  Please specify a positive wait time."
  show_help
  exit 1
fi

echo "⏳ Waiting $HOURS hours and $MINUTES minutes ($TOTAL_SECONDS seconds)..."
sleep "$TOTAL_SECONDS"

# --- Run the main script ---
if [[ -n "$PROMPT" ]]; then
  ./resume-claude.sh -p "$PROMPT"
else
  ./resume-claude.sh
fi
