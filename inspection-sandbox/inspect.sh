#!/bin/bash
#
# Easy Wrapper Script for Inspecting Suspicious Files
# Usage: ./inspect.sh <filename>
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_NAME="inspection-sandbox"
SSH_KEY="${SCRIPT_DIR}/id_rsa"
SSH_PORT=2222
SHARED_DIR="${SCRIPT_DIR}/shared"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

#
# Main inspection workflow
#
main() {
    if [ $# -eq 0 ]; then
        cat <<EOF
Usage: $0 <filename>

Inspect a suspicious file in the isolated sandbox environment.

The file will be copied to the shared directory and analyzed inside
the VM using multiple security tools.

Examples:
  $0 suspicious-attachment.pdf
  $0 invoice.exe
  $0 document.docm

The file can be:
  - A relative path (will be copied from current directory)
  - An absolute path
  - Already in the shared/ directory (will be used as-is)
EOF
        exit 1
    fi

    local file="$1"
    local filename
    filename="$(basename "${file}")"
    local shared_file="${SHARED_DIR}/${filename}"

    echo ""
    echo "========================================"
    echo "🔍 Malware Inspection Sandbox"
    echo "========================================"
    echo ""

    # Check if VM exists
    if ! utmctl status "${VM_NAME}" &>/dev/null; then
        error "VM '${VM_NAME}' not found. Run: ./create-vm.sh"
    fi

    # Copy file to shared directory if needed
    if [ ! -f "${shared_file}" ]; then
        if [ ! -f "${file}" ]; then
            error "File not found: ${file}"
        fi
        info "Copying file to shared directory..."
        cp "${file}" "${SHARED_DIR}/"
        success "File copied: ${filename}"
    else
        info "File already in shared directory: ${filename}"
    fi

    echo ""
    warning "⚠️  ANALYZING POTENTIALLY DANGEROUS FILE ⚠️"
    warning "File: ${filename}"
    echo ""
    read -p "Press ENTER to continue or Ctrl+C to cancel..."
    echo ""

    # Start VM if not running
    if ! utmctl status "${VM_NAME}" | grep -q "started"; then
        info "Starting VM..."
        utmctl start "${VM_NAME}"
        info "Waiting for VM to boot (30 seconds)..."
        sleep 30
    else
        success "VM is already running"
    fi

    # Wait for SSH to be available
    info "Waiting for SSH connection..."
    local max_attempts=30
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if nc -z localhost ${SSH_PORT} 2>/dev/null; then
            if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p ${SSH_PORT} root@localhost "exit" 2>/dev/null; then
                success "SSH connection established"
                break
            fi
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done

    if [ $attempt -eq $max_attempts ]; then
        error "Could not connect to VM via SSH"
    fi

    echo ""
    echo ""

    # Run analysis
    info "Running analysis (this may take a few minutes)..."
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no -p ${SSH_PORT} root@localhost \
        "/media/shared/analyze.sh scan /media/shared/${filename}"; then
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        success "Analysis completed successfully"
    else
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        warning "Analysis completed with warnings or errors"
    fi

    echo ""
    info "The file remains in: ${SHARED_DIR}/${filename}"
    info "To analyze another file: $0 <filename>"
    info "To stop the VM: utmctl stop ${VM_NAME}"
    echo ""
}

main "$@"
