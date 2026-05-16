#!/usr/bin/env bash
set -euo pipefail
fetch-github-projects.sh --all; pushd Personal/superpowers-plus && bash install.sh --upgrade && { popd || exit; }
