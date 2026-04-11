#!/usr/bin/env bash
# PURPOSE: Sync all git repos in a directory — parallel Go binary, built on demand
# USAGE: sync-git-repos.sh [DIR...] [--interactive] [--what-if] [--no-rebase] [--verbose]
set -euo pipefail

# Resolve the real location of this script, following symlinks.
# BASH_SOURCE[0] is the symlink path when invoked via symlink, so we must
# dereference it to find the actual script (and its co-located Go source).
# macOS lacks readlink -f / realpath, so we use a portable loop.
_src="${BASH_SOURCE[0]}"
while [[ -L "$_src" ]]; do
    _dir="$(cd "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    [[ "$_src" = /* ]] || _src="$_dir/$_src"  # handle relative symlinks
done
SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
unset _src _dir
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

# 3. Self-update: pull the scripts repo before hash check so a freshly-pushed
#    Go change is compiled on this run, not the next one.
#    fetch is non-fatal; ff-merge warns but does not abort.
git -C "$SCRIPT_DIR" fetch --quiet 2>/dev/null || true
_upstream=$(git -C "$SCRIPT_DIR" rev-parse '@{u}' 2>/dev/null || true)
if [[ -n "$_upstream" ]]; then
    _local=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || true)
    if [[ -n "$_local" && "$_local" != "$_upstream" ]]; then
        echo "Updating scripts repo..." >&2
        git -C "$SCRIPT_DIR" merge --ff-only "$_upstream" --quiet 2>/dev/null \
            || echo "  Warning: scripts repo has local divergence; using current version" >&2
    fi
fi
unset _upstream _local

# 4. Content-hash cache check — computed AFTER self-update so the hash reflects the pulled source
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

# 5. Rebuild if hash changed or binary missing
if [[ "$current_hash" != "$cached_hash" ]] || [[ ! -x "$BINARY" ]]; then
    echo "Building gitsync..." >&2
    rm -f "$SCRIPT_DIR/gitsync_new"
    if (cd "$SCRIPT_DIR" && go build -o "$SCRIPT_DIR/gitsync_new" ./cmd/gitsync/); then
        mv "$SCRIPT_DIR/gitsync_new" "$BINARY"
        echo "$current_hash" > "$HASH_FILE"
    else
        echo "Build failed" >&2
        rm -f "$SCRIPT_DIR/gitsync_new"
        exit 1
    fi
fi

# 6. Pre-warm SSH ControlMaster BEFORE exec (runs on every invocation, not just rebuilds)
#    This ensures all goroutines in the binary find an existing ControlMaster socket,
#    preventing a connection storm when 8+ goroutines fire simultaneously.
#    NOTE: ControlPersist=60s leaves the SSH master process alive for 60s after exit.
ssh -o ControlMaster=auto \
    -o "ControlPath=$HOME/.ssh/cm-%r@%h:%p" \
    -o ControlPersist=60s \
    git@github.com info 2>/dev/null || true

# 7. Exec binary (replaces this shell process)
exec "$BINARY" "$@"
