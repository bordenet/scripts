#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: compress-pcap-zstd.sh
#
# Description: This script compresses .pcap files in a specified directory
#              using zstd. It logs the compression progress and execution time.
#
# Usage: ./compress-pcap-zstd.sh
#
# Author: Gemini
#
# Last Updated: 2025-10-08
#
# -----------------------------------------------------------------------------

# Exit immediately if a command exits with a non-zero status.
set -euo pipefail

# --- Configuration ---
SOURCE_DIR="$HOME/network-diagnostics/captures"
LOG_FILE="/volume1/Network-Diagnostics/compression.log"

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