#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: stop-pcap-rotate.sh
#
# Description: This script stops the packet capture rotation process.
#              It is expected to find a process running with a specific name
#              (e.g., 'tcpdump' or 'tshark') and terminate it.
#
# Usage: ./stop-pcap-rotate.sh
#
# Author: Matt J Bordenet
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -e

# Start timer
start_time=$(date +%s)

echo "Stopping packet capture rotation..."

# --- USER ACTION REQUIRED ---
# The logic to stop the packet capture process goes here.
# For example, you might use pkill or killall to stop the process.
#
# Example:
# pkill -f 'tcpdump'
#
# Or, if you have a PID file:
# if [ -f /var/run/pcap-rotate.pid ]; then
#     kill $(cat /var/run/pcap-rotate.pid)
#     rm /var/run/pcap-rotate.pid
# else
#     echo "PID file not found. Is the capture process running?"
#     exit 1
# fi

echo "Packet capture rotation stopped."

# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo "Execution time: ${execution_time} seconds"