#!/usr/bin/env bash
fetch-github-projects.sh --all; pushd Personal/superpowers-plus && bash install.sh --upgrade && { popd || exit; } && pushd CallBox/tools/superpowers-cari && bash install.sh --upgrade && { popd || exit; }
