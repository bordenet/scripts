#!/bin/bash

# Script to check if we're using the latest Alpine Linux version
# Run this periodically to see if an update is available

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

CURRENT_VERSION=$(grep "^ALPINE_VERSION=" setup_sandbox.sh | cut -d'"' -f2 | head -1)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Alpine Linux Version Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Current version: $CURRENT_VERSION"
echo ""
echo "Checking Alpine Linux website for latest stable..."
echo ""

# Check the official Alpine downloads page
curl -s https://alpinelinux.org/downloads/ | grep -o "alpine-virt-[0-9]\+\.[0-9]\+\.[0-9]\+-x86_64.iso" | head -1 | sed 's/alpine-virt-/Latest version:  /' | sed 's/-x86_64.iso//'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [ -f "alpine.iso" ]; then
    LOCAL_SIZE=$(ls -lh alpine.iso | awk '{print $5}')
    echo "✅ Local alpine.iso exists ($LOCAL_SIZE)"
else
    echo "❌ No alpine.iso found - run ./setup_sandbox.sh to download"
fi

echo ""
echo "📝 To update to a new version:"
echo "   1. Edit setup_sandbox.sh"
echo "   2. Change ALPINE_VERSION=\"$CURRENT_VERSION\" to the new version"
echo "   3. Remove alpine.iso: rm alpine.iso"
echo "   4. Run ./setup_sandbox.sh to download new version"
echo ""
echo "🔗 Manual check: https://alpinelinux.org/downloads/"
echo ""
