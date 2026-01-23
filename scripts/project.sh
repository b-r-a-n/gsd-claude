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

# Get current repo root (or pwd if not in a repo)
get_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

# Compute hash of repo root path (first 12 chars of SHA1)
# Used to create repo-scoped state directories
get_repo_hash() {
  local repo_root
  repo_root=$(get_repo_root)
  echo -n "$repo_root" | shasum -a 1 | cut -c1-12
}

# Get repo-scoped state directory, creating if needed
# Returns: ~/.claude/planning/repos/<hash>/
get_repo_state_dir() {
  local hash
  hash=$(get_repo_hash)
  local repo_state_dir="$PLANNING_DIR/repos/$hash"
  mkdir -p "$repo_state_dir"
  echo "$repo_state_dir"
}

# Validate that a project belongs to current repo
# Returns: 0 if match, 1 if mismatch or error
validate_project_repo() {
  local project="$1"
  local project_yml="$PROJECTS_DIR/$project/project.yml"

  # Check project exists
  if [ ! -f "$project_yml" ]; then
    return 1
  fi

  # Get project's registered repo
  local project_repo
  project_repo=$(grep '^repository:' "$project_yml" 2>/dev/null | cut -d' ' -f2-)

  # Get current repo
  local current_repo
  current_repo=$(get_repo_root)

  # Compare
  [ "$project_repo" = "$current_repo" ]
}

# Get projects registered for current repo
# Returns: newline-separated list of project names
get_projects_for_repo() {
  ensure_planning_dirs
  for dir in "$PROJECTS_DIR"/*/; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    if validate_project_repo "$name"; then
      echo "$name"
    fi
  done
}

# Check project selection ambiguity for current repo
# Returns on stdout: "none", "single", "selected", or "ambiguous"
# When "ambiguous", outputs project list to stderr (one per line)
check_project_ambiguity() {
  local repo_state_dir
  repo_state_dir=$(get_repo_state_dir)

  # Get projects for this repo
  local repo_projects
  repo_projects=$(get_projects_for_repo)
  local project_count
  project_count=$(echo "$repo_projects" | grep -c . 2>/dev/null || echo 0)

  # No projects for this repo
  if [ "$project_count" -eq 0 ] || [ -z "$repo_projects" ]; then
    echo "none"
    return 0
  fi

  # Check if there's an explicit selection (repo-local current-project)
  if [ -f "$repo_state_dir/current-project" ]; then
    local selected
    selected=$(cat "$repo_state_dir/current-project" | tr -d ' \n')
    if [ -n "$selected" ]; then
      echo "selected"
      return 0
    fi
  fi

  # Single project - no ambiguity
  if [ "$project_count" -eq 1 ]; then
    echo "single"
    return 0
  fi

  # Multiple projects, no explicit selection - ambiguous
  # Output project list to stderr for caller to use
  echo "$repo_projects" >&2
  echo "ambiguous"
  return 0
}

# Compute project ID from repo root and project name
compute_project_id() {
  local project_name="$1"
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null || echo "no-repo")
  echo -n "${repo_root}:${project_name}" | shasum -a 1 | cut -c1-12
}

# Get active project (priority: env var > repo-local > auto-select single > global (if repo matches) > last-active > commit history)
get_active_project() {
  # 1. Environment variable (highest priority - explicit override, no repo validation)
  if [ -n "$GSD_PROJECT" ]; then
    echo "$GSD_PROJECT"
    return 0
  fi

  # 2. Repo-local current-project file
  local repo_state_dir
  repo_state_dir=$(get_repo_state_dir)
  if [ -f "$repo_state_dir/current-project" ]; then
    local project
    project=$(cat "$repo_state_dir/current-project" | tr -d ' \n')
    if [ -n "$project" ]; then
      echo "$project"
      return 0
    fi
  fi

  # 3. Auto-select if exactly one project for this repo (and persist the choice)
  local repo_projects
  repo_projects=$(get_projects_for_repo)
  local project_count
  project_count=$(echo "$repo_projects" | grep -c . 2>/dev/null || echo 0)
  if [ "$project_count" -eq 1 ] && [ -n "$repo_projects" ]; then
    local single_project
    single_project=$(echo "$repo_projects" | head -1)
    # Persist the auto-selection so future calls see it as "selected"
    gsd_atomic_write "$repo_state_dir/current-project" "$single_project" 2>/dev/null
    echo "$single_project"
    return 0
  fi

  # 4. Global .current-project file (only if project matches current repo - backward compat)
  if [ -f "$PLANNING_DIR/.current-project" ]; then
    local project
    project=$(cat "$PLANNING_DIR/.current-project" | tr -d ' \n')
    if [ -n "$project" ] && validate_project_repo "$project"; then
      echo "$project"
      return 0
    fi
  fi

  # 5. Most recent last-active (only for repo-matching projects)
  if [ -n "$repo_projects" ]; then
    local latest_time=0
    local latest_project=""
    for project in $repo_projects; do
      local last_active="$PROJECTS_DIR/$project/last-active"
      if [ -f "$last_active" ]; then
        local mtime
        mtime=$(stat -f %m "$last_active" 2>/dev/null || stat -c %Y "$last_active" 2>/dev/null || echo 0)
        if [ "$mtime" -gt "$latest_time" ]; then
          latest_time=$mtime
          latest_project=$project
        fi
      fi
    done
    if [ -n "$latest_project" ]; then
      echo "$latest_project"
      return 0
    fi
  fi

  # 6. Most recent commit with [project] tag
  local from_commit
  from_commit=$(git log --oneline -50 2>/dev/null | grep -o '\[[^]]*\]' | head -1 | tr -d '[]')
  if [ -n "$from_commit" ]; then
    echo "$from_commit"
    return 0
  fi

  return 1
}

# Set active project (with atomic existence check via hold pattern)
# Writes to repo-local state file for session isolation
set_active_project() {
  local project="$1"
  local lock_file
  ensure_planning_dirs

  # Use hold pattern to atomically check existence and prevent deletion
  lock_file=$(gsd_project_hold "$project" 5)
  if [ $? -ne 0 ]; then
    echo "Error: Project '$project' not registered" >&2
    echo "Run: /gsd:commands:new-project $project" >&2
    return 1
  fi

  # Get repo-local state directory
  local repo_state_dir
  repo_state_dir=$(get_repo_state_dir)

  # Project exists and is locked - safe to update files
  # Write to repo-local state (not global) for session isolation
  gsd_atomic_write "$repo_state_dir/current-project" "$project"
  gsd_safe_touch "$PROJECTS_DIR/$project/last-active"

  # Release the hold
  gsd_project_release "$lock_file"

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
    echo "Use: /gsd:commands:set-project $project_name" >&2
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

  # Set as current project (repo-local, not global)
  local repo_state_dir
  repo_state_dir=$(get_repo_state_dir)
  gsd_atomic_write "$repo_state_dir/current-project" "$project_name"

  # Release lock
  gsd_lock_release "$lock_file"

  echo "$project_id"
}

# List projects
# Usage: list_projects [--repo]
#   --repo: Only show projects for current repository
list_projects() {
  local filter_repo=false
  if [ "$1" = "--repo" ]; then
    filter_repo=true
  fi

  ensure_planning_dirs

  # Get active project (now repo-scoped)
  local current
  current=$(get_active_project 2>/dev/null || echo "")

  # Get list of projects to show
  local projects
  if [ "$filter_repo" = true ]; then
    projects=$(get_projects_for_repo)
  else
    # All projects
    projects=""
    for dir in "$PROJECTS_DIR"/*/; do
      [ -d "$dir" ] || continue
      projects="$projects $(basename "$dir")"
    done
  fi

  # Display each project
  for name in $projects; do
    [ -z "$name" ] && continue
    local status="  "
    [ "$name" = "$current" ] && status="* "
    local repo
    repo=$(grep '^repository:' "$PROJECTS_DIR/$name/project.yml" 2>/dev/null | cut -d' ' -f2-)
    echo "${status}${name} (${repo})"
  done
}

# Check if project exists
project_exists() {
  local project="$1"
  [ -d "$PROJECTS_DIR/$project" ]
}

# Hold a project lock to prevent deletion during use (FR-007)
# Usage: gsd_project_hold <project_name> [timeout_seconds]
# Returns: 0 if project exists and lock acquired, 1 otherwise
# Outputs: Lock file path on stdout (for use with gsd_project_release)
# Note: Caller MUST call gsd_project_release when done
gsd_project_hold() {
  local project="$1"
  local timeout="${2:-30}"
  local project_dir="$PROJECTS_DIR/$project"
  local lock_file="$project_dir/.project-lock"

  if [ -z "$project" ]; then
    echo "Error: gsd_project_hold requires a project name" >&2
    return 1
  fi

  # First check if project exists (quick check before trying to lock)
  if [ ! -d "$project_dir" ]; then
    return 1
  fi

  # Acquire lock on the project
  if ! gsd_lock_acquire "$lock_file" "$timeout"; then
    echo "Error: Could not acquire project lock" >&2
    return 1
  fi

  # Re-check existence while holding lock (atomic check)
  if [ ! -d "$project_dir" ]; then
    gsd_lock_release "$lock_file"
    return 1
  fi

  # Output lock file path for caller to use with gsd_project_release
  echo "$lock_file"
  return 0
}

# Release a project lock acquired by gsd_project_hold
# Usage: gsd_project_release <lock_file>
# Returns: 0 on success
gsd_project_release() {
  local lock_file="$1"

  if [ -z "$lock_file" ]; then
    echo "Error: gsd_project_release requires a lock file path" >&2
    return 1
  fi

  gsd_lock_release "$lock_file"
  return 0
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
