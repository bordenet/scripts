#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: create-vm.sh
#
# Description: This script provides detailed manual instructions for creating the
#              malware inspection sandbox VM using UTM. It guides the user
#              through the process of setting up the VM in "Emulate" mode,
#              which is recommended for compatibility with the Alpine Linux ISO.
#
# Usage: ./create-vm.sh
#
# Dependencies: utmctl (for checking VM status)
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Script Setup ---
start_time=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SHARED_DIR="${SCRIPT_DIR}/shared"
ISO_PATH="${SCRIPT_DIR}/alpine.iso"

# --- Pre-flight Checks ---
echo "========================================"
echo "  Inspection Sandbox VM Creation Guide"
echo "========================================"

echo -n "Checking for existing VM named '${VM_NAME}'... "
if utmctl status "${VM_NAME}" &>/dev/null; then
    echo "❌ Found."
    echo "A VM with this name already exists. To recreate it, please delete the existing VM in UTM first, or run './setup_sandbox.sh burn'."
    exit 1
fi
echo "✅ Not found."

echo -n "Checking for Alpine Linux ISO... "
if [ ! -f "${ISO_PATH}" ]; then
    echo "❌ Not found at: ${ISO_PATH}"
    echo "Please run './setup_sandbox.sh' first to download it."
    exit 1
fi
echo "✅ Found."

# Create shared directory if it doesn't exist
mkdir -p "${SHARED_DIR}"

# --- Instructions ---
echo ""
echo "⚠️ This script provides MANUAL instructions. UTM does not support fully automated VM creation from the CLI."
echo ""

cat <<'EOF'
Please follow these steps carefully in the UTM application:

--- PART 1: Create the Virtual Machine ---

1.  Open the UTM application.
2.  Click the "+" button to "Create a New Virtual Machine".
3.  Select "Emulate" (do NOT use "Virtualize" for better ISO boot compatibility).
4.  Select "Other".
5.  Click "Skip ISO boot". We will add it later in the settings.
6.  Configure the hardware:
    - Architecture: x86_64
    - Memory: 2048 MB
    - CPU Cores: 2
7.  Configure storage:
    - Size: 8 GB (or more)
8.  Configure shared directory:
    - Click "Browse" and select the "shared" directory located in this project folder.
    - You can leave it as "Read & Write" for now.
9.  On the Summary screen:
    - Name the VM: inspection-sandbox
    - Check "Open VM Settings".
    - Click "Save".

--- PART 2: Configure VM Settings ---

The VM settings should open automatically. If not, select the VM and click the "Edit" (🎛️) icon.

1.  In the "Drives" section:
    - Click "New...".
    - Select "Removable" (or "CD/DVD").
    - In the "Image" dropdown, select "Browse..." and choose the `alpine.iso` file from this project directory.

2.  In the "Network" section:
    - Network Mode: "Shared Network".
    - **Port Forwarding**: Click "New..." and add the following rule for SSH access:
        - Protocol: TCP
        - Guest Port: 22
        - Host Port: 2222

3.  In the "Sharing" section:
    - Uncheck "Enable Clipboard Sharing" for better isolation.

4.  Save the settings.

--- PART 3: Install Alpine Linux ---

1.  Start the VM. It should boot from the Alpine ISO.
2.  Follow the detailed installation and setup guide here:
    `ACTUAL-WORKING-SETUP.md`

    Key steps include:
    - Logging in as `root`.
    - Running `setup-alpine`.
    - Partitioning the disk and installing the OS.
    - Transferring your SSH key to the guest for passwordless access.

EOF

# --- Completion ---
end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo "----------------------------------------"
echo "End of instructions."
echo "Script finished in ${execution_time} seconds."
echo "Your next step is to follow the manual instructions above in the UTM app."