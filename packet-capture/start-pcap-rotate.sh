#!/bin/bash
# start-pcap-rotate.sh - start rotating tcpdump capture safely
# Usage: ./start-pcap-rotate.sh [interface] [capture-dir]
# Defaults: interface=eth0  capture-dir=./captures

INTERFACE="${1:-eth0}"
CAP_DIR="${2:-$(pwd)/captures}"
DURATION="${3:-600}"     # seconds per file (default 600 = 10min)
KEEP_FILES="${4:-48}"    # number of files to keep
FILTER="${5:-(host 1.1.1.1 or host 8.8.8.8) and (tcp[tcpflags] & (tcp-rst|tcp-fin) != 0 or icmp or arp)}"
PIDFILE="${CAP_DIR}/tcpdump-rotate.pid"
MIN_FREE_GB=5            # minimum free GB required to start

mkdir -p "$CAP_DIR"
# check free space on capture dir filesystem
avail_kb=$(df --output=avail -k "$CAP_DIR" | tail -n1)
avail_gb=$((avail_kb / 1024 / 1024))

if [ "$avail_gb" -lt "$MIN_FREE_GB" ]; then
  echo "ERROR: Only ${avail_gb}GB free on $(df -h "$CAP_DIR" | tail -n1 | awk '{print $1}') — need >= ${MIN_FREE_GB}GB. Aborting."
  exit 1
fi

if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
  echo "tcpdump rotating capture already running (PID $(cat "$PIDFILE")). Exiting."
  exit 0
fi

# start tcpdump in background; write PID
sudo nohup tcpdump -i "$INTERFACE" -nn -tttt -G "$DURATION" -W "$KEEP_FILES" \
  -w "$CAP_DIR/capture-%Y-%m-%d_%H-%M-%S.pcap" "$FILTER" \
  1>>"$CAP_DIR/tcpdump-rotate.log" 2>&1 &

sleep 0.5
echo $! > "$PIDFILE"
echo "Started tcpdump rotate (PID $(cat "$PIDFILE")) -> $CAP_DIR (filter: $FILTER)"
