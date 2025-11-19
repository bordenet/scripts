#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: start-pcap-rotate.sh
#
# Description: This script starts a rotating packet capture using tcpdump.
#              It checks for available disk space, ensures no other instance is
#              running, and logs the output.
#
# Usage: ./start-pcap-rotate.sh [interface] [capture-dir] [duration] [keep-files] [filter]
#
#   - interface: Network interface to capture on (default: eth0)
#   - capture-dir: Directory to store capture files (default: ./captures)
#   - duration: Seconds per capture file (default: 600)
#   - keep-files: Number of capture files to keep (default: 48)
#   - filter: tcpdump filter expression (default: "(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0 or icmp or arp)")
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

echo "Starting packet capture rotation setup..."

# --- Configuration ---
INTERFACE="${1:-eth0}"
CAP_DIR="${2:-$(pwd)/captures}"
DURATION="${3:-600}"     # seconds per file (default 600 = 10min)
KEEP_FILES="${4:-48}"    # number of files to keep
FILTER="${5:-(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0 or icmp or arp)}"
PIDFILE="${CAP_DIR}/tcpdump-rotate.pid"
MIN_FREE_GB=5            # minimum free GB required to start

# --- Pre-flight Checks ---
echo "Creating capture directory if it doesn't exist: ${CAP_DIR}"
mkdir -p "$CAP_DIR"

echo "Checking for available disk space..."
avail_kb=$(df --output=avail -k "$CAP_DIR" | tail -n1)
avail_gb=$((avail_kb / 1024 / 1024))

if [ "$avail_gb" -lt "$MIN_FREE_GB" ]; then
  echo "ERROR: Only ${avail_gb}GB free on $(df -h "$CAP_DIR" | tail -n1 | awk '{print $1}') — need >= ${MIN_FREE_GB}GB. Aborting."
  exit 1
fi
echo "Available disk space is sufficient (${avail_gb}GB)."

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "tcpdump rotating capture already running (PID $(cat "$PIDFILE")). Exiting."
  exit 0
fi
echo "No existing capture process found."

# --- Start Capture ---
echo "Starting tcpdump in the background..."
sudo nohup tcpdump -i "$INTERFACE" -nn -tttt -G "$DURATION" -W "$KEEP_FILES" \
  -w "$CAP_DIR/capture-%Y-%m-%d_%H-%M-%S.pcap" "$FILTER" \
  1>>"$CAP_DIR/tcpdump-rotate.log" 2>&1 &

# Store the PID of the background process
TCPDUMP_PID=$!
sleep 0.5

echo "Writing PID ${TCPDUMP_PID} to ${PIDFILE}"
echo $TCPDUMP_PID > "$PIDFILE"

echo "Started tcpdump rotate (PID $(cat "$PIDFILE")) -> $CAP_DIR (filter: $FILTER)"

# --- Completion ---
# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo "Script execution time: ${execution_time} seconds"