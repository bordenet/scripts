#!/usr/bin/env bash
################################################################################
# Script Name: compress-pcap-zstd.sh
# Description: Compress .pcap files using zstd
# Platform: macOS/Linux
# Author: Matt J Bordenet
# Last Updated: 2025-11-21
################################################################################

set -euo pipefail

# Display help information
show_help() {
    cat << EOF
NAME
    $(basename "$0") - Compress .pcap files using zstd

SYNOPSIS
    $(basename "$0") [SOURCE_DIR] [LOG_FILE]
    $(basename "$0") [OPTIONS]

DESCRIPTION
    Compresses all .pcap files in a specified directory using zstd -19 (maximum
    compression). Logs compression progress and execution time.

    zstd typically provides better compression ratios and faster decompression
    than gzip, making it ideal for archiving packet captures.

ARGUMENTS
    SOURCE_DIR
        Directory containing .pcap files to compress
        (default: \$HOME/network-diagnostics/captures)

    LOG_FILE
        Path to log file for compression progress
        (default: /volume1/Network-Diagnostics/compression.log)

OPTIONS
    -h, --help
        Display this help message and exit

EXAMPLES
    # Compress with defaults
    $(basename "$0")

    # Compress specific directory
    $(basename "$0") /var/captures

    # Custom directory and log file
    $(basename "$0") /var/captures /var/log/compression.log

EXIT STATUS
    0   Success
    1   Error (directory not found, zstd not installed, etc.)

NOTES
    - Uses zstd -19 for maximum compression
    - Original .pcap files are removed (--rm flag)
    - Compression is logged to LOG_FILE
    - Shows before/after directory sizes
    - Progress counter shows files processed
    - Requires zstd to be installed at /opt/bin/zstd

SEE ALSO
    compress-pcap-gzip.sh(1), zstd(1), tcpdump(8)

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

# --- Configuration ---
SOURCE_DIR="${1:-$HOME/network-diagnostics/captures}"
LOG_FILE="${2:-/volume1/Network-Diagnostics/compression.log}"

# --- Start ---
start_time=$(date +%s)
echo "=== Compression started at $(date) ===" >> "$LOG_FILE"

# Function to get human-readable size
get_size() {
  du -sh "$1" 2>/dev/null | awk '{print $1}'
}

# Record initial size
initial_size=$(get_size "$SOURCE_DIR")
echo "Initial folder size: $initial_size" | tee -a "$LOG_FILE"

# Count total files
total_files=$(find "$SOURCE_DIR" -type f -name '*.pcap' | wc -l)
echo "Total .pcap files to process: $total_files" | tee -a "$LOG_FILE"

# Compress files
count=0
find "$SOURCE_DIR" -type f -name '*.pcap' | while read -r file; do
  count=$((count + 1))
  echo "[$count/$total_files] Compressing: $file" | tee -a "$LOG_FILE"
  /opt/bin/zstd -19 --rm "$file"
done

# Record final size
final_size=$(get_size "$SOURCE_DIR")
end_time=$(date +%s)
duration=$((end_time - start_time))

echo "Final folder size: $final_size" | tee -a "$LOG_FILE"
echo "Execution time: ${duration}s" | tee -a "$LOG_FILE"
echo "=== Compression completed at $(date) ===" >> "$LOG_FILE"

echo "Compression process completed. See ${LOG_FILE} for details."
echo "Total execution time: ${duration} seconds"