#!/bin/bash
#
# Script: bu.sh
# Description: This script performs a comprehensive system update and cleanup.
#              It updates various package managers and tools including Homebrew,
#              apm, bower, npm, mas, and pip. It also cleans up Homebrew installations,
#              resets local Git repositories, and performs a macOS software update.
# Usage: ./bu.sh
# Dependencies: Homebrew, apm, bower, npm, mas, pip, git, reset_all_repos.sh
#
sudo ls
clear
brew update
brew upgrade
brew cleanup -s
brew upgrade --cask
brew untap homebrew/cask

brew doctor
brew missing
#apm upgrade -c false

#bower update
npm update -g --force
npm install -g npm --force

brew install mas
mas outdated
echo "install with: mas upgrade"
mas upgrade

#pushd ~/GitHub > /dev/null
#./reset_all_repos.sh -f
#popd > /dev/null

sudo -H pip install --upgrade pip
sudo -H pip3 install --upgrade pip

#~/GitHub/fetch-github-projects.sh
#/Users/matt/GitHub/fetch-github-projects.sh
sudo softwareupdate --all --install --force -R
