#!/bin/bash
# State management utilities for GSD
# Provides atomic operations on STATE.md files
#
# DEPRECATION NOTICE:
# This script is deprecated in favor of Claude's built-in Task API.
# Use TaskCreate, TaskUpdate, TaskList, and TaskGet instead.
#
# Migration guide:
#   - update_state_status() -> TaskUpdate(taskId, status: "in_progress" | "completed")
#   - append_state_history() -> Task metadata captures history automatically
#   - get_current_phase()    -> TaskList filtered by gsd_project, check gsd_phase
#   - get_current_status()   -> TaskGet(taskId) and check status field
#
# This script remains for backward compatibility with existing projects.
# New projects should use the Task API exclusively.

# Get script directory for sourcing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source locking utilities
source "$SCRIPT_DIR/lock.sh"

# Emit deprecation warning (once per session)
_GSD_STATE_DEPRECATED_WARNED="${_GSD_STATE_DEPRECATED_WARNED:-}"
if [ -z "$_GSD_STATE_DEPRECATED_WARNED" ]; then
  echo "[DEPRECATED] state.sh: Use Claude's Task API (TaskUpdate, TaskGet) instead" >&2
  export _GSD_STATE_DEPRECATED_WARNED=1
fi

# Update the current status section in STATE.md
# Usage: update_state_status <planning_dir> <phase> <task> <status>
# Returns: 0 on success, 1 on error
update_state_status() {
  local planning_dir="$1"
  local phase="$2"
  local task="$3"
  local status="$4"
  local state_file="$planning_dir/STATE.md"

  if [ -z "$planning_dir" ] || [ -z "$phase" ] || [ -z "$task" ] || [ -z "$status" ]; then
    echo "Error: update_state_status requires <planning_dir> <phase> <task> <status>" >&2
    return 1
  fi

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Use gsd_locked_update to atomically modify the file
  # The awk script replaces the status section while preserving everything else
  gsd_locked_update "$state_file" awk -v phase="$phase" -v task="$task" -v status="$status" '
    BEGIN { in_status = 0 }
    /^## Current Status/ {
      print "## Current Status"
      print "- **Phase**: " phase
      print "- **Task**: " task
      print "- **Status**: " status
      print ""
      in_status = 1
      next
    }
    /^## / && in_status {
      in_status = 0
    }
    !in_status { print }
  '
}

# Append an entry to the history section in STATE.md
# Usage: append_state_history <planning_dir> <entry>
# Returns: 0 on success, 1 on error
append_state_history() {
  local planning_dir="$1"
  local entry="$2"
  local state_file="$planning_dir/STATE.md"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M")

  if [ -z "$planning_dir" ] || [ -z "$entry" ]; then
    echo "Error: append_state_history requires <planning_dir> <entry>" >&2
    return 1
  fi

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Use gsd_locked_update to atomically append to history section
  gsd_locked_update "$state_file" awk -v entry="- $timestamp $entry" '
    { print }
    END { print entry }
  '
}

# Get the current phase number from STATE.md
# Usage: get_current_phase <planning_dir>
# Outputs: Phase number to stdout
# Returns: 0 on success, 1 if not found
get_current_phase() {
  local planning_dir="$1"
  local state_file="$planning_dir/STATE.md"

  if [ -z "$planning_dir" ]; then
    echo "Error: get_current_phase requires <planning_dir>" >&2
    return 1
  fi

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Extract phase number from STATE.md
  local phase
  phase=$(grep -E '^\- \*\*Phase\*\*:' "$state_file" | head -1 | sed 's/.*: *//')

  if [ -z "$phase" ]; then
    return 1
  fi

  echo "$phase"
}

# Get the current status from STATE.md
# Usage: get_current_status <planning_dir>
# Outputs: Status to stdout
# Returns: 0 on success, 1 if not found
get_current_status() {
  local planning_dir="$1"
  local state_file="$planning_dir/STATE.md"

  if [ -z "$planning_dir" ]; then
    echo "Error: get_current_status requires <planning_dir>" >&2
    return 1
  fi

  if [ ! -f "$state_file" ]; then
    echo "Error: STATE.md not found at $state_file" >&2
    return 1
  fi

  # Extract status from STATE.md
  local status
  status=$(grep -E '^\- \*\*Status\*\*:' "$state_file" | head -1 | sed 's/.*: *//')

  if [ -z "$status" ]; then
    return 1
  fi

  echo "$status"
}

# Execute the function if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  "$@"
fi
