#!/usr/bin/env bash
# PURPOSE: Sync all git repos in a directory — parallel Go binary, built on demand
# USAGE: fetch-github-projects.sh [--all] [--recursive] [--what-if] [--no-rebase] [DIRECTORY]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY="$SCRIPT_DIR/gitsync"
HASH_FILE="$SCRIPT_DIR/.gitsync.hash"
LOCK_FILE="$SCRIPT_DIR/.gitsync.lock"

# 1. Require Go toolchain
command -v go >/dev/null 2>&1 || {
    echo "gitsync requires Go. Install: brew install go" >&2; exit 1
}

# 2. Concurrent invocation guard (flock requires util-linux on macOS: brew install util-linux)
if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || { echo "Another gitsync instance is running" >&2; exit 1; }
fi

# 3. Content-hash cache check
#    Hash = SHA-256 of sorted(find cmd/ internal/ -name "*.go") + go.mod [+ go.sum if present]
#    Uses shasum -a 256 (macOS BSD — NOT sha256sum which is GNU/Linux only)
current_hash=$(
    {
        find "$SCRIPT_DIR/cmd" "$SCRIPT_DIR/internal" -name "*.go" | sort | xargs shasum -a 256
        shasum -a 256 "$SCRIPT_DIR/go.mod"
        if [[ -f "$SCRIPT_DIR/go.sum" ]]; then
            shasum -a 256 "$SCRIPT_DIR/go.sum"
        fi
    } | shasum -a 256 | awk '{print $1}'
)
cached_hash=$(cat "$HASH_FILE" 2>/dev/null || echo "")

# 4. Rebuild if hash changed or binary missing
if [[ "$current_hash" != "$cached_hash" ]] || [[ ! -x "$BINARY" ]]; then
    echo "Building gitsync..." >&2
    rm -f "$SCRIPT_DIR/gitsync_new"
    if go build -o "$SCRIPT_DIR/gitsync_new" "$SCRIPT_DIR/cmd/gitsync/"; then
        mv "$SCRIPT_DIR/gitsync_new" "$BINARY"
        echo "$current_hash" > "$HASH_FILE"
    else
        echo "Build failed" >&2
        rm -f "$SCRIPT_DIR/gitsync_new"
        exit 1
    fi
fi

# 5. Pre-warm SSH ControlMaster BEFORE exec (runs on every invocation, not just rebuilds)
#    This ensures all goroutines in the binary find an existing ControlMaster socket,
#    preventing a connection storm when 8+ goroutines fire simultaneously.
#    NOTE: ControlPersist=60s leaves the SSH master process alive for 60s after exit.
ssh -o ControlMaster=auto \
    -o "ControlPath=$HOME/.ssh/cm-%r@%h:%p" \
    -o ControlPersist=60s \
    git@github.com info 2>/dev/null || true

# 6. Exec binary (replaces this shell process; passes SCRIPT_DIR for self-exclusion)
export GITSYNC_SOURCE_DIR="$SCRIPT_DIR"
exec "$BINARY" "$@"
