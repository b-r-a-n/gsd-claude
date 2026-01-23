#!/bin/bash
# Project management functions

# Get script directory for sourcing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source locking utilities
source "$SCRIPT_DIR/lock.sh"

PLANNING_DIR="$HOME/.claude/planning"
PROJECTS_DIR="$PLANNING_DIR/projects"

# Ensure directories exist
ensure_planning_dirs() {
  mkdir -p "$PROJECTS_DIR"
}

# Compute project ID from repo root and project name
compute_project_id() {
  local project_name="$1"
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "no-repo")
  echo -n "${repo_root}:${project_name}" | shasum -a 1 | cut -c1-12
}

# Get active project (priority: env var > .current-project > last-active > commit history)
get_active_project() {
  # 1. Environment variable
  if [ -n "$GSD_PROJECT" ]; then
    echo "$GSD_PROJECT"
    return 0
  fi

  # 2. .current-project file
  if [ -f "$PLANNING_DIR/.current-project" ]; then
    cat "$PLANNING_DIR/.current-project" | tr -d ' \n'
    return 0
  fi

  # 3. Most recent last-active
  local latest
  latest=$(ls -t "$PROJECTS_DIR"/*/last-active 2>/dev/null | head -1)
  if [ -n "$latest" ]; then
    basename "$(dirname "$latest")"
    return 0
  fi

  # 4. Most recent commit with [project] tag
  local from_commit
  from_commit=$(git log --oneline -50 2>/dev/null | grep -o '\[[^]]*\]' | head -1 | tr -d '[]')
  if [ -n "$from_commit" ]; then
    echo "$from_commit"
    return 0
  fi

  return 1
}

# Set active project
set_active_project() {
  local project="$1"
  ensure_planning_dirs

  if [ ! -d "$PROJECTS_DIR/$project" ]; then
    echo "Error: Project '$project' not registered" >&2
    echo "Run: gsd-new-project $project" >&2
    return 1
  fi

  gsd_atomic_write "$PLANNING_DIR/.current-project" "$project"
  gsd_safe_touch "$PROJECTS_DIR/$project/last-active"
  echo "Active project: $project"
}

# Register a new project (with collision detection)
register_project() {
  local project_name="$1"
  local description="${2:-}"
  local lock_file="$PROJECTS_DIR/.registration-lock"
  local project_dir="$PROJECTS_DIR/$project_name"

  ensure_planning_dirs

  # Acquire registration lock to prevent concurrent registrations
  if ! gsd_lock_acquire "$lock_file" 30; then
    echo "Error: Could not acquire registration lock" >&2
    return 1
  fi

  # Check if project already exists
  if [ -d "$project_dir" ]; then
    gsd_lock_release "$lock_file"
    echo "Error: Project '$project_name' already exists" >&2
    echo "Use: /gsd-set-project $project_name" >&2
    return 1
  fi

  # Compute project metadata
  local project_id
  project_id=$(compute_project_id "$project_name")
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
  local created_at
  created_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Create project directory (will fail if somehow created between check and now)
  if ! mkdir "$project_dir" 2>/dev/null; then
    gsd_lock_release "$lock_file"
    echo "Error: Failed to create project directory" >&2
    return 1
  fi

  # Build project.yml content
  local yaml_content="name: $project_name
id: $project_id
repository: $repo_root
status: active
created: $created_at
last_accessed: $created_at
description: |
  $description"

  # Create project.yml atomically
  if ! gsd_atomic_write "$project_dir/project.yml" "$yaml_content"; then
    # Cleanup on failure
    rm -rf "$project_dir" 2>/dev/null
    gsd_lock_release "$lock_file"
    echo "Error: Failed to create project.yml" >&2
    return 1
  fi

  # Create last-active marker
  gsd_safe_touch "$project_dir/last-active"

  # Set as current project
  gsd_atomic_write "$PLANNING_DIR/.current-project" "$project_name"

  # Release lock
  gsd_lock_release "$lock_file"

  echo "$project_id"
}

# List all projects
list_projects() {
  ensure_planning_dirs
  local current
  current=$(get_active_project 2>/dev/null || echo "")

  for dir in "$PROJECTS_DIR"/*/; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    local status="  "
    [ "$name" = "$current" ] && status="* "
    local repo
    repo=$(grep '^repository:' "$dir/project.yml" 2>/dev/null | cut -d' ' -f2-)
    echo "${status}${name} (${repo})"
  done
}

# Check if project exists
project_exists() {
  local project="$1"
  [ -d "$PROJECTS_DIR/$project" ]
}

# Get project planning directory
get_project_planning_dir() {
  local project="$1"
  echo "$PROJECTS_DIR/$project"
}

# Discover projects from commit history
discover_projects_from_commits() {
  git log --oneline -200 2>/dev/null | \
    grep -o '\[[^]]*\]' | \
    tr -d '[]' | \
    sort -u
}

# Execute the function if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  "$@"
fi
