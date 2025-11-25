#!/usr/bin/env bash
################################################################################
# Script Name: capture.sh
# Description: Start packet capture using tcpdump with rotation
# Platform: macOS/Linux
# Author: Matt J Bordenet
# Last Updated: 2025-11-21
################################################################################

set -euo pipefail

# Display help information
show_help() {
    cat << EOF
NAME
    $(basename "$0") - Start packet capture using tcpdump

SYNOPSIS
    $(basename "$0") [OPTIONS]

DESCRIPTION
    Starts packet capture using tcpdump. Runs one capture in the background
    with rotation (600s intervals, 48 files max) and another in the foreground
    for real-time monitoring.

    Captures DNS traffic to 1.1.1.1 and 8.8.8.8, focusing on TCP RST/FIN flags,
    ICMP, and ARP packets.

OPTIONS
    -h, --help
        Display this help message and exit

EXAMPLES
    $(basename "$0")
        Start packet capture with default settings

EXIT STATUS
    0   Success
    1   Error (missing permissions, interface not found, etc.)

NOTES
    - Requires root/sudo privileges
    - Background captures saved to /volume1/captures/
    - Foreground capture runs until Ctrl+C
    - Uses interface en0 by default

SEE ALSO
    start-pcap-rotate.sh(1), stop-pcap-rotate.sh(1), tcpdump(8)

EOF
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            show_help
            ;;
        *)
            echo "Error: Unknown option: $1" >&2
            echo "Use --help for usage information" >&2
            exit 1
            ;;
    esac
done

# Start timer
start_time=$(date +%s)

echo "Starting packet capture..."

# --- Background Capture with Rotation ---
echo "Starting background packet capture with rotation..."
sudo tcpdump -i en0 -nn -tttt -G 600 -W 48 \
  -w /volume1/captures/capture-%Y-%m-%d_%H-%M-%S.pcap \
  '(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0 or icmp or arp)' &

# --- Foreground Capture ---
echo "Starting foreground packet capture..."
# Note: This command will run indefinitely until manually stopped (e.g., with Ctrl+C).
# The script will not proceed beyond this point until the foreground tcpdump process is terminated.
sudo tcpdump -i en0 -n '(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0)'

echo "Packet capture stopped."

# --- Completion ---
# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo "Script execution time: ${execution_time} seconds"