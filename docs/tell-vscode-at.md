# tell-vscode-at.sh

Automate sending messages to VS Code windows at scheduled times.

## Overview

`tell-vscode-at.sh` is a macOS automation script that:
- Waits until a specified time
- Finds a VS Code window by its subtitle
- Sends a message (text + Enter) to that window

Perfect for scheduling automated tasks in VS Code, like continuing AI assistant conversations at specific times.

## Requirements

- **macOS** with AppleScript support
- **VS Code** must be running
- **Accessibility permissions** for Terminal/iTerm (System Settings → Privacy & Security → Accessibility)

## Usage

```bash
./tell-vscode-at.sh --instance SUBTITLE --message TEXT --at TIME
```

### Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `--instance` | VS Code window subtitle to match | `"codebase-reviewer"` |
| `--message` | Text to send (followed by Enter) | `"Continue"` |
| `--at` | Time to send message | `"1 AM"`, `"14:30"`, `"2:30 PM"` |
| `-v, --verbose` | Show detailed progress | |
| `-h, --help` | Display help | |

### Time Formats

Supports multiple time formats:
- **12-hour**: `"1 AM"`, `"1:30 PM"`, `"12:00 AM"`
- **24-hour**: `"13:00"`, `"01:30"`, `"23:45"`

If the specified time has already passed today, the script schedules for tomorrow.

## Examples

### Basic Usage

```bash
# Send "Continue" to codebase-reviewer window at 1 AM
./tell-vscode-at.sh --instance "codebase-reviewer" --message "Continue" --at "1 AM"
```

### With Verbose Output

```bash
# Show progress while waiting
./tell-vscode-at.sh -v \
    --instance "my-project" \
    --message "run tests" \
    --at "14:30"
```

### Different Time Formats

```bash
# 12-hour format
./tell-vscode-at.sh --instance "dev" --message "deploy" --at "3 PM"

# 24-hour format
./tell-vscode-at.sh --instance "dev" --message "deploy" --at "15:00"

# With minutes
./tell-vscode-at.sh --instance "dev" --message "deploy" --at "3:30 PM"
```

## How It Works

1. **Parse Time**: Converts time string to target epoch timestamp
2. **Wait**: Sleeps until target time (shows countdown in verbose mode)
3. **Find Window**: Uses AppleScript to search VS Code windows by subtitle
4. **Send Message**: Brings window to front, types message, presses Enter

## Window Subtitle Matching

VS Code window titles typically look like:
```
filename.txt - project-name
```

The subtitle is the part after the dash (e.g., `"project-name"`).

To find your window subtitle:
1. Open VS Code
2. Look at the window title bar
3. Use the text after the dash as `--instance` value

## Troubleshooting

### "VS Code is not running"
- Start VS Code before running the script
- Ensure VS Code is the application name (not "Visual Studio Code")

### "No VS Code window found with subtitle"
- Check window title bar for exact subtitle
- Subtitle matching is case-sensitive
- Try with verbose mode to see what's happening

### "Operation not permitted"
- Grant Accessibility permissions to Terminal/iTerm
- System Settings → Privacy & Security → Accessibility
- Add Terminal or iTerm to allowed apps

### Script exits immediately
- Check time format is correct
- Ensure time hasn't already passed (or it will schedule for tomorrow)
- Use verbose mode to see what's happening

## Use Cases

### Scheduled AI Assistant Interactions
```bash
# Continue Claude conversation at 1 AM
./tell-vscode-at.sh --instance "codebase-reviewer" --message "Continue" --at "1 AM"
```

### Automated Testing
```bash
# Run tests at 2 AM
./tell-vscode-at.sh --instance "my-project" --message "npm test" --at "2 AM"
```

### Scheduled Deployments
```bash
# Deploy at 3 AM
./tell-vscode-at.sh --instance "production" --message "deploy --prod" --at "3 AM"
```

## Running in Background

To run the script in the background and log output:

```bash
nohup ./tell-vscode-at.sh \
    --instance "codebase-reviewer" \
    --message "Continue" \
    --at "1 AM" \
    > /tmp/vscode-automation.log 2>&1 &
```

## Limitations

- **macOS only**: Uses AppleScript for window automation
- **Foreground execution**: Script runs until scheduled time (use `nohup` for background)
- **Single message**: Sends one message per execution
- **No retry**: If window not found, script exits with error

## See Also

- `schedule-claude.sh` - Schedule Claude Desktop interactions
- `resume-claude.sh` - Resume Claude conversations
- AppleScript documentation: `man osascript`

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success - message sent |
| 1 | Error (invalid args, window not found, etc.) |
| 2 | Timeout or scheduling error |

