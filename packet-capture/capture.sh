#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: capture.sh
#
# Description: This script starts a packet capture using tcpdump.
#              It starts one capture in the background with rotation and
#              another in the foreground.
#
# Usage: ./capture.sh
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

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