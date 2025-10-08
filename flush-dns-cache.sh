#!/bin/bash
# -----------------------------------------------------------------------------
#
# Script Name: flush-dns-cache.sh
#
# Description: This script flushes the DNS cache on macOS.
#
# Usage: ./flush-dns-cache.sh
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

echo "Flushing DNS cache..."

# Flush the DNS cache
sudo dscacheutil -flushcache

# Restart the mDNSResponder service
sudo killall -HUP mDNSResponder

echo "DNS cache flushed successfully."

# End timer
end_time=$(date +%s)

# Calculate and display execution time
execution_time=$((end_time - start_time))
echo "Execution time: ${execution_time} seconds"