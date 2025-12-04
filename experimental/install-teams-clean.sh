#!/bin/zsh
# Teams Auto-Cleaner Installer - Single Script Solution

set -e

echo "🚀 Installing Teams Auto-Cleaner..."

# 1. Create cleaned-up teams-clean script
cat > ~/bin/teams-clean << 'EOF'
#!/bin/zsh
teams_cache="$HOME/Library/Group Containers/UBF8T346G9.com.microsoft.teams"
before_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')
echo "📊 Teams Cache Before: $before_size"

rm -rf "$teams_cache"/{Blob_storage,Cache,"Code Cache",GPUCache,IndexedDB,"Local Storage",logs}
rm -rf ~/Library/Containers/com.microsoft.teams*/Data/Library/Caches/*

after_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')
[[ -n "$before_size" && -n "$after_size" ]] && {
  saved=$(echo $before_size $after_size | awk '{printf "%.0fMB\n", $1-$2}')
  echo "✅ After: $after_size | Saved: $saved"
} || echo "✅ Cleanup complete"
EOF

# 2. Make executable & create bin dir
mkdir -p ~/bin
chmod +x ~/bin/teams-clean

# 3. Install watch (for monitoring)
brew install watch

# 4. Add weekly cron (Monday 6PM)
(crontab -l 2>/dev/null; echo "0 18 * * 1 ~/bin/teams-clean") | crontab -

# 5. Create monitor alias
echo 'alias teams-watch="watch -n 60 '\''du -sh ~/Library/Group\\ Containers/*teams* 2>/dev/null || echo \\"No Teams data\\"'\''"' >> ~/.zshrc
source ~/.zshrc

echo "🎉 Installed! Usage:"
echo "   ~/bin/teams-clean          # Run now"
echo "   teams-watch                # Monitor live"
echo "   crontab -l | grep teams    # Check cron"
echo ""
~/bin/teams-clean  # Test run
