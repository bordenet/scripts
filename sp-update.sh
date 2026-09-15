#!/usr/bin/env bash
set -euo pipefail

# Resolve the real location of this script, following symlinks, so it works
# regardless of the caller's cwd (fetch-github-projects.sh renamed to
# sync-git-repos.sh; this script previously relied on both being on PATH
# from a ~/git cwd, which doesn't hold on every machine).
_src="${BASH_SOURCE[0]}"
while [[ -L "$_src" ]]; do
    _dir="$(cd "$(dirname "$_src")" && pwd)"
    _src="$(readlink "$_src")"
    [[ "$_src" = /* ]] || _src="$_dir/$_src"
done
SCRIPT_DIR="$(cd "$(dirname "$_src")" && pwd)"
unset _src _dir

cd "$SCRIPT_DIR/../.."  # Personal/scripts -> workspace root (~/git)

./sync-git-repos.sh --all
pushd Personal/superpowers-plus >/dev/null
bash install.sh --upgrade
popd >/dev/null
