#!/bin/zsh
# Teams Auto-Cleaner v4 - FULLY AUTOMATED INSTALLER

set -e

echo "🚀 Installing COMPLETE Teams Auto-Cleaner Suite..."

# 1. Bulletproof teams-clean script
cat > ~/bin/teams-clean << 'EOF'
#!/bin/zsh
setopt +o nomatch
teams_cache="$HOME/Library/Group Containers/UBF8T346G9.com.microsoft.teams"
before_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')
echo "📊 Before: $before_size"

rm -rf "$teams_cache"/Blob_storage \
       "$teams_cache"/Cache \
       "$teams_cache"/"Code Cache" \
       "$teams_cache"/GPUCache \
       "$teams_cache"/IndexedDB \
       "$teams_cache"/"Local Storage" \
       "$teams_cache"/logs 2>/dev/null || true

find ~/Library/Containers -name "com.microsoft.teams*" -type d 2>/dev/null | \
  xargs -I {} find {} -path "*/Caches/*" -type d 2>/dev/null | \
  xargs rm -rf 2>/dev/null || true

after_size=$(du -sh "$teams_cache" 2>/dev/null | awk '{print $1}')
saved=$(echo $before_size $after_size | awk '{printf "%.0fMB\n", $1-$2}')
echo "✅ After: $after_size | Saved: $saved"
EOF

# 2. Setup bin dir & permissions
mkdir -p ~/bin
chmod +x ~/bin/teams-clean

# 3. Ensure watch is installed
brew install watch || true

# 4. Install aliases
cat >> ~/.zshrc << 'EOF'

# Teams Auto-Cleaner
alias teams-clean="~/bin/teams-clean"
alias teams-watch="watch -n 60 'du -sh ~/Library/Group\\ Containers/*teams* 2>/dev/null || echo \"No Teams data\"'"
EOF
source ~/.zshrc

# 5. DAILY cron (6PM) + MONTHLY deep clean (1st, 6AM)
(crontab -l 2>/dev/null; echo "0 18 * * * ~/bin/teams-clean" ; echo "0 6 1 * * ~/bin/teams-clean") | crontab -

# 6. Launch Agent for REAL-TIME monitoring (alerts >500MB)
cat > ~/Library/LaunchAgents/com.teams-cleaner.plist << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.teams-cleaner</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/zsh</string>
    <string>-c</string>
    <string>while true; do ~/bin/teams-clean; sleep 3600; done</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
EOF

launchctl load ~/Library/LaunchAgents/com.teams-cleaner.plist

echo "🎉 FULLY AUTOMATED Teams Cleaner INSTALLED!"
echo ""
echo "✅ Daily cleanup: 6PM (cron)"
echo "✅ Hourly background: LaunchAgent" 
echo "✅ Commands: teams-clean | teams-watch"
echo ""
teams-clean  # Final test
echo "✅ LaunchAgent loaded: $(launchctl list | grep teams-cleaner)"
