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

# Cross-platform sha256: shasum -a 256 on macOS, sha256sum on Linux/WSL
if command -v shasum >/dev/null 2>&1; then
    SHA256_CMD=(shasum -a 256)
else
    SHA256_CMD=(sha256sum)
fi

# 1. Require Go toolchain
command -v go >/dev/null 2>&1 || {
    case "$(uname -s)" in
        Darwin) echo "gitsync requires Go. Install: brew install go" >&2 ;;
        *)      echo "gitsync requires Go. See https://go.dev/dl/" >&2 ;;
    esac
    exit 1
}

# 2. Concurrent invocation guard (flock requires util-linux on macOS: brew install util-linux)
if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || { echo "Another gitsync instance is running" >&2; exit 1; }
fi

# 3. Self-update: pull the scripts repo before hash check so a freshly-pushed
#    Go change is compiled on this run, not the next one.
#    fetch is non-fatal; ff-merge warns but does not abort.
#    If HEAD moves, export GITSYNC_SELF_UPDATED so the Go binary can report it
#    accurately instead of showing a misleading "up to date" for this repo.
_head_before=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || true)
git -C "$SCRIPT_DIR" fetch --quiet 2>/dev/null || true
_upstream=$(git -C "$SCRIPT_DIR" rev-parse '@{u}' 2>/dev/null || true)
if [[ -n "$_upstream" ]]; then
    _local=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || true)
    if [[ -n "$_local" && "$_local" != "$_upstream" ]]; then
        git -C "$SCRIPT_DIR" merge --ff-only "$_upstream" --quiet 2>/dev/null \
            || echo "  Warning: scripts repo has local divergence; using current version" >&2
    fi
fi
# _head_after captured after merge attempt; if merge failed, HEAD unchanged, so no false positive.
_head_after=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || true)
if [[ -n "$_head_before" && -n "$_head_after" && "$_head_before" != "$_head_after" ]]; then
    export GITSYNC_SELF_UPDATED="$SCRIPT_DIR"
    export GITSYNC_SELF_UPDATED_BRANCH
    GITSYNC_SELF_UPDATED_BRANCH=$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
fi
unset _upstream _local _head_before _head_after

# 4. Content-hash cache check — computed AFTER self-update so the hash reflects the pulled source
#    Hash = SHA-256 of sorted(find cmd/ internal/ -name "*.go") + go.mod [+ go.sum if present]
#    Cross-platform: shasum -a 256 (macOS) or sha256sum (Linux/WSL), selected above as SHA256_CMD
current_hash=$(
    {
        find "$SCRIPT_DIR/cmd" "$SCRIPT_DIR/internal" -name "*.go" | sort | xargs "${SHA256_CMD[@]}"
        "${SHA256_CMD[@]}" "$SCRIPT_DIR/go.mod"
        if [[ -f "$SCRIPT_DIR/go.sum" ]]; then
            "${SHA256_CMD[@]}" "$SCRIPT_DIR/go.sum"
        fi
    } | "${SHA256_CMD[@]}" | awk '{print $1}'
)
cached_hash=$(cat "$HASH_FILE" 2>/dev/null || echo "")

# 4b. Belt-and-suspenders mtime check. If a previous rebuild was suppressed
#     (e.g., hash file overwritten by an external sync between checks, OneDrive
#     replication mid-build, or a flock-aborted invocation), the hash compare
#     can return "match" even though source files are newer than the binary.
#     Compare the newest source mtime against the binary mtime as a fallback.
#     macOS uses `stat -f %m`, Linux/WSL uses `stat -c %Y`.
#     On systems where `stat` does not recognise `-c` as a format flag it may
#     output its default verbose report (e.g. "  File: /path\n  Size: ...") to
#     stdout and exit 0, so the `|| echo 0` fallback never fires. In `(( ))` bash
#     treats the leading word "File" as a variable name; with `set -u` that
#     crashes with "File: unbound variable". _mtime_of() guards with a numeric
#     regex so any non-numeric stat output falls back to 0 rather than crashing.
#     Degradation is safe, not an independent guarantee: an mtime of 0 sorts below
#     any real binary mtime, so a broken stat drops this secondary check back to
#     the hash-gate-only baseline — it never detects LESS staleness than the hash
#     gate alone, and never crashes. In the rare stale-HASH_FILE cases 4b targets
#     (see above), a simultaneously-broken stat leaves both gates quiet until the
#     next clean run — no worse than having no mtime gate at all.
if [[ "$(uname -s)" == "Darwin" ]]; then
    STAT_MTIME=(stat -f %m)
else
    STAT_MTIME=(stat -c %Y)
fi

# Resolve a file's mtime into the global `_mtime`. Called directly (not in a
# command-substitution subshell) so the one-shot `_stat_warned` flag persists
# across calls and the degraded-stat warning fires once per run, not per file.
_stat_warned=0
_mtime_of() {
    _mtime=$("${STAT_MTIME[@]}" "$1" 2>/dev/null || echo 0)
    if [[ ! "$_mtime" =~ ^[0-9]+$ ]]; then
        if (( ! _stat_warned )); then
            echo "Warning: stat returned non-numeric output (e.g. for '$1'); mtime gate disabled — a stale binary may not be auto-rebuilt if the hash cache still matches (stale hash file); force a rebuild by removing .gitsync.hash or touching a source file" >&2
            _stat_warned=1
        fi
        _mtime=0
    fi
}

newest_source_mtime=0
while IFS= read -r _f; do
    _mtime_of "$_f"
    if (( _mtime > newest_source_mtime )); then newest_source_mtime=$_mtime; fi
done < <(
    find "$SCRIPT_DIR/cmd" "$SCRIPT_DIR/internal" -name "*.go" -type f 2>/dev/null || true
    printf '%s\n' "$SCRIPT_DIR/go.mod"
    [[ -f "$SCRIPT_DIR/go.sum" ]] && printf '%s\n' "$SCRIPT_DIR/go.sum" || true
)
binary_mtime=0
if [[ -x "$BINARY" ]]; then
    _mtime_of "$BINARY"
    binary_mtime=$_mtime
fi
# `_stat_warned` is intentionally left set; any future second mtime pass must
# reset it to re-arm the once-per-run warning.
unset _f _mtime

# 5. Rebuild if hash changed OR binary missing OR source newer than binary
mtime_stale=0
if (( newest_source_mtime > binary_mtime )); then mtime_stale=1; fi

if [[ "$current_hash" != "$cached_hash" ]] || [[ ! -x "$BINARY" ]] || (( mtime_stale )); then
    if (( mtime_stale )) && [[ "$current_hash" == "$cached_hash" ]]; then
        echo "Building gitsync... (source newer than binary; hash check was stale)" >&2
    else
        echo "Building gitsync..." >&2
    fi
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
