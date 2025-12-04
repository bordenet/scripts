#!/bin/zsh
setopt +o nomatch

echo "💣 DISK-MASTER: TOTAL NUCLEAR CLEANUP"
before=$(df ~/ | awk 'NR==2 {print $4*1024}')

# BREW FIRST POLICY
brew cleanup

# 1. Microsoft (post-teams-clean)
pkill -f 'Microsoft' 2>/dev/null || true
rm -rf ~/Library/{Application\ Support,Containers,Caches,Group\ Containers}/Microsoft* \
       ~/Library/Group\ Containers/UBF8T346G9.*

# 2. NON-WORK APPS (Kiro/Comet/Zoom)
for app in Kiro Comet zoom.us; do
  brew uninstall --cask "$app" 2>/dev/null || brew uninstall "$app" 2>/dev/null
  rm -rf ~/Library/{Application\ Support,Containers,Caches}/"$app"*
done

# 3. Apple Music Artwork
rm -rf ~/Library/Containers/com.apple.AMPArtworkAgent

# 4. Dev Caches (VS Code/Edge safe trim)
find ~/Library/Application\ Support/Code -name "CachedExtensions" -o -name "workspaceStorage" | xargs rm -rf 2>/dev/null
find ~/Library/Application\ Support/Microsoft\ Edge -name Cache -o -name "Code Cache" | xargs rm -rf 2>/dev/null
rm -rf ~/Library/Caches/{Homebrew,pip,node-gyp,go-build,bun,com.microsoft.*VSCode*}
rm -rf ~/Library/Developer/Xcode/DerivedData/*

after=$(df ~/ | awk 'NR==2 {print $4*1024}')
saved_mb=$(((before-after)/1024))
echo "✅ TOTAL SAVED: ${saved_mb}MB | $(df -h ~ | awk 'NR==2 {print $4}')"
