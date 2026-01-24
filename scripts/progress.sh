#!/bin/bash
# Progress tracking utilities for GSD
# Provides atomic operations on PROGRESS.md files
#
# DEPRECATION NOTICE:
# This script is deprecated in favor of Claude's built-in Task API.
# Use TaskCreate, TaskUpdate, TaskList, and TaskGet instead.
#
# Migration guide:
#   - mark_task_complete() -> TaskUpdate(taskId, status: "completed", metadata: {gsd_commit_hash: "..."})
#   - mark_task_blocked()  -> TaskUpdate(taskId, status: "pending") + add blocker info to description
#   - get_task_status()    -> TaskGet(taskId) and check status field
#   - update_progress_status() -> TaskUpdate with appropriate status
#
# This script remains for backward compatibility with existing projects.
# New projects should use the Task API exclusively.

# Get script directory for sourcing other scripts
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source locking utilities
source "$SCRIPT_DIR/lock.sh"

# Emit deprecation warning (once per session)
_GSD_PROGRESS_DEPRECATED_WARNED="${_GSD_PROGRESS_DEPRECATED_WARNED:-}"
if [ -z "$_GSD_PROGRESS_DEPRECATED_WARNED" ]; then
  echo "[DEPRECATED] progress.sh: Use Claude's Task API (TaskUpdate, TaskList) instead" >&2
  export _GSD_PROGRESS_DEPRECATED_WARNED=1
fi

# Mark a task as complete in PROGRESS.md
# Usage: mark_task_complete <planning_dir> <phase> <task_id> <commit_hash>
# Returns: 0 on success, 1 on error
mark_task_complete() {
  local planning_dir="$1"
  local phase="$2"
  local task_id="$3"
  local commit_hash="$4"
  local progress_file="$planning_dir/phases/phase-$(printf '%02d' "$phase")/PROGRESS.md"

  if [ -z "$planning_dir" ] || [ -z "$phase" ] || [ -z "$task_id" ]; then
    echo "Error: mark_task_complete requires <planning_dir> <phase> <task_id> [commit_hash]" >&2
    return 1
  fi

  if [ ! -f "$progress_file" ]; then
    echo "Error: PROGRESS.md not found at $progress_file" >&2
    return 1
  fi

  # Build the sed pattern to match the task line
  # Match: - [ ] Task X.Y: ...
  # Replace with: - [x] Task X.Y: ... - commit: hash
  local pattern="s/^(- \\[ \\] Task ${task_id}:.*)$/\\1 - commit: ${commit_hash:-unknown}/"
  pattern="${pattern//\./\\.}"  # Escape dots in task_id

  # For sed, we need to escape the pattern differently
  # Use awk instead for reliability
  gsd_locked_update "$progress_file" awk -v task_id="$task_id" -v commit="$commit_hash" '
    $0 ~ "^- \\[ \\] Task " task_id ":" {
      # Replace [ ] with [x] and append commit hash
      sub(/\[ \]/, "[x]")
      if (commit != "") {
        print $0 " - commit: " commit
      } else {
        print $0
      }
      next
    }
    { print }
  '
}

# Mark a task as blocked in PROGRESS.md
# Usage: mark_task_blocked <planning_dir> <phase> <task_id> <reason>
# Returns: 0 on success, 1 on error
mark_task_blocked() {
  local planning_dir="$1"
  local phase="$2"
  local task_id="$3"
  local reason="$4"
  local progress_file="$planning_dir/phases/phase-$(printf '%02d' "$phase")/PROGRESS.md"

  if [ -z "$planning_dir" ] || [ -z "$phase" ] || [ -z "$task_id" ] || [ -z "$reason" ]; then
    echo "Error: mark_task_blocked requires <planning_dir> <phase> <task_id> <reason>" >&2
    return 1
  fi

  if [ ! -f "$progress_file" ]; then
    echo "Error: PROGRESS.md not found at $progress_file" >&2
    return 1
  fi

  gsd_locked_update "$progress_file" awk -v task_id="$task_id" -v reason="$reason" '
    $0 ~ "^- \\[ \\] Task " task_id ":" {
      # Replace [ ] with [!] and append blocked reason
      sub(/\[ \]/, "[!]")
      print $0 " - BLOCKED: " reason
      next
    }
    { print }
  '
}

# Update the overall status in PROGRESS.md
# Usage: update_progress_status <planning_dir> <phase> <status>
# Returns: 0 on success, 1 on error
update_progress_status() {
  local planning_dir="$1"
  local phase="$2"
  local status="$3"
  local progress_file="$planning_dir/phases/phase-$(printf '%02d' "$phase")/PROGRESS.md"

  if [ -z "$planning_dir" ] || [ -z "$phase" ] || [ -z "$status" ]; then
    echo "Error: update_progress_status requires <planning_dir> <phase> <status>" >&2
    return 1
  fi

  if [ ! -f "$progress_file" ]; then
    echo "Error: PROGRESS.md not found at $progress_file" >&2
    return 1
  fi

  gsd_locked_update "$progress_file" sed "s/^## Status:.*$/## Status: $status/"
}

# Append an entry to the log section in PROGRESS.md
# Usage: append_progress_log <planning_dir> <phase> <entry>
# Returns: 0 on success, 1 on error
append_progress_log() {
  local planning_dir="$1"
  local phase="$2"
  local entry="$3"
  local progress_file="$planning_dir/phases/phase-$(printf '%02d' "$phase")/PROGRESS.md"
  local timestamp
  timestamp=$(date +"%Y-%m-%d %H:%M")

  if [ -z "$planning_dir" ] || [ -z "$phase" ] || [ -z "$entry" ]; then
    echo "Error: append_progress_log requires <planning_dir> <phase> <entry>" >&2
    return 1
  fi

  if [ ! -f "$progress_file" ]; then
    echo "Error: PROGRESS.md not found at $progress_file" >&2
    return 1
  fi

  gsd_locked_update "$progress_file" awk -v entry="[$timestamp] $entry" '
    { print }
    END { print entry }
  '
}

# Get task status from PROGRESS.md
# Usage: get_task_status <planning_dir> <phase> <task_id>
# Outputs: "pending", "complete", "blocked", or "unknown"
# Returns: 0 on success, 1 if not found
get_task_status() {
  local planning_dir="$1"
  local phase="$2"
  local task_id="$3"
  local progress_file="$planning_dir/phases/phase-$(printf '%02d' "$phase")/PROGRESS.md"

  if [ -z "$planning_dir" ] || [ -z "$phase" ] || [ -z "$task_id" ]; then
    echo "Error: get_task_status requires <planning_dir> <phase> <task_id>" >&2
    return 1
  fi

  if [ ! -f "$progress_file" ]; then
    echo "Error: PROGRESS.md not found at $progress_file" >&2
    return 1
  fi

  local line
  line=$(grep "Task ${task_id}:" "$progress_file" | head -1)

  if [ -z "$line" ]; then
    echo "unknown"
    return 1
  fi

  if echo "$line" | grep -q '\[x\]'; then
    echo "complete"
  elif echo "$line" | grep -q '\[!\]'; then
    echo "blocked"
  elif echo "$line" | grep -q '\[ \]'; then
    echo "pending"
  else
    echo "unknown"
  fi
}

# Execute the function if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  "$@"
fi
