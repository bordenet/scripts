#!/usr/bin/env bash
################################################################################
# Script Name: stop-pcap-rotate.sh
# Description: Stop rotating packet capture process
# Platform: macOS/Linux
# Author: Matt J Bordenet
# Last Updated: 2025-11-21
################################################################################

set -euo pipefail

# Display help information
show_help() {
    cat << EOF
NAME
    $(basename "$0") - Stop rotating packet capture process

SYNOPSIS
    $(basename "$0") [CAPTURE_DIR]
    $(basename "$0") [OPTIONS]

DESCRIPTION
    Stops the packet capture rotation process started by start-pcap-rotate.sh.
    Reads the PID file and terminates the tcpdump process gracefully.

ARGUMENTS
    CAPTURE_DIR
        Directory where captures are stored (default: ./captures)
        Used to locate the PID file

OPTIONS
    -h, --help
        Display this help message and exit

EXAMPLES
    # Stop capture in default directory
    $(basename "$0")

    # Stop capture in specific directory
    $(basename "$0") /var/captures

EXIT STATUS
    0   Success - process stopped
    1   Error (PID file not found, process not running, etc.)

FILES
    \$CAPTURE_DIR/tcpdump-rotate.pid
        PID file for running capture process

NOTES
    - Requires permissions to kill the tcpdump process
    - Removes PID file after stopping process
    - Safe to run even if process already stopped

SEE ALSO
    start-pcap-rotate.sh(1), capture.sh(1), tcpdump(8)

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

echo "Stopping packet capture rotation..."

# Configuration
CAP_DIR="${1:-$(pwd)/captures}"
PIDFILE="${CAP_DIR}/tcpdump-rotate.pid"

# Stop the capture process
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping tcpdump process (PID $PID)..."
        sudo kill "$PID"
        rm "$PIDFILE"
        echo "✓ Packet capture rotation stopped"
    else
        echo "Warning: Process $PID not running, removing stale PID file"
        rm "$PIDFILE"
    fi
else
    echo "Error: PID file not found at $PIDFILE" >&2
    echo "Is the capture process running?" >&2
    exit 1
fi

# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo "Execution time: ${execution_time} seconds"
