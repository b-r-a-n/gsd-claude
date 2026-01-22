#!/bin/bash
# Locking and atomic file operation utilities for GSD
# Uses mkdir-based locking for cross-platform compatibility (Linux, macOS, BSD)

# Default lock timeout in seconds
GSD_LOCK_TIMEOUT="${GSD_LOCK_TIMEOUT:-30}"

# Detect platform
GSD_PLATFORM="unknown"
case "$(uname -s)" in
  Linux*)  GSD_PLATFORM="linux" ;;
  Darwin*) GSD_PLATFORM="macos" ;;
  *)       GSD_PLATFORM="other" ;;
esac

# Acquire an exclusive lock using mkdir (atomic on POSIX)
# Usage: gsd_lock_acquire <lockfile> [timeout_seconds]
# Returns: 0 on success, 1 on timeout, 2 on error
gsd_lock_acquire() {
  local lockfile="$1"
  local timeout="${2:-$GSD_LOCK_TIMEOUT}"
  local lockdir="${lockfile}.lock"
  local pidfile="${lockdir}/pid"
  local start_time
  local current_time
  local elapsed

  if [ -z "$lockfile" ]; then
    echo "Error: gsd_lock_acquire requires a lockfile path" >&2
    return 2
  fi

  start_time=$(date +%s)

  while true; do
    # Try to create lock directory (atomic operation)
    if mkdir "$lockdir" 2>/dev/null; then
      # Lock acquired - store our PID for stale detection
      echo $$ > "$pidfile"
      return 0
    fi

    # Lock exists - check if it's stale
    if [ -f "$pidfile" ]; then
      local lock_pid
      lock_pid=$(cat "$pidfile" 2>/dev/null)

      if [ -n "$lock_pid" ]; then
        # Check if process is still running
        if ! kill -0 "$lock_pid" 2>/dev/null; then
          # Process is dead - clean up stale lock
          rm -rf "$lockdir" 2>/dev/null
          # Try again immediately
          continue
        fi
      fi
    fi

    # Check timeout
    current_time=$(date +%s)
    elapsed=$((current_time - start_time))

    if [ "$elapsed" -ge "$timeout" ]; then
      return 1  # Timeout
    fi

    # Wait before retry (100ms if available, otherwise 1s)
    if command -v perl &>/dev/null; then
      perl -e 'select(undef, undef, undef, 0.1)'
    else
      sleep 1
    fi
  done
}

# Release a lock
# Usage: gsd_lock_release <lockfile>
# Returns: 0 on success, 1 if lock wasn't held
gsd_lock_release() {
  local lockfile="$1"
  local lockdir="${lockfile}.lock"
  local pidfile="${lockdir}/pid"

  if [ -z "$lockfile" ]; then
    echo "Error: gsd_lock_release requires a lockfile path" >&2
    return 2
  fi

  # Verify we own the lock
  if [ -f "$pidfile" ]; then
    local lock_pid
    lock_pid=$(cat "$pidfile" 2>/dev/null)

    if [ "$lock_pid" != "$$" ]; then
      echo "Warning: Releasing lock not owned by this process (owner: $lock_pid, us: $$)" >&2
    fi
  fi

  # Remove lock directory
  rm -rf "$lockdir" 2>/dev/null
  return 0
}

# Check if a lock is currently held
# Usage: gsd_lock_check <lockfile>
# Returns: 0 if locked, 1 if not locked
gsd_lock_check() {
  local lockfile="$1"
  local lockdir="${lockfile}.lock"

  [ -d "$lockdir" ]
}

# Get PID of lock holder
# Usage: gsd_lock_holder <lockfile>
# Outputs: PID of holder, or empty if not locked
gsd_lock_holder() {
  local lockfile="$1"
  local pidfile="${lockfile}.lock/pid"

  if [ -f "$pidfile" ]; then
    cat "$pidfile" 2>/dev/null
  fi
}

# Execute a command while holding a lock
# Usage: gsd_with_lock <lockfile> <command> [args...]
# Returns: Exit code of command, or 1 on lock timeout
gsd_with_lock() {
  local lockfile="$1"
  shift
  local result

  if ! gsd_lock_acquire "$lockfile"; then
    echo "Error: Could not acquire lock on $lockfile" >&2
    return 1
  fi

  # Set up trap to release lock on exit
  trap 'gsd_lock_release "'"$lockfile"'"' EXIT

  # Execute command
  "$@"
  result=$?

  # Release lock (trap will also do this, but be explicit)
  gsd_lock_release "$lockfile"
  trap - EXIT

  return $result
}

# =============================================================================
# Atomic File Operations
# =============================================================================

# Atomically write content to a file using temp+rename pattern
# Usage: gsd_atomic_write <file> <content>
# Or:    echo "content" | gsd_atomic_write <file>
# Returns: 0 on success, 1 on error
gsd_atomic_write() {
  local target_file="$1"
  local content="$2"
  local target_dir
  local temp_file

  if [ -z "$target_file" ]; then
    echo "Error: gsd_atomic_write requires a file path" >&2
    return 1
  fi

  # Ensure target directory exists
  target_dir=$(dirname "$target_file")
  if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir" || return 1
  fi

  # Create temp file in same directory (required for atomic rename)
  temp_file=$(mktemp "${target_file}.XXXXXX") || return 1

  # Write content - either from argument or stdin
  if [ -n "$content" ]; then
    printf '%s' "$content" > "$temp_file"
  else
    cat > "$temp_file"
  fi

  if [ $? -ne 0 ]; then
    rm -f "$temp_file" 2>/dev/null
    return 1
  fi

  # Atomic rename - if this fails, clean up temp file
  if ! mv "$temp_file" "$target_file"; then
    rm -f "$temp_file" 2>/dev/null
    return 1
  fi

  return 0
}

# Atomically append content to a file (not truly atomic, but locked)
# Usage: gsd_atomic_append <file> <content>
# Returns: 0 on success, 1 on error
gsd_atomic_append() {
  local target_file="$1"
  local content="$2"
  local lockfile="${target_file}"

  if [ -z "$target_file" ]; then
    echo "Error: gsd_atomic_append requires a file path" >&2
    return 1
  fi

  # Use lock for append since we can't do atomic append with rename
  if ! gsd_lock_acquire "$lockfile"; then
    echo "Error: Could not acquire lock for append" >&2
    return 1
  fi

  printf '%s' "$content" >> "$target_file"
  local result=$?

  gsd_lock_release "$lockfile"
  return $result
}

# Execute the function if called directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  "$@"
fi
