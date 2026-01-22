#!/bin/bash
# Detect which VCS is in use in the current directory

if [ -d .git ] || git rev-parse --git-dir >/dev/null 2>&1; then
  echo "git"
elif [ -d .hg ]; then
  echo "hg"
else
  echo "none"
fi
