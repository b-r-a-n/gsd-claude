#!/bin/bash
# Mercurial adapter implementing the VCS interface

vcs-status() {
  hg status
}

vcs-branch() {
  # Try bookmark first, fall back to branch
  local bookmark=$(hg bookmark -l 2>/dev/null | grep '\*' | awk '{print $2}')
  if [ -n "$bookmark" ]; then
    echo "$bookmark"
  else
    hg branch 2>/dev/null || echo "default"
  fi
}

vcs-dirty() {
  [ -z "$(hg status)" ]
}

vcs-stage() {
  # Mercurial doesn't have a staging area, but we track files for commit
  hg add "$1" 2>/dev/null || true
}

vcs-unstage() {
  # Mercurial doesn't have staging, this is a no-op for tracked files
  # For newly added files, we can forget them
  hg forget "$1" 2>/dev/null || true
}

vcs-commit() {
  hg commit -m "$1"
}

vcs-atomic-commit() {
  local type="$1" phase="$2" task="$3" desc="$4"

  # Get active project
  local project
  project=$("$GSD_DIR/scripts/project.sh" get_active_project 2>/dev/null)

  if [ -n "$project" ]; then
    hg commit -m "[$project] ${type}(${phase}-${task}): ${desc}"
  else
    hg commit -m "${type}(${phase}-${task}): ${desc}"
  fi
}

vcs-log() {
  hg log --template '{rev}:{node|short} {desc|firstline}\n' -l "${1:-10}"
}

vcs-diff() {
  if [ -n "$1" ]; then
    hg diff "$1"
  else
    hg diff
  fi
}

vcs-diff-staged() {
  # Mercurial doesn't have staging, show all changes
  hg diff
}

vcs-bisect-start() {
  hg bisect --reset
}

vcs-bisect-good() {
  hg bisect --good "$@"
}

vcs-bisect-bad() {
  hg bisect --bad "$@"
}

vcs-bisect-reset() {
  hg bisect --reset
}

vcs-root() {
  hg root
}

vcs-current-rev() {
  hg id -i | tr -d '+'
}

vcs-has-commits() {
  hg log -l 1 >/dev/null 2>&1
}
