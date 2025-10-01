#!/bin/bash
#
# Automated VM Creation Script for Malware Inspection Sandbox
# This script creates a UTM VM using VIRTUALIZE mode (much faster than emulate!)
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SHARED_DIR="${SCRIPT_DIR}/shared"
ISO_PATH="${SCRIPT_DIR}/alpine.iso"

echo "========================================"
echo "Creating Inspection Sandbox VM"
echo "========================================"

# Check if VM already exists
if utmctl status "${VM_NAME}" &>/dev/null; then
    echo "❌ VM '${VM_NAME}' already exists!"
    echo "To recreate, first run: ./setup_sandbox.sh burn"
    exit 1
fi

# Check for ISO
if [ ! -f "${ISO_PATH}" ]; then
    echo "❌ Alpine Linux ISO not found at: ${ISO_PATH}"
    echo "Run: ./setup_sandbox.sh"
    exit 1
fi

# Create shared directory if it doesn't exist
mkdir -p "${SHARED_DIR}"

echo ""
echo "📦 Creating VM with VIRTUALIZE mode (native performance)..."
echo ""

# Create the VM using UTM CLI
# Note: UTM CLI is limited, so we'll provide clear manual instructions

cat <<'EOF'

⚠️  UTM doesn't support full CLI automation yet. Follow these steps:

1. Open UTM app
2. Click "+" (Create a New Virtual Machine)
3. Select "Virtualize" (NOT Emulate - much faster!)
4. Select "Linux"
5. Use these settings:

   **Boot ISO Image:**
   Browse and select: alpine.iso (in this directory)

   **Hardware:**
   - RAM: 2048 MB
   - CPU Cores: 2

   **Storage:**
   - Size: 8 GB
   - Leave other settings as default

   **Shared Directory:**
   - Browse and select the "shared" directory in this folder
   - IMPORTANT: Click "Advanced" and set to "Read Only"

   **Summary:**
   - Name: inspection-sandbox
   - Click "Save"

6. BEFORE starting the VM, click the VM name, then click the 🎛️ (Edit) icon:

   **Network Tab:**
   - Network Mode: "Emulated VLAN"
   - ✅ Show Advanced Settings
   - ✅ Isolate Guest from Host

   **Port Forwarding (under Network):**
   - Click "New..."
   - Protocol: TCP
   - Guest Port: 22
   - Host Address: 127.0.0.1
   - Host Port: 2222

   **Sharing Tab:**
   - ✅ Directory Share Mode: VirtFS
   - Shared Directory: (should already be set to "shared" folder)
   - ❌ Uncheck "Enable Clipboard Sharing"

7. Save the settings

8. Start the VM and run: ./provision-vm.sh

EOF

echo ""
echo "After creating the VM as described above, run:"
echo "  ./provision-vm.sh"
echo ""
