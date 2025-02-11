#!/bin/bash
#cd /Users/mattbordenet/GitHub
#cd /Users/$(whoami)/GitHub
cd ~/GitHub
for filename in /Users/$(whoami)/GitHub/*/; do
#  echo "dir: $filename"
  pushd $filename
  echo $(pwd)
#  git maintenance start
#  git reset --hard
#  git clean -d -x -f
#  git fetch
#git fetch origin
#git reset --hard origin/master
#git clean -fd
git pull
  popd
done
