#!/bin/bash
# Session garbage collection utilities for GSD
# Manages cleanup of stale session files across all projects

# Get script directory for sourcing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PLANNING_DIR="$HOME/.claude/planning"
PROJECTS_DIR="$PLANNING_DIR/projects"

# Default stale threshold in days
DEFAULT_STALE_DAYS=7

# List stale sessions older than N days
# Usage: list_stale_sessions [days]
# Output: One session file per line with metadata
list_stale_sessions() {
  local days="${1:-$DEFAULT_STALE_DAYS}"

  if [ ! -d "$PROJECTS_DIR" ]; then
    echo "No projects directory found" >&2
    return 1
  fi

  echo "Sessions older than $days days:"
  echo ""

  local found=0
  for project_dir in "$PROJECTS_DIR"/*/; do
    [ -d "$project_dir" ] || continue
    local project_name
    project_name=$(basename "$project_dir")
    local sessions_dir="$project_dir/sessions"

    [ -d "$sessions_dir" ] || continue

    # Find session files older than N days
    while IFS= read -r session_file; do
      [ -z "$session_file" ] && continue
      found=$((found + 1))

      local filename
      filename=$(basename "$session_file")
      local age_days
      age_days=$(( ( $(date +%s) - $(stat -f %m "$session_file" 2>/dev/null || stat -c %Y "$session_file" 2>/dev/null || echo 0) ) / 86400 ))

      # Check if session was resumed
      local status="orphaned"
      if grep -q "Status.*Resumed" "$session_file" 2>/dev/null; then
        status="resumed"
      fi

      echo "  [$project_name] $filename ($age_days days old, $status)"
    done < <(find "$sessions_dir" -name "session-*.md" -mtime +"$days" 2>/dev/null)
  done

  if [ "$found" -eq 0 ]; then
    echo "  No stale sessions found"
  fi

  echo ""
  echo "Total: $found stale session(s)"
}

# Clean stale sessions older than N days
# Usage: clean_stale_sessions [days] [--force]
# Without --force, prompts for confirmation
clean_stale_sessions() {
  local days="${1:-$DEFAULT_STALE_DAYS}"
  local force=false
  [ "$2" = "--force" ] && force=true

  if [ ! -d "$PROJECTS_DIR" ]; then
    echo "No projects directory found" >&2
    return 1
  fi

  # First, list what would be deleted
  echo "The following sessions will be deleted:"
  echo ""

  local files_to_delete=()
  for project_dir in "$PROJECTS_DIR"/*/; do
    [ -d "$project_dir" ] || continue
    local project_name
    project_name=$(basename "$project_dir")
    local sessions_dir="$project_dir/sessions"

    [ -d "$sessions_dir" ] || continue

    while IFS= read -r session_file; do
      [ -z "$session_file" ] && continue
      files_to_delete+=("$session_file")

      local filename
      filename=$(basename "$session_file")
      echo "  [$project_name] $filename"
    done < <(find "$sessions_dir" -name "session-*.md" -mtime +"$days" 2>/dev/null)
  done

  if [ ${#files_to_delete[@]} -eq 0 ]; then
    echo "  No stale sessions to delete"
    return 0
  fi

  echo ""
  echo "Total: ${#files_to_delete[@]} file(s)"
  echo ""

  # Confirm unless --force
  if [ "$force" != true ]; then
    read -p "Delete these files? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Aborted"
      return 1
    fi
  fi

  # Delete the files
  local deleted=0
  for file in "${files_to_delete[@]}"; do
    if rm "$file" 2>/dev/null; then
      deleted=$((deleted + 1))
    else
      echo "Failed to delete: $file" >&2
    fi
  done

  echo "Deleted $deleted file(s)"
}

# Mark a session as having been resumed
# Usage: mark_session_resumed <project> <session_id>
# Appends a "Resumed" status to the session file
mark_session_resumed() {
  local project="$1"
  local session_id="$2"

  if [ -z "$project" ] || [ -z "$session_id" ]; then
    echo "Error: mark_session_resumed requires <project> <session_id>" >&2
    return 1
  fi

  local sessions_dir="$PROJECTS_DIR/$project/sessions"

  # Find the session file (support partial match)
  local session_file
  session_file=$(find "$sessions_dir" -name "session-*${session_id}*.md" 2>/dev/null | head -1)

  if [ -z "$session_file" ] || [ ! -f "$session_file" ]; then
    echo "Error: Session file not found for ID: $session_id" >&2
    return 1
  fi

  # Check if already marked
  if grep -q "Status.*Resumed" "$session_file" 2>/dev/null; then
    echo "Session already marked as resumed"
    return 0
  fi

  # Append resumed status
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M")

  echo "" >> "$session_file"
  echo "---" >> "$session_file"
  echo "**Status**: Resumed on $timestamp" >> "$session_file"

  echo "Marked session as resumed: $(basename "$session_file")"
}

# List all sessions (not just stale) for a project
# Usage: list_sessions [project]
# If no project specified, lists for all projects
list_sessions() {
  local project="$1"

  if [ ! -d "$PROJECTS_DIR" ]; then
    echo "No projects directory found" >&2
    return 1
  fi

  local projects
  if [ -n "$project" ]; then
    projects="$project"
  else
    projects=$(ls -1 "$PROJECTS_DIR" 2>/dev/null)
  fi

  for proj in $projects; do
    local sessions_dir="$PROJECTS_DIR/$proj/sessions"
    [ -d "$sessions_dir" ] || continue

    local session_count
    session_count=$(find "$sessions_dir" -name "session-*.md" 2>/dev/null | wc -l | tr -d ' ')

    if [ "$session_count" -gt 0 ]; then
      echo "[$proj] $session_count session(s):"

      find "$sessions_dir" -name "session-*.md" -print0 2>/dev/null | while IFS= read -r -d '' session_file; do
        local filename
        filename=$(basename "$session_file")
        local age_days
        age_days=$(( ( $(date +%s) - $(stat -f %m "$session_file" 2>/dev/null || stat -c %Y "$session_file" 2>/dev/null || echo 0) ) / 86400 ))

        local status="orphaned"
        if grep -q "Status.*Resumed" "$session_file" 2>/dev/null; then
          status="resumed"
        fi

        echo "  $filename ($age_days days, $status)"
      done
      echo ""
    fi
  done
}

# Show usage
show_usage() {
  echo "Session Garbage Collection Utility"
  echo ""
  echo "Usage:"
  echo "  $0 list_stale_sessions [days]     List sessions older than N days (default: 7)"
  echo "  $0 clean_stale_sessions [days]    Delete sessions older than N days"
  echo "  $0 mark_session_resumed <project> <session_id>  Mark session as resumed"
  echo "  $0 list_sessions [project]        List all sessions"
  echo ""
  echo "Examples:"
  echo "  $0 list_stale_sessions 14         List sessions older than 14 days"
  echo "  $0 clean_stale_sessions 7 --force Delete 7+ day old sessions without prompt"
  echo "  $0 mark_session_resumed myproj 2024-01-15  Mark a session as resumed"
}

# Execute the function if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ $# -eq 0 ]; then
    show_usage
    exit 0
  fi
  "$@"
fi
