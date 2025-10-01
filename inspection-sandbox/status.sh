#!/bin/bash
#
# Status Check Script - Quick health check of the sandbox
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SSH_KEY="${SCRIPT_DIR}/id_rsa"
SSH_PORT=2222

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo ""
echo "========================================"
echo "🔍 Sandbox Status Check"
echo "========================================"
echo ""

# Check dependencies
echo -n "Homebrew: "
if command -v brew &>/dev/null; then
    echo -e "${GREEN}✅ Installed${NC}"
else
    echo -e "${RED}❌ Not found${NC}"
fi

echo -n "UTM: "
if command -v utmctl &>/dev/null; then
    echo -e "${GREEN}✅ Installed${NC}"
else
    echo -e "${RED}❌ Not found${NC}"
fi

# Check for ISO
echo -n "Alpine ISO: "
if [ -f "${SCRIPT_DIR}/alpine.iso" ]; then
    size=$(ls -lh "${SCRIPT_DIR}/alpine.iso" | awk '{print $5}')
    echo -e "${GREEN}✅ Downloaded (${size})${NC}"
else
    echo -e "${RED}❌ Not found${NC} - Run: ./setup_sandbox.sh"
fi

# Check for SSH key
echo -n "SSH Key: "
if [ -f "${SSH_KEY}" ]; then
    echo -e "${GREEN}✅ Generated${NC}"
else
    echo -e "${RED}❌ Not found${NC} - Run: ./setup_sandbox.sh"
fi

# Check for VM
echo -n "VM Status: "
if utmctl status "${VM_NAME}" &>/dev/null; then
    status=$(utmctl status "${VM_NAME}")
    if echo "$status" | grep -q "started"; then
        echo -e "${GREEN}✅ Running${NC}"
    else
        echo -e "${YELLOW}⏸️  Stopped${NC}"
    fi
else
    echo -e "${RED}❌ Not found${NC} - Run: ./create-vm.sh"
fi

# Check SSH connection (if VM is running)
if utmctl status "${VM_NAME}" 2>/dev/null | grep -q "started"; then
    echo -n "SSH Connection: "
    if nc -z localhost ${SSH_PORT} 2>/dev/null; then
        if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p ${SSH_PORT} root@localhost "exit" 2>/dev/null; then
            echo -e "${GREEN}✅ Working${NC}"

            # Get VM info
            echo ""
            echo "VM Information:"
            ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -p ${SSH_PORT} root@localhost "
                echo -n '  OS: '
                cat /etc/os-release | grep PRETTY_NAME | cut -d'\"' -f2
                echo -n '  Uptime: '
                uptime | awk '{print \$3, \$4}' | sed 's/,//'
                echo -n '  Disk: '
                df -h / | tail -1 | awk '{print \$3 \"/\" \$2 \" (\" \$5 \" used)\"}'
                echo -n '  Shared Mount: '
                mount | grep -q '/media/shared' && echo '✅ Mounted' || echo '❌ Not mounted'
                echo -n '  Analysis Tools: '
                [ -f /root/.analysis_tools_installed ] && echo '✅ Installed' || echo '⚠️  Not installed'
            " 2>/dev/null
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    else
        echo -e "${YELLOW}⏸️  Port not accessible${NC}"
    fi
fi

# Check shared directory
echo ""
echo "Shared Directory:"
if [ -d "${SCRIPT_DIR}/shared" ]; then
    file_count=$(ls -1 "${SCRIPT_DIR}/shared" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✅ ${SCRIPT_DIR}/shared${NC}"
    echo "  Files: ${file_count}"
    if [ "$file_count" -gt 0 ]; then
        echo "  Contents:"
        ls -lh "${SCRIPT_DIR}/shared" | tail -n +2 | awk '{print "    - " $9 " (" $5 ")"}'
    fi
else
    echo -e "  ${RED}❌ Not found${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Overall status
vm_exists=false
vm_running=false
ssh_works=false

utmctl status "${VM_NAME}" &>/dev/null && vm_exists=true
utmctl status "${VM_NAME}" 2>/dev/null | grep -q "started" && vm_running=true
if $vm_running; then
    ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p ${SSH_PORT} root@localhost "exit" 2>/dev/null && ssh_works=true
fi

echo ""
if $vm_exists && $vm_running && $ssh_works; then
    echo -e "${GREEN}✅ Sandbox is fully operational!${NC}"
    echo ""
    echo "Ready to inspect files:"
    echo "  ./inspect.sh <filename>"
elif $vm_exists && ! $vm_running; then
    echo -e "${YELLOW}⚠️  VM exists but is not running${NC}"
    echo ""
    echo "Start it with:"
    echo "  utmctl start ${VM_NAME}"
elif $vm_exists && $vm_running && ! $ssh_works; then
    echo -e "${YELLOW}⚠️  VM is running but SSH is not working${NC}"
    echo ""
    echo "Try reprovisioning:"
    echo "  ./provision-vm.sh"
elif ! $vm_exists; then
    echo -e "${YELLOW}⚠️  VM not created yet${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. ./setup_sandbox.sh (if not done)"
    echo "  2. ./create-vm.sh"
    echo "  3. ./provision-vm.sh"
else
    echo -e "${RED}❌ Sandbox needs attention${NC}"
    echo ""
    echo "Check the status above for issues"
fi

echo ""
