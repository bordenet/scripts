#!/bin/zsh
# Usage: app-nuke Kiro
app=$1
if [[ -z "$app" ]]; then echo "Usage: app-nuke <appname>"; exit 1; fi

echo "🎯 TARGETING: $app"
brew uninstall --cask "$app" 2>/dev/null || brew uninstall "$app" 2>/dev/null
before=$(du -sh ~/Library/*/"$app"* 2>/dev/null | awk '{sum+=$1} END {print sum}')
rm -rf ~/Library/{Application\ Support,Containers,Caches}/"$app"*
echo "✅ $app: $before → GONE"
