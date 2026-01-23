#!/bin/bash
# Git adapter implementing the VCS interface

vcs-status() {
  git status --porcelain
}

vcs-branch() {
  git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD"
}

vcs-dirty() {
  [ -z "$(git status --porcelain)" ]
}

vcs-stage() {
  git add "$1"
}

vcs-unstage() {
  git restore --staged "$1"
}

vcs-commit() {
  git commit -m "$1"
}

vcs-atomic-commit() {
  local type="$1" phase="$2" task="$3" desc="$4" project="${5:-}"

  # Use provided project or fall back to get_active_project (FR-008)
  if [ -z "$project" ]; then
    project=$("$GSD_DIR/scripts/project.sh" get_active_project 2>/dev/null)
  fi

  if [ -n "$project" ]; then
    git commit -m "[$project] ${type}(${phase}-${task}): ${desc}"
  else
    git commit -m "${type}(${phase}-${task}): ${desc}"
  fi
}

vcs-log() {
  git log --oneline -"${1:-10}"
}

vcs-diff() {
  if [ -n "$1" ]; then
    git diff "$1"
  else
    git diff
  fi
}

vcs-diff-staged() {
  git diff --staged
}

vcs-bisect-start() {
  git bisect start
}

vcs-bisect-good() {
  git bisect good "$@"
}

vcs-bisect-bad() {
  git bisect bad "$@"
}

vcs-bisect-reset() {
  git bisect reset
}

vcs-root() {
  git rev-parse --show-toplevel
}

vcs-current-rev() {
  git rev-parse --short HEAD
}

vcs-has-commits() {
  git rev-parse HEAD >/dev/null 2>&1
}
