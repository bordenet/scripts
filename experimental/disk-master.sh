#!/bin/zsh
# ⚠️ EXPERIMENTAL: Aggressive disk cleanup. DESTRUCTIVE — removes app data.
# Usage: disk-master [--what-if]   (default: dry-run)
setopt +o nomatch

what_if=true  # Safe default: dry-run
if [[ "${1:-}" == "--force" ]]; then what_if=false; fi
if [[ "${1:-}" == "--what-if" ]]; then what_if=true; fi

if $what_if; then
    echo "💣 DISK-MASTER: DRY RUN (use --force to actually delete)"
else
    echo "💣 DISK-MASTER: TOTAL CLEANUP"
    echo ""
    read -q "REPLY?⚠️  This will delete app data. Continue? [y/N] " || { echo "\nAborted."; exit 0; }
    echo ""
fi

before=$(df ~/ | awk 'NR==2 {print $4*1024}')

# BREW FIRST POLICY
echo "  brew cleanup"
$what_if || { brew cleanup 2>/dev/null || true; }

# 1. Microsoft (post-teams-clean)
echo "  Removing: Microsoft Library data"
if ! $what_if; then
    pkill -f 'Microsoft' 2>/dev/null || true
    rm -rf ~/Library/{Application\ Support,Containers,Caches,Group\ Containers}/Microsoft* \
           ~/Library/Group\ Containers/UBF8T346G9.* 2>/dev/null || true
fi

# 2. NON-WORK APPS
for app in Kiro Comet zoom.us; do
    echo "  Removing: $app"
    if ! $what_if; then
        brew uninstall --cask "$app" 2>/dev/null || brew uninstall "$app" 2>/dev/null || true
        rm -rf ~/Library/Application\ Support/"$app"* ~/Library/Containers/"$app"* ~/Library/Caches/"$app"* 2>/dev/null || true
    fi
done

# 3. Apple Music Artwork
echo "  Removing: Apple Music artwork cache"
$what_if || { rm -rf ~/Library/Containers/com.apple.AMPArtworkAgent 2>/dev/null || true; }

# 4. Dev Caches (VS Code/Edge safe trim)
echo "  Removing: Dev caches (VS Code, Edge, Xcode, brew, pip, node-gyp)"
if ! $what_if; then
    find ~/Library/Application\ Support/Code \( -name "CachedExtensions" -o -name "workspaceStorage" \) -print0 2>/dev/null | xargs -0 rm -rf 2>/dev/null || true
    find ~/Library/Application\ Support/Microsoft\ Edge \( -name Cache -o -name "Code Cache" \) -print0 2>/dev/null | xargs -0 rm -rf 2>/dev/null || true
    rm -rf ~/Library/Caches/{Homebrew,pip,node-gyp,go-build,bun,com.microsoft.*VSCode*} 2>/dev/null || true
    rm -rf ~/Library/Developer/Xcode/DerivedData/* 2>/dev/null || true
fi

if ! $what_if; then
    after=$(df ~/ | awk 'NR==2 {print $4*1024}')
    saved_mb=$(((after-before)/1024))
    echo "✅ TOTAL SAVED: ${saved_mb}MB | $(df -h ~ | awk 'NR==2 {print $4}')"
else
    echo ""
    echo "To execute: $0 --force"
fi
