#!/usr/bin/env bash
################################################################################
# Script Name: start-pcap-rotate.sh
# Description: Start rotating packet capture using tcpdump
# Platform: macOS/Linux
# Author: Matt J Bordenet
# Last Updated: 2025-11-21
################################################################################

set -euo pipefail

# Display help information
show_help() {
    cat << EOF
NAME
    $(basename "$0") - Start rotating packet capture using tcpdump

SYNOPSIS
    $(basename "$0") [INTERFACE] [CAPTURE_DIR] [DURATION] [KEEP_FILES] [FILTER]
    $(basename "$0") [OPTIONS]

DESCRIPTION
    Starts a rotating packet capture using tcpdump. Checks for available disk
    space, ensures no other instance is running, and logs output.

    Captures rotate automatically based on duration, keeping only the most
    recent files. Useful for continuous network monitoring.

ARGUMENTS
    INTERFACE
        Network interface to capture on (default: eth0)

    CAPTURE_DIR
        Directory to store capture files (default: ./captures)

    DURATION
        Seconds per capture file (default: 600 = 10 minutes)

    KEEP_FILES
        Number of capture files to keep (default: 48 = 8 hours at 10min each)

    FILTER
        tcpdump filter expression
        (default: "(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0 or icmp or arp)")

OPTIONS
    -h, --help
        Display this help message and exit

EXAMPLES
    # Start with defaults (eth0, ./captures, 10min rotation, keep 48 files)
    $(basename "$0")

    # Capture on en0 interface
    $(basename "$0") en0

    # Custom directory and duration
    $(basename "$0") en0 /var/captures 300 96

    # Custom filter
    $(basename "$0") en0 ./captures 600 48 "port 80 or port 443"

EXIT STATUS
    0   Success
    1   Error (insufficient disk space, already running, etc.)

FILES
    \$CAPTURE_DIR/tcpdump-rotate.pid
        PID file for running capture process

    \$CAPTURE_DIR/tcpdump-rotate.log
        Log file for capture output

    \$CAPTURE_DIR/capture-YYYY-MM-DD_HH-MM-SS.pcap
        Captured packet files

NOTES
    - Requires root/sudo privileges
    - Minimum 5GB free disk space required
    - Only one instance can run per capture directory
    - Files automatically rotate based on duration
    - Oldest files deleted when KEEP_FILES limit reached

SEE ALSO
    stop-pcap-rotate.sh(1), capture.sh(1), tcpdump(8)

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
            break
            ;;
    esac
done

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
