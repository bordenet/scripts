#!/usr/bin/env bash
fetch-github-projects.sh --all; pushd Personal/superpowers-plus && bash install.sh --upgrade && { popd || exit; } && pushd [COMPANY]/tools/superpowers-[removed] && bash install.sh --upgrade && { popd || exit; }
