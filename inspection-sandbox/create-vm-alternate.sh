#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: create-vm-alternate.sh
#
# Description: This script provides an alternate method for creating the
#              inspection sandbox VM. It extracts the kernel and initrd from
#              the Alpine ISO to work around potential UEFI boot issues in
#              UTM's "Virtualize" mode. It then presents the user with
#              several manual installation options.
#
# Usage: ./create-vm-alternate.sh
#
# Dependencies: hdiutil (macOS), cp
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Script Setup ---
start_time=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SHARED_DIR="${SCRIPT_DIR}/shared"
ISO_PATH="${SCRIPT_DIR}/alpine.iso"
BOOT_FILES_DIR="${SCRIPT_DIR}/boot-files"

# --- Main Script ---
echo "======================================================"
echo "  Creating Inspection Sandbox VM (Alternate Method)"
echo "======================================================"

# 1. Check for the Alpine ISO
echo -n "Checking for Alpine ISO... "
if [ ! -f "${ISO_PATH}" ]; then
    echo "❌ Not found at: ${ISO_PATH}"
    echo "Please run './setup_sandbox.sh' first to download it."
    exit 1
fi
echo "✅ Found."

# 2. Extract boot files from the ISO
echo "📦 Extracting boot files from ISO..."
mkdir -p "${BOOT_FILES_DIR}"

# Mount the ISO (macOS specific)
echo -n "   - Mounting ISO... "
MOUNT_POINT=$(hdiutil attach "${ISO_PATH}" | grep Volumes | awk '{print $3}')
if [ -z "$MOUNT_POINT" ]; then
    echo "❌ Failed to mount ISO."
    exit 1
fi
echo "✅ Mounted at: $MOUNT_POINT"

# Copy kernel and initramfs
echo -n "   - Copying kernel and initramfs... "
cp "${MOUNT_POINT}/boot/vmlinuz-lts" "${BOOT_FILES_DIR}/" 2>/dev/null || \
cp "${MOUNT_POINT}/boot/vmlinuz-virt" "${BOOT_FILES_DIR}/" 2>/dev/null || \
{ echo "⚠️ Could not find kernel file."; }

cp "${MOUNT_POINT}/boot/initramfs-lts" "${BOOT_FILES_DIR}/" 2>/dev/null || \
cp "${MOUNT_POINT}/boot/initramfs-virt" "${BOOT_FILES_DIR}/" 2>/dev/null || \
{ echo "⚠️ Could not find initramfs file."; }
echo "✅ Done."

# Unmount the ISO
echo -n "   - Unmounting ISO... "
hdiutil detach "$MOUNT_POINT" >/dev/null 2>&1
echo "✅ Unmounted."

# 3. Display manual instructions
cat <<'EOF'

======================================================
  ⚠️  MANUAL VM CREATION REQUIRED  ⚠️
======================================================

The boot files have been extracted, but due to potential UEFI boot issues
with UTM's "Virtualize" mode, manual setup is recommended.

Please choose one of the following options:

--- OPTION 1: Use UTM "Emulate" Mode (Recommended) ---

This mode is slower but has better compatibility with bootable ISOs.

1.  Open UTM.
2.  Click "Create a New Virtual Machine".
3.  Select "Emulate".
4.  Select "Other".
5.  Skip ISO for now.
6.  Architecture: x86_64
7.  Memory: 2048 MB, CPU Cores: 2
8.  Specify a storage size (e.g., 8 GB).
9.  Select the 'shared' directory for sharing.
10. Name the VM "inspection-sandbox" and save.

After creation, go to the VM settings:
-   Add a new CD/DVD Drive and select the 'alpine.iso' file.
-   Ensure the boot order is set to boot from the CD/DVD drive first.
-   Configure network (e.g., "Shared Network") and any port forwards.
-   Boot the VM and follow the standard Alpine installation.

--- OPTION 2: Use VirtualBox (Alternative) ---

If you have VirtualBox installed, it often handles Alpine Linux well.

1.  Install VirtualBox: `brew install --cask virtualbox`
2.  Create a new Linux VM, pointing to the `alpine.iso` as the installation medium.

------------------------------------------------------

EOF

# --- Completion ---
end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo "Script finished in ${execution_time} seconds."
echo "Next step is to follow the manual instructions above."