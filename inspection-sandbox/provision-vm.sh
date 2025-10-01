#!/bin/bash
#
# VM Provisioning Script
# Run this AFTER installing Alpine Linux in the VM
# This script automates SSH setup and installs analysis tools
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
    echo "🚀 Starting VM..."
    utmctl start "${VM_NAME}"
    echo "⏳ Waiting 30 seconds for VM to boot..."
    sleep 30
fi

echo "📋 MANUAL STEPS REQUIRED IN THE VM:"
echo ""
echo "1. In the VM console, login as 'root' (no password yet)"
echo "2. Run: setup-alpine"
echo "3. Follow the prompts:"
echo "   - Keyboard: us"
echo "   - Hostname: sandbox"
echo "   - Network: eth0"
echo "   - IP address: dhcp"
echo "   - Root password: SET A STRONG PASSWORD"
echo "   - Timezone: (your timezone)"
echo "   - Proxy: none"
echo "   - NTP: chrony"
echo "   - APK mirror: 1 (first option)"
echo "   - SSH: openssh"
echo "   - Disk: sda"
echo "   - Use: sys"
echo ""
echo "4. After installation, run these commands in the VM:"
echo ""
cat <<'VMEOF'
# Enable SSH and configure it
rc-update add sshd
echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config

# Install required packages
apk add bash curl sudo

# Create mount point for shared directory
mkdir -p /media/shared

# Add to fstab for auto-mounting
echo "shared /media/shared 9p trans=virtio,version=9p2000.L,ro,_netdev 0 0" >> /etc/fstab

# Mount the shared directory
mount -a

# Setup SSH key
mkdir -p /root/.ssh
chmod 700 /root/.ssh
cat /media/shared/id_rsa.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# Start SSH
service sshd start

# Reboot to ensure everything works
echo "Setup complete! Rebooting..."
reboot
VMEOF

echo ""
echo "5. After VM reboots, press ENTER here to test SSH connection..."
read -r

echo ""
echo "🔍 Testing SSH connection..."

max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if nc -z localhost ${SSH_PORT} 2>/dev/null; then
        echo "✅ SSH port is open"
        break
    fi
    echo "⏳ Waiting for SSH... (attempt $((attempt + 1))/${max_attempts})"
    sleep 2
    attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ SSH port never became available"
    exit 1
fi

echo "🔐 Attempting SSH connection..."
if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=10 -p ${SSH_PORT} root@localhost "echo '✅ SSH connection successful!'; uname -a"; then
    echo ""
    echo "🎉 VM is fully provisioned and ready!"
    echo ""
    echo "Next steps:"
    echo "  - Copy suspicious files to: ${SCRIPT_DIR}/shared/"
    echo "  - Run: ./inspect.sh filename"
else
    echo "❌ SSH connection failed"
    echo "Troubleshooting:"
    echo "  1. Check if SSH is running in VM: service sshd status"
    echo "  2. Check if key is installed: cat /root/.ssh/authorized_keys"
    echo "  3. Check port forwarding in UTM settings"
    exit 1
fi
