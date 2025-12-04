#!/bin/zsh
setopt +o nomatch
echo "🔄 DAILY TRIM (Work-Safe)"

brew cleanup
rm -rf ~/Library/Caches/{Homebrew,pip,node-gyp,go-build,bun,com.microsoft.*VSCode*}
find ~/Library/Developer/Xcode/DerivedData -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
rm -rf ~/Library/Containers/com.apple.AMPArtworkAgent

df -h ~ | awk 'NR==2 {print "📊 Free: " $4}'
