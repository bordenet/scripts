# lib/display-layout-auto.sh — no-argument auto-detect/restore for display-layout.sh
# Sourced by display-layout.sh; not executable directly.
# shellcheck shell=bash

all_ids_present() {
  local expected="$1" connected="$2" id
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    grep -Fqx -- "$id" <<< "$connected" || return 1
  done <<< "$expected"
  return 0
}

auto_run() {
  find_displayplacer

  if [[ ! -d "$LAYOUT_DIR" ]] || \
     [[ -z "$(find "$LAYOUT_DIR" -maxdepth 1 -type f -name '*.displayplacer' -print -quit)" ]]; then
    printf 'No saved layouts yet in %s\n\n' "$LAYOUT_DIR" >&2
    usage
    return
  fi

  local connected file name expected matches=()
  connected="$(current_ids)"

  while IFS= read -r file; do
    name="$(basename "$file" .displayplacer)"
    expected="$(command_ids "$file")"
    [[ -n "$expected" ]] || continue
    if [[ -n "$connected" ]] && all_ids_present "$expected" "$connected"; then
      matches+=("$name")
    fi
  done < <(find "$LAYOUT_DIR" -maxdepth 1 -type f -name '*.displayplacer' -print | sort)

  case "${#matches[@]}" in
    1)
      printf "Detected saved layout '%s' matches your connected displays.\n" "${matches[0]}"
      restore_layout "${matches[0]}"
      ;;
    0)
      printf 'No saved layout matches the currently connected displays:\n\n'
      list_layouts
      printf "\nRun '%s restore <name>' to apply one, or '%s save <name>' to save this arrangement.\n" \
        "$SCRIPT_NAME" "$SCRIPT_NAME"
      ;;
    *)
      printf 'Multiple saved layouts match your connected displays:\n\n'
      printf '  %s\n' "${matches[@]}"
      printf "\nRun '%s restore <name>' to choose one.\n" "$SCRIPT_NAME"
      ;;
  esac
}
