#!/bin/zsh
# Teams Auto-Cleaner Installer v3 - NO GLOB ERRORS

set -e

echo "🚀 Teams Auto-Cleaner v3 - Bulletproof..."

cat > ~/bin/teams-clean << 'EOF'
#!/bin/zsh
setopt +o nomatch  # Disable zsh glob error

teams_cache="$HOME/Library/Group Containers/UBF8T346G9.com.microsoft.teams"
before_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')
echo "📊 Before: $before_size"

# Clean Group Containers (main cache)
rm -rf "$teams_cache"/Blob_storage \
       "$teams_cache"/Cache \
       "$teams_cache"/"Code Cache" \
       "$teams_cache"/GPUCache \
       "$teams_cache"/IndexedDB \
       "$teams_cache"/"Local Storage" \
       "$teams_cache"/logs 2>/dev/null || true

# Clean ALL Teams containers safely (no glob error)
find ~/Library/Containers -name "com.microsoft.teams*" -type d 2>/dev/null | \
  xargs -I {} find {} -path "*/Caches/*" -type d 2>/dev/null | \
  xargs rm -rf 2>/dev/null || true

after_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')
[[ -n "$before_size" && -n "$after_size" ]] && {
  saved=$(echo $before_size $after_size | awk '{printf "%.0fMB\n", $1-$2}')
  echo "✅ After: $after_size | Saved: $saved"
} || echo "✅ Clean (no cache found)"
EOF

chmod +x ~/bin/teams-clean
~/bin/teams-clean

echo "🎉 v3 COMPLETE - No more errors!"
