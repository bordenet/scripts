#!/bin/bash
#
# Alternate VM Creation Method - Boot Alpine directly without CD-ROM
# This works around UEFI boot issues with UTM Virtualize mode
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SHARED_DIR="${SCRIPT_DIR}/shared"
ISO_PATH="${SCRIPT_DIR}/alpine.iso"

echo "========================================"
echo "Creating Inspection Sandbox VM (Alternate Method)"
echo "========================================"

# Check for ISO
if [ ! -f "${ISO_PATH}" ]; then
    echo "❌ Alpine Linux ISO not found at: ${ISO_PATH}"
    echo "Run: ./setup_sandbox.sh"
    exit 1
fi

# Extract kernel and initrd from ISO
echo "📦 Extracting boot files from ISO..."
mkdir -p "${SCRIPT_DIR}/boot-files"

# Mount the ISO (macOS)
MOUNT_POINT=$(hdiutil attach "${ISO_PATH}" | grep Volumes | awk '{print $3}')

if [ -z "$MOUNT_POINT" ]; then
    echo "❌ Failed to mount ISO"
    exit 1
fi

echo "✅ ISO mounted at: $MOUNT_POINT"

# Copy boot files
if [ -d "${MOUNT_POINT}/boot" ]; then
    cp "${MOUNT_POINT}/boot/vmlinuz-lts" "${SCRIPT_DIR}/boot-files/" 2>/dev/null || \
    cp "${MOUNT_POINT}/boot/vmlinuz-virt" "${SCRIPT_DIR}/boot-files/" 2>/dev/null || \
    echo "⚠️  Could not find kernel"

    cp "${MOUNT_POINT}/boot/initramfs-lts" "${SCRIPT_DIR}/boot-files/" 2>/dev/null || \
    cp "${MOUNT_POINT}/boot/initramfs-virt" "${SCRIPT_DIR}/boot-files/" 2>/dev/null || \
    echo "⚠️  Could not find initramfs"
fi

# Unmount
hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1

cat <<'EOF'

⚠️  ALTERNATE INSTALLATION METHOD

Due to UEFI boot issues with UTM's Virtualize mode, we recommend
a simpler approach:

**OPTION 1: Use VirtualBox Instead (Easier)**

1. Install VirtualBox: brew install --cask virtualbox
2. VirtualBox has better Alpine Linux support
3. Let me know if you want instructions for VirtualBox

**OPTION 2: Use UTM Emulate Mode (Slower but Works)**

UTM's Emulate mode has better ISO boot support:

1. Open UTM
2. Create New VM
3. Select "Emulate" (NOT Virtualize)
4. Select "Other"
5. Skip ISO for now
6. Architecture: x86_64
7. RAM: 2048 MB, CPU: 2
8. Storage: 8 GB
9. Shared Directory: (select the shared folder)
10. Name: inspection-sandbox

Then in settings:
- Add the alpine.iso as a removable drive
- Configure network isolation and port forwarding as before
- Boot order should work correctly

**OPTION 3: Install Alpine Manually via Console**

If you want to stick with Virtualize mode, you can:
1. Download Alpine "netboot" version instead
2. Or install Alpine step-by-step via serial console

Which approach do you prefer?

EOF
