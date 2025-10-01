#!/bin/bash
#
# VM Creation Script for Malware Inspection Sandbox
# Uses Emulate mode due to Virtualize mode UEFI boot issues
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
echo "📦 Creating VM with EMULATE mode..."
echo ""
echo "⚠️  NOTE: We use Emulate mode because Virtualize mode has UEFI boot issues with Alpine ISO."
echo ""

cat <<'EOF'

UTM doesn't support full CLI automation. Follow these steps:

1. Open UTM app
2. Click "+" (Create a New Virtual Machine)
3. Select "Emulate" (NOT Virtualize - boot compatibility)
4. Select "Other"
5. Skip ISO for now (we'll add it in settings)
6. Use these settings:

   **Architecture:** x86_64
   **RAM:** 2048 MB
   **CPU Cores:** 2

7. **Storage:**
   - Size: 8 GB
   - Leave other settings as default

8. **Shared Directory:**
   - Browse and select the "shared" directory in this folder
   - Set to "Read Only"

9. **Summary:**
   - Name: inspection-sandbox
   - Click "Save"

10. AFTER creating the VM, click the VM name, then click the 🎛️ (Edit) icon:

    **Add the Alpine ISO:**
    - Look for "Drives" section in the left sidebar
    - Click "New..." or "+"
    - Select "Removable" or "CD/DVD"
    - Browse and select: alpine.iso (in this directory)

    **Network Tab:**
    - Network Mode: "Shared Network" (we'll isolate it AFTER installation)
    - Do NOT check "Isolate Guest from Host" yet

    **Port Forwarding (under Network):**
    - Click "New..."
    - Protocol: TCP
    - Guest Port: 22
    - Host Address: 127.0.0.1
    - Host Port: 2222

    **Sharing Tab:**
    - Directory Share Mode: VirtFS (won't work with standard Alpine, but set it anyway)
    - ❌ Uncheck "Enable Clipboard Sharing"

11. Save the settings

12. Start the VM and follow the installation instructions in:
    ./ACTUAL-WORKING-SETUP.md

    Key steps:
    - Login as root (no password)
    - Run: setup-alpine
    - Follow prompts
    - After install, use HTTP server method to transfer SSH key

EOF

echo ""
echo "After creating the VM, follow the setup guide:"
echo "  cat ACTUAL-WORKING-SETUP.md"
echo ""
echo "Or use the automated provisioning script (experimental):"
echo "  ./provision-vm.sh"
echo ""
