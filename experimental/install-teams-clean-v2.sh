#!/bin/zsh
# Teams Auto-Cleaner Installer v2 - FIXED

set -e

echo "🚀 Reinstalling Teams Auto-Cleaner (Fixed)..."

cat > ~/bin/teams-clean << 'EOF'
#!/bin/zsh
teams_cache="$HOME/Library/Group Containers/UBF8T346G9.com.microsoft.teams"
before_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')

echo "📊 Teams Cache Before: $before_size"

# Safe rm - skip missing globs
rm -rf "$teams_cache"/Blob_storage \
       "$teams_cache"/Cache \
       "$teams_cache"/"Code Cache" \
       "$teams_cache"/GPUCache \
       "$teams_cache"/IndexedDB \
       "$teams_cache"/"Local Storage" \
       "$teams_cache"/logs

# Handle missing containers safely
for dir in ~/Library/Containers/com.microsoft.teams*/Data/Library/Caches/*; do
  [[ -e "$dir" ]] && rm -rf "$dir"
done

after_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')
saved=$(echo $before_size $after_size | awk '{printf "%.0fMB\n", $1-$2}')
echo "✅ After: $after_size | Saved: $saved"
EOF

chmod +x ~/bin/teams-clean

echo "🎉 Fixed & Reinstalled!"
echo "Test run:"
~/bin/teams-clean

echo ""
echo "✅ Ready: ~/bin/teams-clean | teams-watch | crontab -l | grep teams"
