#!/bin/bash
# Background work tracking utilities for GSD
# Manages the "Active Background Work" section in STATE.md

# Get script directory for sourcing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source locking utilities
source "$SCRIPT_DIR/lock.sh"

# Source project utilities for getting planning dir
source "$SCRIPT_DIR/project.sh"

# Section header for background work in STATE.md
BACKGROUND_SECTION="## Active Background Work"

# Get planning dir for active project
# Returns: planning directory path or error
get_planning_dir() {
  local project
  project=$(get_active_project 2>/dev/null)
  if [ -z "$project" ]; then
    echo "Error: No active project" >&2
    return 1
  fi
  echo "$PROJECTS_DIR/$project"
}

# Ensure the background work section exists in STATE.md
# Creates it before the History section if not present
ensure_background_section() {
  local state_file="$1"

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Check if section already exists
  if grep -q "^$BACKGROUND_SECTION" "$state_file"; then
    return 0
  fi

  # Insert section before History section (or at end if no History)
  gsd_locked_update "$state_file" awk -v section="$BACKGROUND_SECTION" '
    /^## History/ && !inserted {
      print section
      print ""
      inserted = 1
    }
    { print }
    END {
      if (!inserted) {
        print ""
        print section
        print ""
      }
    }
  '
}

# Track a background work item
# Usage: track_background <type> <id> <description>
# Types: shell, task
# Example: track_background shell abc123 "cargo build"
track_background() {
  local type="$1"
  local id="$2"
  local description="$3"

  if [ -z "$type" ] || [ -z "$id" ]; then
    echo "Error: track_background requires <type> <id> [description]" >&2
    return 1
  fi

  local planning_dir
  planning_dir=$(get_planning_dir) || return 1
  local state_file="$planning_dir/STATE.md"

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Ensure section exists
  ensure_background_section "$state_file" || return 1

  # Format: - <type>:<id> - <description> - spawned <timestamp>
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local entry="- ${type}:${id} - ${description:-no description} - spawned ${timestamp}"

  # Add entry after the section header
  gsd_locked_update "$state_file" awk -v section="$BACKGROUND_SECTION" -v entry="$entry" '
    $0 == section {
      print
      print entry
      next
    }
    { print }
  '

  echo "Tracked: ${type}:${id}"
}

# List tracked background work items
# Usage: list_background
# Output: One item per line in format: <type>:<id> - <description> - spawned <timestamp>
list_background() {
  local planning_dir
  planning_dir=$(get_planning_dir) || return 1
  local state_file="$planning_dir/STATE.md"

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Extract entries from the background section
  awk -v section="$BACKGROUND_SECTION" '
    $0 == section { in_section = 1; next }
    /^## / && in_section { in_section = 0 }
    in_section && /^- (shell|task):/ { print substr($0, 3) }
  ' "$state_file"
}

# Get count of tracked background items
# Usage: count_background
# Output: Number of tracked items
count_background() {
  local count
  count=$(list_background 2>/dev/null | wc -l | tr -d ' ')
  echo "${count:-0}"
}

# Clear a specific background work item by ID
# Usage: clear_background <id>
# The id can be just the ID part or the full type:id
clear_background() {
  local id="$1"

  if [ -z "$id" ]; then
    echo "Error: clear_background requires <id>" >&2
    return 1
  fi

  local planning_dir
  planning_dir=$(get_planning_dir) || return 1
  local state_file="$planning_dir/STATE.md"

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Remove lines containing the ID in the background section
  # Handle both "shell:abc123" and just "abc123" patterns
  gsd_locked_update "$state_file" awk -v section="$BACKGROUND_SECTION" -v id="$id" '
    $0 == section { in_section = 1; print; next }
    /^## / && in_section { in_section = 0 }
    in_section && /^- (shell|task):/ && index($0, id) > 0 { next }
    { print }
  '

  echo "Cleared: $id"
}

# Clear all background work items
# Usage: clear_all_background
clear_all_background() {
  local planning_dir
  planning_dir=$(get_planning_dir) || return 1
  local state_file="$planning_dir/STATE.md"

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Remove all entries in the background section but keep the header
  gsd_locked_update "$state_file" awk -v section="$BACKGROUND_SECTION" '
    $0 == section { in_section = 1; print; next }
    /^## / && in_section { in_section = 0 }
    in_section && /^- (shell|task):/ { next }
    { print }
  '

  echo "Cleared all background work"
}

# Check if any background work is tracked
# Usage: has_background
# Returns: 0 if there are tracked items, 1 if empty
has_background() {
  local count
  count=$(count_background)
  [ "$count" -gt 0 ]
}

# Get IDs of all tracked background work
# Usage: get_background_ids
# Output: One ID per line in format type:id
get_background_ids() {
  list_background 2>/dev/null | sed 's/ - .*//'
}

# Execute the function if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  "$@"
fi
