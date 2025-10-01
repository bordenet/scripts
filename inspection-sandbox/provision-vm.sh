#!/bin/bash
#
# VM Provisioning Script
# Run this AFTER creating the VM and installing Alpine Linux
# This script helps automate SSH key setup using HTTP server method
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SSH_KEY="${SCRIPT_DIR}/id_rsa"
SSH_PORT=2222

echo "========================================"
echo "Provisioning Inspection Sandbox VM"
echo "========================================"
echo ""

# Check if VM exists
if ! utmctl status "${VM_NAME}" &>/dev/null; then
    echo "❌ VM '${VM_NAME}' not found!"
    echo "Create it first: ./create-vm.sh"
    exit 1
fi

# Check if VM is running
if ! utmctl status "${VM_NAME}" | grep -q "started"; then
    echo "⚠️  VM is not running. Start it first in UTM."
    exit 1
fi

echo "This script will help you set up SSH access to the VM."
echo ""
echo "PREREQUISITES:"
echo "1. You've installed Alpine Linux in the VM using setup-alpine"
echo "2. The VM is currently running with SHARED NETWORK (not isolated yet)"
echo "3. You have network connectivity from the VM"
echo ""
read -p "Have you completed Alpine installation? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please complete Alpine installation first. See ACTUAL-WORKING-SETUP.md"
    exit 1
fi

echo ""
echo "📡 Starting HTTP server to transfer SSH key..."
echo ""

# Start Python HTTP server in background
python3 -m http.server 8000 &
HTTP_PID=$!

# Ensure we kill the server on exit
trap "kill $HTTP_PID 2>/dev/null || true" EXIT

echo "✅ HTTP server running on port 8000 (PID: $HTTP_PID)"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "NOW, IN THE VM CONSOLE, run these commands:"
echo ""
cat <<'VMCMDS'
# Ensure network is up
ifconfig eth0 up
udhcpc -i eth0

# Get host IP (look for "via" address)
ip route | grep default

# Download SSH key (replace HOST_IP with the IP from above, usually 192.168.64.1)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
wget http://HOST_IP:8000/id_rsa.pub -O /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Verify the key was downloaded
cat /root/.ssh/authorized_keys

# Install and start SSH if not already done
apk update
apk add openssh bash curl
rc-update add sshd
service sshd start

# Shutdown the VM
poweroff
VMCMDS

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⏳ Waiting for VM to download the SSH key..."
echo "   (The HTTP server will show the request when it happens)"
echo ""
echo "Press CTRL+C when the VM has shut down."
echo ""

# Wait for interrupt
wait $HTTP_PID 2>/dev/null || true

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "AFTER THE VM SHUTS DOWN:"
echo ""
echo "1. Edit VM in UTM → Network tab"
echo "2. Change to 'Emulated VLAN'"
echo "3. ✅ Check 'Isolate Guest from Host'"
echo "4. Save"
echo ""
echo "5. (Optional) Remove the Alpine ISO from the VM drives"
echo ""
echo "6. Start the VM and test SSH:"
echo "   ./status.sh"
echo ""
echo "If SSH works, you're done! Use ./inspect.sh to analyze files."
echo ""
