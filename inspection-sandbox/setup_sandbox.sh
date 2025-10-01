#!/bin/bash

# This script sets up a secure sandbox environment for inspecting potentially malicious files.

# --- Configuration ---
SANDBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
SHARED_DIR="${SANDBOX_DIR}/shared"
VM_NAME="inspection-sandbox"

# --- Functions ---

#
# Checks for required dependencies.
#
check_dependencies() {
    echo "Checking for dependencies..."
    local missing_deps=0

    # Check for Homebrew
    if ! command -v brew &>/dev/null; then
        echo "Error: Homebrew is not installed. Please install it from https://brew.sh/"
        missing_deps=$((missing_deps + 1))
    fi

    # Check for UTM
    if ! command -v utmctl &>/dev/null; then
        echo "Error: UTM is not installed. Please install it via 'brew install --cask utm'"
        missing_deps=$((missing_deps + 1))
    fi

    if [ "$missing_deps" -ne 0 ]; then
        echo "Please install the missing dependencies and run the script again."
        exit 1
    fi
    echo "All dependencies are installed."
}

#
# Creates the required directories.
#
create_directories() {
    echo "Creating directories..."
    mkdir -p "${SHARED_DIR}"
    echo "Directories created."
}

#
# Downloads the Alpine Linux ISO.
#
download_iso() {
    echo "Downloading Alpine Linux ISO..."
    if [ ! -f "${SANDBOX_DIR}/alpine.iso" ]; then
        curl -L -o "${SANDBOX_DIR}/alpine.iso" "https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-standard-3.19.1-x86_64.iso"
    else
        echo "Alpine Linux ISO already downloaded."
    fi
    echo "Alpine Linux ISO ready."
}

#
# Generates an SSH key pair.
#
generate_ssh_key() {
    echo "Generating SSH key pair..."
    if [ ! -f "${SANDBOX_DIR}/id_rsa" ]; then
        ssh-keygen -t rsa -b 4096 -f "${SANDBOX_DIR}/id_rsa" -N ""
        cp "${SANDBOX_DIR}/id_rsa.pub" "${SHARED_DIR}/id_rsa.pub"
    else
        echo "SSH key pair already exists."
    fi
    echo "SSH key pair ready."
}

#
# Destroys the sandbox environment.
#
burn() {
    echo "Destroying sandbox environment..."
    if utmctl status "${VM_NAME}" | grep -q "running"; then
        utmctl stop "${VM_NAME}"
    fi
    utmctl delete "${VM_NAME}"
    rm -rf "${SHARED_DIR}"
    rm -f "${SANDBOX_DIR}/id_rsa" "${SANDBOX_DIR}/id_rsa.pub"
    echo "Sandbox environment destroyed."
}

#
# Tests the sandbox environment.
#
test_sandbox() {
    echo "Testing sandbox environment..."

    # List all VMs
    utmctl list

    # Check if the VM is registered
    if ! utmctl status "${VM_NAME}" &>/dev/null; then
        echo "Error: VM is not registered. Please create it manually in the UTM app."
        exit 1
    fi

    # Create a test file
    local test_file="${SHARED_DIR}/test_file.txt"
    echo "This is a test file." > "${test_file}"

    # Start the VM
    utmctl start "${VM_NAME}"

    # Wait for the VM to boot and for the SSH port to be open
    echo "Waiting for VM to boot..."
    local i=0
    while ! nc -z localhost 2222 && [ $i -lt 30 ]; do
        sleep 1
        i=$((i+1))
    done

    # Run the analysis script
    ssh -v -i "${SANDBOX_DIR}/id_rsa" -o StrictHostKeyChecking=no -p 2222 root@localhost -- "/media/shared/analyze.sh scan /media/shared/test_file.txt"

    # Stop the VM
    utmctl stop "${VM_NAME}"

    echo "Sandbox environment test complete."
}

#
# Main function
#
main() {
    if [ $# -eq 0 ]; then
        echo "Starting sandbox setup..."
        check_dependencies
        create_directories
        download_iso
        generate_ssh_key
        echo "Sandbox setup complete."
        exit 0
    fi

    case "$1" in
        burn)
            burn
            ;;
        test)
            test_sandbox
            ;;
        start)
            utmctl start "${VM_NAME}"
            ;;
        *)
            echo "Invalid command: $1"
            exit 1
            ;;
    esac
}

# --- Main execution ---
main "$@"