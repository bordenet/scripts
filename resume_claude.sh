#!/bin/bash

# --- Defaults ---
PROJECT_PATH="/Users/$(whoami)/GitHub/RecipeArchive"
PROMPT="Proceed, noting I have made additions to CLAUDE.md which I need you to factor into the plan."

show_help() {
  cat <<EOF
Usage: $0 [options]

Options:
  -p, --prompt <text>   Prompt string to send to Claude
  ?, --help             Show this help message

Examples:
  $0 -p "Resume where we left off"
EOF
}

# --- Parse args ---
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
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

# --- Script Logic ---
echo "Opening project in VS Code..."

if pgrep -x "Code" >/dev/null; then
  echo "VS Code already running, opening folder..."
  code -r "$PROJECT_PATH"
else
  echo "Starting VS Code fresh..."
  code "$PROJECT_PATH"
  sleep 5
fi

echo "Activating VS Code and using integrated terminal..."
osascript <<EOF
tell application "Code"
	activate
end tell

delay 2

tell application "System Events"
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
	keystroke "$PROMPT"
	keystroke return

	delay 10

	-- Extra return for good measure
	keystroke return
end tell
EOF

echo "✅ Script finished."
