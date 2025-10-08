#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: provision-vm.sh
#
# Description: This script helps automate the final provisioning steps for the
#              inspection sandbox VM after Alpine Linux has been installed.
#              It starts a local HTTP server to facilitate transferring the
#              SSH public key to the VM, then provides manual instructions
#              for the user to execute within the VM console.
#
# Usage: ./provision-vm.sh
#
# Prerequisites:
#   - The VM has been created using 'create-vm.sh'.
#   - Alpine Linux has been installed inside the VM via 'setup-alpine'.
#   - The VM is running with a "Shared Network" connection.
#
# Dependencies: utmctl, python3
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit on error, undefined variable, or pipe failure
set -euo pipefail

# --- Script Setup ---
start_time=$(date +%s)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SSH_PUB_KEY="${SCRIPT_DIR}/id_rsa.pub"

# --- Pre-flight Checks ---
echo "=========================================="
echo "  Provisioning Inspection Sandbox VM"
echo "=========================================="
echo ""

echo -n "Checking for VM '${VM_NAME}'... "
if ! utmctl status "${VM_NAME}" &>/dev/null; then
    echo "❌ Not found. Please create it first using './create-vm.sh'."
    exit 1
fi
echo "✅ Found."

echo -n "Checking if VM is running... "
if ! utmctl status "${VM_NAME}" | grep -q "started"; then
    echo "❌ Not running. Please start the VM in UTM."
    exit 1
fi
echo "✅ Running."

echo -n "Checking for SSH public key... "
if [ ! -f "$SSH_PUB_KEY" ]; then
    echo "❌ Not found at ${SSH_PUB_KEY}."
    echo "Please run './setup_sandbox.sh' to generate the key pair."
    exit 1
fi
echo "✅ Found."

echo ""
echo "This script will guide you through setting up SSH access to the VM."
echo ""
read -p "Have you already completed the 'setup-alpine' process inside the VM? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please complete the Alpine Linux installation inside the VM before continuing."
    exit 1
fi

# --- Main Process ---
echo ""
echo "📡 Starting a temporary HTTP server to transfer the SSH key..."
echo ""

# Start Python HTTP server in the background in the script's directory.
pushd "$SCRIPT_DIR" > /dev/null
python3 -m http.server 8000 &
HTTP_PID=$!
popd > /dev/null

# Ensure the server is killed on script exit.
trap "echo; echo 'Shutting down HTTP server...'; kill $HTTP_PID 2>/dev/null || true" EXIT

echo "✅ HTTP server is running on port 8000 (PID: $HTTP_PID)."
echo "   It is serving files from: $SCRIPT_DIR"
echo ""
echo "------------------------------------------------------------------------------"
echo "  ACTION REQUIRED: Execute the following commands inside the VM's console"
echo "------------------------------------------------------------------------------"
cat <<'VMCMDS'

# 1. Enable networking and get an IP address
ifconfig eth0 up
udhcpc -i eth0

# 2. Find your host machine's IP address (look for the 'default via' IP)
ip route

# 3. Download the SSH key from your host (REPLACE 'HOST_IP' with the IP from step 2)
mkdir -p /root/.ssh
chmod 700 /root/.ssh
wget http://HOST_IP:8000/id_rsa.pub -O /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys

# 4. Verify the key was downloaded correctly
cat /root/.ssh/authorized_keys

# 5. Install required packages and enable SSH server
apk update
apk add openssh bash curl
rc-update add sshd
service sshd start

# 6. Shut down the VM
poweroff

VMCMDS
echo "------------------------------------------------------------------------------"
echo ""
echo "⏳ Waiting for the VM to download the key..."
echo "   (The running terminal will show a log when 'id_rsa.pub' is requested)."
echo "   Once the VM has powered off, press Ctrl+C here to continue."
echo ""

# Wait for the user to interrupt.
wait $HTTP_PID 2>/dev/null || true

echo ""
echo "------------------------------------------------------------------------------"
echo "  FINAL STEPS: Isolate the VM Network"
echo "------------------------------------------------------------------------------"
echo ""
echo "1. In the UTM app, edit the '${VM_NAME}' settings."
echo "2. Go to the 'Network' tab."
echo "3. Change 'Network Mode' to 'Emulated VLAN'."
echo "4. CHECK the box for 'Isolate Guest from Host'."
echo "5. Save the settings."
echo "6. (Optional) Remove the Alpine ISO from the VM's drives."
echo ""
echo "✅ Provisioning is complete!"
echo "You can now start the VM and use './status.sh' or './inspect.sh'."
echo ""

# --- Completion ---
end_time=$(date +%s)
execution_time=$((end_time - start_time))
echo "Total script execution time: ${execution_time} seconds."