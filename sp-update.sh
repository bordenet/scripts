#!/bin/bash
fetch-github-projects.sh --all; pushd Personal/superpowers-plus && bash install.sh --upgrade && popd && pushd [COMPANY]/tools/superpowers-[removed] && bash install.sh --upgrade && popd
