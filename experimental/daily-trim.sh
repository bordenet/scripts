#!/bin/zsh
# shellcheck disable=SC1071  # zsh script
# ⚠️ EXPERIMENTAL: Clears common macOS caches to reclaim disk space.
# Safe for daily use — only removes regenerable caches.
# Usage: daily-trim [--what-if]
setopt +o nomatch

what_if=false
if [[ "${1:-}" == "--what-if" ]]; then what_if=true; fi

echo "🔄 DAILY TRIM (Work-Safe)"

targets=(
    ~/Library/Caches/Homebrew
    ~/Library/Caches/pip
    ~/Library/Caches/node-gyp
    ~/Library/Caches/go-build
    ~/Library/Caches/bun
    ~/Library/Containers/com.apple.AMPArtworkAgent
)

# Show targets and sizes
total=0
for t in "${targets[@]}"; do
    if [[ -e "$t" ]]; then
        size=$(du -sk "$t" 2>/dev/null | cut -f1)
        echo "  $((size/1024))MB  $t"
        total=$((total + size))
    fi
done

# Xcode DerivedData
xcode_dd=~/Library/Developer/Xcode/DerivedData
if [[ -d "$xcode_dd" ]]; then
    size=$(du -sk "$xcode_dd" 2>/dev/null | cut -f1)
    echo "  $((size/1024))MB  $xcode_dd/*"
    total=$((total + size))
fi

echo "  Total reclaimable: ~$((total/1024))MB"

if $what_if; then
    echo "(dry-run — no changes made)"
    exit 0
fi

brew cleanup 2>/dev/null || true
for t in "${targets[@]}"; do
    rm -rf "$t" 2>/dev/null || true
done
find "$xcode_dd" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true

df -h ~ | awk 'NR==2 {print "📊 Free: " $4}'
