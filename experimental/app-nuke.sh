#!/bin/zsh
# shellcheck disable=SC1071  # zsh script
# ⚠️ EXPERIMENTAL: Completely removes an app and its Library data.
# Usage: app-nuke <appname>
#        app-nuke --what-if <appname>   (dry-run: show what would be deleted)
set -euo pipefail

what_if=false
if [[ "${1:-}" == "--what-if" ]]; then what_if=true; shift; fi

app=${1:-}
if [[ -z "$app" ]]; then echo "Usage: app-nuke [--what-if] <appname>"; exit 1; fi

echo "🎯 TARGETING: $app"

# Show what would be affected
targets=()
for dir in ~/Library/Application\ Support ~/Library/Containers ~/Library/Caches; do
    for match in "$dir"/"$app"*(N); do
        targets+=("$match")
    done
done

if [[ ${#targets[@]} -eq 0 ]]; then
    echo "No Library data found for '$app'."
fi

for t in "${targets[@]}"; do
    echo "  $(du -sh "$t" 2>/dev/null | cut -f1)  $t"
done

if $what_if; then
    echo "(dry-run — no changes made)"
    exit 0
fi

echo ""
read -q "REPLY?Delete all of the above? [y/N] " || { echo "\nAborted."; exit 0; }
echo ""

brew uninstall --cask "$app" 2>/dev/null || brew uninstall "$app" 2>/dev/null || true
for t in "${targets[@]}"; do
    rm -rf "$t"
done
echo "✅ $app removed."
