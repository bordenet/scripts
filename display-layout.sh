#!/usr/bin/env bash
# display-layout — capture, inspect, validate, restore, and document macOS display layouts.
#
# See: display-layout --help

set -Eeuo pipefail
IFS=$'\n\t'

# shellcheck disable=SC2034  # VERSION is a convention; not referenced internally.
VERSION="1.0.0"
SCRIPT_NAME="$(basename "$0")"
LAYOUT_DIR_DEFAULT="${XDG_CONFIG_HOME:-$HOME/.config}/display-layouts"
LAYOUT_DIR="${DISPLAY_LAYOUT_DIR:-$LAYOUT_DIR_DEFAULT}"
DISPLAYPLACER="${DISPLAYPLACER_BIN:-}"
VERBOSE=0

# Resolve symlinks so lib/ is found relative to the real script location.
_SCRIPT_PATH="${BASH_SOURCE[0]}"
while [[ -L "$_SCRIPT_PATH" ]]; do
  _SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT_PATH")" && pwd)"
  _SCRIPT_PATH="$(readlink "$_SCRIPT_PATH")"
  [[ "$_SCRIPT_PATH" != /* ]] && _SCRIPT_PATH="$_SCRIPT_DIR/$_SCRIPT_PATH"
done
_SCRIPT_DIR="$(cd "$(dirname "$_SCRIPT_PATH")" && pwd)"
# shellcheck source=lib/display-layout-help.sh
source "$_SCRIPT_DIR/lib/display-layout-help.sh"
# shellcheck source=lib/display-layout-auto.sh
source "$_SCRIPT_DIR/lib/display-layout-auto.sh"
unset _SCRIPT_PATH _SCRIPT_DIR

die() {
  printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2
  exit 1
}

warn() {
  printf '%s: warning: %s\n' "$SCRIPT_NAME" "$*" >&2
}

vlog() {
  (( VERBOSE )) && printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2 || true
}

require_macos() {
  [[ "$(uname -s)" == "Darwin" ]] || die "this script requires macOS"
}

find_displayplacer() {
  if [[ -n "$DISPLAYPLACER" ]]; then
    [[ -x "$DISPLAYPLACER" ]] || die "DISPLAYPLACER_BIN is not executable: $DISPLAYPLACER"
    return
  fi

  if command -v displayplacer >/dev/null 2>&1; then
    DISPLAYPLACER="$(command -v displayplacer)"
    return
  fi

  local candidate
  for candidate in /opt/homebrew/bin/displayplacer /usr/local/bin/displayplacer; do
    if [[ -x "$candidate" ]]; then
      DISPLAYPLACER="$candidate"
      return
    fi
  done

  printf '%s: displayplacer not found; installing via Homebrew...\n' "$SCRIPT_NAME" >&2
  if ! command -v brew >/dev/null 2>&1; then
    die "displayplacer not found and Homebrew is not available. Install manually: brew install displayplacer"
  fi
  brew install displayplacer >&2
  if command -v displayplacer >/dev/null 2>&1; then
    DISPLAYPLACER="$(command -v displayplacer)"
    vlog "installed displayplacer: $DISPLAYPLACER"
    return
  fi
  die "displayplacer installation failed. Install manually: brew install displayplacer"
}

validate_name() {
  local name="$1"
  [[ -n "$name" ]] || die "layout name is required"
  [[ "$name" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || \
    die "invalid layout name '$name' (use letters, digits, dot, underscore, and hyphen)"
}

layout_file() {
  printf '%s/%s.displayplacer\n' "$LAYOUT_DIR" "$1"
}

meta_file() {
  printf '%s/%s.meta\n' "$LAYOUT_DIR" "$1"
}

extract_suggested_command() {
  awk '
    /Execute the command below to set your screens/ {capture=1; next}
    capture && /^displayplacer / {print; exit}
    capture && /^\// && /displayplacer/ {print; exit}
  '
}

current_command() {
  local output command
  output="$($DISPLAYPLACER list)"
  command="$(printf '%s\n' "$output" | extract_suggested_command || true)"

  if [[ -z "$command" ]]; then
    printf '%s\n' "$output" >&2
    die "could not find a suggested command in 'displayplacer list' output; inspect it with '$SCRIPT_NAME current'"
  fi

  printf '%s\n' "$command"
}

command_ids() {
  # grep -o extracts every non-overlapping "id:<value>" token on the line;
  # a greedy sed s/// substitution here would only capture the LAST id
  # when multiple displays are listed on one saved-layout command line.
  grep -ohE 'id:[^[:space:]]+' "$1" | sed 's/^id://' | sort -u
}

current_ids() {
  "$DISPLAYPLACER" list | sed -nE 's/.*(Persistent|Contextual|Serial) screen id: ([^ ]+).*/\2/p' | sort -u
}

save_layout() {
  local name="$1" file meta command tmp reply
  validate_name "$name"
  mkdir -p "$LAYOUT_DIR"
  file="$(layout_file "$name")"
  meta="$(meta_file "$name")"
  command="$(current_command)"

  if [[ -e "$file" ]]; then
    printf "Layout '%s' already exists. Overwrite? [y/N] " "$name" >&2
    read -r reply || true
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || die "not overwritten"
  fi

  tmp="$(mktemp "$LAYOUT_DIR/.${name}.XXXXXX")"
  {
    printf '# Saved by %s on %s\n' "$SCRIPT_NAME" "$(date '+%Y-%m-%d %H:%M:%S %Z')"
    printf '# Host: %s\n' "$(scutil --get ComputerName 2>/dev/null || hostname)"
    printf '# displayplacer: %s\n' "$DISPLAYPLACER"
    printf '%s\n' "$command"
  } > "$tmp"
  mv "$tmp" "$file"
  chmod 600 "$file"

  {
    printf 'saved_at=%q\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'host=%q\n' "$(scutil --get ComputerName 2>/dev/null || hostname)"
    printf 'macos=%q\n' "$(sw_vers -productVersion 2>/dev/null || true)"
    printf 'displayplacer=%q\n' "$DISPLAYPLACER"
  } > "$meta"
  chmod 600 "$meta"

  printf "Saved layout '%s' to %s\n" "$name" "$file"
  printf "Restore it with: %s restore %s\n" "$SCRIPT_NAME" "$name"
}

show_layout() {
  local name="$1" file
  validate_name "$name"
  file="$(layout_file "$name")"
  [[ -f "$file" ]] || die "layout '$name' does not exist"
  cat "$file"
}

list_layouts() {
  local found=0 file name
  [[ -d "$LAYOUT_DIR" ]] || {
    printf 'No saved layouts. Directory does not exist: %s\n' "$LAYOUT_DIR"
    return 0
  }

  while IFS= read -r file; do
    found=1
    name="$(basename "$file" .displayplacer)"
    printf '%-30s %s\n' "$name" "$(head -n 1 "$file" | sed 's/^# Saved by .* on //')"
  done < <(find "$LAYOUT_DIR" -maxdepth 1 -type f -name '*.displayplacer' -print | sort)

  (( found )) || printf 'No saved layouts in %s\n' "$LAYOUT_DIR"
}

validate_layout() {
  local name="$1" file expected connected missing=0 id
  validate_name "$name"
  file="$(layout_file "$name")"
  [[ -f "$file" ]] || die "layout '$name' does not exist"

  expected="$(command_ids "$file")"
  connected="$(current_ids)"

  [[ -n "$expected" ]] || die "no display IDs found in '$file'"
  if [[ -z "$connected" ]]; then
    warn "could not parse connected display IDs from displayplacer output"
    "$DISPLAYPLACER" list
    return 2
  fi

  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    if ! grep -Fqx -- "$id" <<< "$connected"; then
      printf 'MISSING  %s\n' "$id"
      missing=1
    else
      printf 'PRESENT  %s\n' "$id"
    fi
  done <<< "$expected"

  if (( missing )); then
    warn "one or more saved display IDs are not currently connected"
    warn "run '$SCRIPT_NAME current' to inspect current inventory and cabling/EDID state"
    return 1
  fi

  printf "All saved display IDs for '%s' appear connected.\n" "$name"
}

restore_layout() {
  local name="$1" file command reply validation_status=0
  validate_name "$name"
  file="$(layout_file "$name")"
  [[ -f "$file" ]] || die "layout '$name' does not exist"

  printf "Validating connected displays for '%s'...\n" "$name"
  validate_layout "$name" || validation_status=$?

  if (( validation_status != 0 )); then
    printf "Restore anyway? IDs may have changed; this can affect an unexpected display. [y/N] " >&2
    read -r reply || true
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || die "restore cancelled"
  elif [[ "${DISPLAY_LAYOUT_NO_CONFIRM:-0}" != "1" ]]; then
    printf "Restore layout '%s'? [y/N] " "$name" >&2
    read -r reply || true
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || die "restore cancelled"
  fi

  command="$(grep -Ev '^\s*($|#)' "$file" | tail -n 1)"
  [[ "$command" == displayplacer\ * || "$command" == */displayplacer\ * ]] || \
    die "saved layout does not contain a valid displayplacer command: $file"

  printf 'Applying layout %q...\n' "$name"
  # eval is required: displayplacer command arguments contain multi-word strings
  # with embedded quotes that cannot survive array construction intact. The
  # command is validated as a displayplacer invocation immediately above.
  # shellcheck disable=SC2294
  eval "$command"
  printf "Done. Verify the result, then re-save '%s' if this is the new desired state.\n" "$name"
}

delete_layout() {
  local name="$1" file meta reply
  validate_name "$name"
  file="$(layout_file "$name")"
  meta="$(meta_file "$name")"
  [[ -f "$file" ]] || die "layout '$name' does not exist"

  printf "Delete layout '%s'? [y/N] " "$name" >&2
  read -r reply || true
  [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]] || die "delete cancelled"
  rm -f -- "$file" "$meta"
  printf "Deleted layout '%s'.\n" "$name"
}

doctor() {
  local layouts=0
  printf 'System:             %s %s\n' "$(sw_vers -productName)" "$(sw_vers -productVersion)"
  printf 'Architecture:       %s\n' "$(uname -m)"
  printf 'Profile directory:  %s\n' "$LAYOUT_DIR"

  if find_displayplacer; then
    printf 'displayplacer:      %s\n' "$DISPLAYPLACER"
    "$DISPLAYPLACER" version 2>/dev/null || true
  fi

  if [[ -d "$LAYOUT_DIR" ]]; then
    layouts="$(find "$LAYOUT_DIR" -maxdepth 1 -type f -name '*.displayplacer' -print | wc -l | tr -d ' ')"
  fi
  printf 'Saved profiles:     %s\n' "$layouts"

  cat <<EOF

Recommended operating model:
  1. Use fixed monitor/dock ports; investigate EDID and wake timing if IDs move.
  2. Capture one profile per desk, lid-open/clamshell, and travel state.
  3. Use '$SCRIPT_NAME restore <name>' as the deterministic recovery action.
  4. While debugging cross-device pointer traversal, disable Universal Control
     automatic reconnect and explicitly join only the intended devices.
  5. Use BetterDisplay only as an optional GUI protection layer; retain saved
     profiles as the reproducible fallback. Use Stay for app-window recovery.

Next commands:
  $SCRIPT_NAME current
  $SCRIPT_NAME list
  $SCRIPT_NAME save <descriptive-name>
EOF
}

main() {
  require_macos

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dir)
        [[ $# -ge 2 ]] || die "--dir requires a directory"
        LAYOUT_DIR="$2"
        shift 2
        ;;
      -v|--verbose)
        VERBOSE=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        break
        ;;
    esac
  done

  local command="${1:-}"
  shift || true

  if [[ -z "$command" ]]; then
    auto_run
    return
  fi

  case "$command" in
    help)
      [[ $# -eq 0 ]] || die "help accepts no arguments"
      usage
      ;;
    path)
      [[ $# -eq 0 ]] || die "path accepts no arguments"
      printf '%s\n' "$LAYOUT_DIR"
      ;;
    list)
      [[ $# -eq 0 ]] || die "list accepts no arguments"
      list_layouts
      ;;
    current)
      [[ $# -eq 0 ]] || die "current accepts no arguments"
      find_displayplacer
      "$DISPLAYPLACER" list
      ;;
    save)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME save <name>"
      find_displayplacer
      save_layout "$1"
      ;;
    show)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME show <name>"
      show_layout "$1"
      ;;
    validate)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME validate <name>"
      find_displayplacer
      validate_layout "$1"
      ;;
    restore)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME restore <name>"
      find_displayplacer
      restore_layout "$1"
      ;;
    delete|rm)
      [[ $# -eq 1 ]] || die "usage: $SCRIPT_NAME delete <name>"
      delete_layout "$1"
      ;;
    doctor)
      [[ $# -eq 0 ]] || die "doctor accepts no arguments"
      doctor
      ;;
    *)
      usage >&2
      die "unknown command: $command"
      ;;
  esac
}

main "$@"
