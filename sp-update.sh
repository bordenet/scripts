#!/bin/bash
fetch-github-projects.sh --all; pushd Personal/superpowers-plus && bash install.sh --upgrade && popd && pushd CallBox/tools/superpowers-cari && bash install.sh --upgrade && popd
