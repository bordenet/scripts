#!/usr/bin/env bash

set -euo pipefail

[[ "$(uname -s)" != "Darwin" ]] && { echo "Error: This script requires macOS" >&2; exit 1; }
#
# Script: resume-claude.sh
# Description: This script automates the process of resuming an AI assistant session
#              with "Claude" within VS Code. It opens a specified project, activates
#              VS Code, opens the integrated terminal, initiates Claude, and sends
#              a predefined or custom prompt to continue a conversation or task.
# Platform: macOS only
# Usage: ./resume-claude.sh [-p <prompt>|--prompt <prompt>]
# Arguments:
#   -p, --prompt <text>: Optional. A custom prompt string to send to Claude.
#                        If not provided, a default prompt will be used.
# Dependencies: VS Code, osascript (macOS), pgrep
#
# --- Defaults ---
PROJECT_PATH=""  # Must be provided via --project or first positional arg
PROMPT="Proceed, noting I have made additions to CLAUDE.md which I need you to factor into the plan."
VERBOSE=false

log_verbose() {
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[VERBOSE] $*" >&2
  fi
}

show_help() {
  cat <<EOF
Usage: $0 --project <path> [options]

Options:
  --project <path>      Path to the project to open in VS Code (required)
  -p, --prompt <text>   Prompt string to send to Claude
  -v, --verbose         Enable verbose logging
  -h, --help            Show this help message

Examples:
  $0 --project ~/GitHub/MyProject -p "Resume where we left off"
  $0 --project . --verbose
EOF
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --project)
      [[ $# -ge 2 ]] || { echo "Error: --project requires a value" >&2; exit 1; }
      PROJECT_PATH="$2"
      shift 2
      ;;
    -p|--prompt)
      [[ $# -ge 2 ]] || { echo "Error: --prompt requires a value" >&2; exit 1; }
      PROMPT="$2"
      shift 2
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      # Treat first positional arg as project path
      if [[ -z "$PROJECT_PATH" && ! "$1" =~ ^- ]]; then
        PROJECT_PATH="$1"
        shift
      else
        echo "Unknown option: $1"
        show_help
        exit 1
      fi
      ;;
  esac
done

# --- Validate required args ---
if [[ -z "$PROJECT_PATH" ]]; then
  echo "Error: No project path specified. Use --project <path> or pass as first argument." >&2
  show_help >&2
  exit 1
fi

# --- Script Logic ---
log_verbose "Starting resume-claude.sh with prompt: $PROMPT"
log_verbose "Project path: $PROJECT_PATH"

echo "Opening project in VS Code..."

if pgrep -x "Code" >/dev/null; then
  log_verbose "VS Code process found (PID: $(pgrep -x 'Code'))"
  echo "VS Code already running, opening folder..."
  code -r "$PROJECT_PATH"
else
  log_verbose "VS Code not running, starting fresh"
  echo "Starting VS Code fresh..."
  code "$PROJECT_PATH"
  sleep 5
fi

# Sanitize prompt for AppleScript (escape backslashes and double quotes)
SAFE_PROMPT=$(printf '%s' "$PROMPT" | sed 's/\\/\\\\/g; s/"/\\"/g')

log_verbose "Initiating AppleScript automation sequence"
echo "Activating VS Code and using integrated terminal..."
osascript <<EOF
tell application "Code"
	activate
end tell

delay 2

tell application "System Events"
	set promptText to "${SAFE_PROMPT}"

	tell process "Code"
		-- Ensure terminal panel is open/focused
		click menu item "Terminal" of menu "View" of menu bar 1
	end tell

	delay 2

	-- Start Claude
	keystroke "claude"
	keystroke return

	-- Give Claude time to initialize
	delay 10

	-- Send ESC keystroke
	key code 53

	delay 1

	-- Now send the action string
	keystroke promptText
	keystroke return

	delay 10

	-- Extra return for good measure
	keystroke return
end tell
EOF

log_verbose "AppleScript automation complete"
echo "✅ Script finished."
