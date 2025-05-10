#!/bin/bash

# 软链接当前目录
if [ ! -L "armbian/userpatches" ] || [ "$(readlink armbian/userpatches)" != "../userpatches" ]; then
  rm -rf armbian/userpatches
  ln -s ../userpatches armbian/userpatches
fi

if [ ! -L "armbian/output" ] || [ "$(readlink armbian/output)" != "../output" ]; then
  rm -rf armbian/output
  ln -s ../output armbian/output
fi