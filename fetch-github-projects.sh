#!/bin/bash
#
# Script: fetch-github-projects.sh
# Description: This script automates the process of updating all local Git repositories
#              located within the '~/GitHub' directory. It iterates through each
#              repository and performs a 'git pull' to fetch and merge changes
#              from their respective remote origins.
# Usage: ./fetch-github-projects.sh
# Dependencies: git
#
cd ~/GitHub
for filename in /Users/$(whoami)/GitHub/*/; do
  pushd $filename
  echo $(pwd)
  git pull
  popd
done
