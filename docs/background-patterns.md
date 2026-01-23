# Background Work Patterns in GSD

This document describes patterns for correctly handling background tasks and processes in GSD commands to prevent resource leaks.

## Overview

Background work in Claude Code can be spawned via:
- `Bash` tool with `run_in_background: true` - spawns a background shell process
- `Task` tool with `run_in_background: true` - spawns a background agent

Both return an ID that must be tracked for later cleanup.

## When to Use Background Execution

### Use Background When:
- Long-running operations (builds, tests) that would block the orchestrator
- Parallel operations where you want to spawn multiple items and poll later
- Operations where you need to continue with other work while waiting

### Prefer Foreground When:
- Short operations (< 30 seconds)
- Operations whose output is immediately needed
- Simple one-off commands
- When there's nothing else to do while waiting

## Pattern 1: Spawn and Track

**CRITICAL**: Always track spawned background work **immediately** after spawning using the `background.sh` script. This is a **required 2-step process** - GSD cannot automatically detect untracked background work.

**Why this matters:**
- STATE.md's "Active Background Work" section only shows explicitly tracked items
- verify-work and execute-phase cleanup only operate on tracked items
- Untracked processes become orphaned and may cause resource leaks
- The `/tasks` command shows all running work, but GSD commands only check STATE.md

### Background Shell (Bash)

```
# 1. Spawn the background process
Use Bash tool:
  command: "cargo build 2>&1 | tee /tmp/build.log"
  run_in_background: true

# Tool returns: { "shell_id": "abc123", "output_file": "/path/to/output" }

# 2. Track it immediately
~/.claude/commands/gsd/scripts/background.sh track_background shell abc123 "cargo build"
```

### Background Task (Agent)

```
# 1. Spawn the background agent
Use Task tool:
  prompt: "Monitor the build log and report errors"
  subagent_type: "general-purpose"
  run_in_background: true

# Tool returns: { "task_id": "xyz789", "output_file": "/path/to/output" }

# 2. Track it immediately
~/.claude/commands/gsd/scripts/background.sh track_background task xyz789 "build monitor agent"
```

## Pattern 2: Poll for Completion

Use `TaskOutput` with `block: false` for non-blocking status checks.

### Poll a Background Shell

```
# Non-blocking check
Use TaskOutput tool:
  task_id: "abc123"
  block: false
  timeout: 1000

# Returns status and any new output
# If still running: status will indicate "running"
# If complete: status will indicate "complete" with final output
```

### Poll a Background Task

```
# Non-blocking check
Use TaskOutput tool:
  task_id: "xyz789"
  block: false
  timeout: 1000

# Same pattern - check status without blocking
```

### Polling Loop Pattern

```
# In your command workflow:
1. Check for tracked background work:
   items=$(~/.claude/commands/gsd/scripts/background.sh list_background)

2. For each item, poll status:
   Use TaskOutput with block: false

3. If still running, decide:
   - Wait (use TaskOutput with block: true)
   - Kill (use KillShell for shells)
   - Continue (if work can proceed without it)
```

## Pattern 3: Cleanup

### Cleanup a Specific Shell

```
# Kill the background process
Use KillShell tool:
  shell_id: "abc123"

# Remove from tracking
~/.claude/commands/gsd/scripts/background.sh clear_background abc123
```

### Cleanup All Background Work

```
# 1. Get list of tracked items
items=$(~/.claude/commands/gsd/scripts/background.sh get_background_ids)

# 2. For each item, kill if needed
for item in $items; do
  type=$(echo $item | cut -d: -f1)
  id=$(echo $item | cut -d: -f2)

  if [ "$type" = "shell" ]; then
    Use KillShell tool with shell_id: $id
  fi
  # Note: Task agents cannot be killed, only awaited
done

# 3. Clear all tracking
~/.claude/commands/gsd/scripts/background.sh clear_all_background
```

## Pattern 4: Timeout Handling

Always set reasonable timeouts for background work.

### With Bash Background Process

```
# Spawn with built-in timeout
Use Bash tool:
  command: "timeout 300 cargo build"  # 5 minute timeout
  run_in_background: true
```

### Polling with Deadline

```
# Set a deadline for completion
deadline=$(date -d '+10 minutes' +%s)  # or: deadline=$(($(date +%s) + 600))

# Poll until complete or deadline
while true; do
  result = Use TaskOutput with block: false, timeout: 5000

  if result.status == "complete":
    break

  if $(date +%s) > $deadline:
    # Timeout reached - kill and cleanup
    Use KillShell if applicable
    break

  # Wait before next poll
  sleep 5
done
```

## Lifecycle Best Practices

### DO:
- Always track background work immediately after spawning
- Poll periodically rather than fire-and-forget
- Clean up tracked items when complete or no longer needed
- Set timeouts on long-running operations
- Prefer foreground for short operations

### DON'T:
- Spawn background work without tracking the ID
- Assume background work will clean itself up
- Leave orphaned processes/agents running
- Fire-and-forget without any completion check
- Use background for operations < 30 seconds

## Integration with GSD Commands

### execute-phase.md

After each wave completion:
1. Check `background.sh list_background`
2. Poll each item for completion
3. Prompt user if items are still running
4. Clear tracking when confirmed complete

### verify-work.md

Before generating verification report:
1. Check for any tracked background work
2. Ensure all items complete before finalizing
3. Include background work status in report

### Executor Agents

When implementing tasks that need background work:
1. Consider if background is truly necessary
2. Track immediately after spawning
3. Include completion check before marking task done
4. Report tracked work to orchestrator

## Troubleshooting

### Check Current Background Work
```bash
# List all tracked items with details
~/.claude/commands/gsd/scripts/background.sh list_background

# Get count of tracked items
~/.claude/commands/gsd/scripts/background.sh count_background

# Check if any background work exists (returns 0 if yes, 1 if no)
~/.claude/commands/gsd/scripts/background.sh has_background
```

### Clear Stale Entries
```bash
# Clear specific item
~/.claude/commands/gsd/scripts/background.sh clear_background <id>

# Clear all
~/.claude/commands/gsd/scripts/background.sh clear_all_background
```

### Find Orphaned Processes
Use `/tasks` command in Claude Code to see all running background work.

### Clean Up Old Session Files
```bash
# List stale session files (older than N days, default 7)
~/.claude/commands/gsd/scripts/session-gc.sh list_stale_sessions 7

# Clean up stale sessions
~/.claude/commands/gsd/scripts/session-gc.sh clean_stale_sessions 7

# List all sessions for a project
~/.claude/commands/gsd/scripts/session-gc.sh list_sessions [project]
```

## Related Tools

- `background.sh` - GSD tracking script (`~/.claude/commands/gsd/scripts/background.sh`)
- `session-gc.sh` - Session garbage collection (`~/.claude/commands/gsd/scripts/session-gc.sh`)
- `TaskOutput` - Claude Code tool for polling background work
- `KillShell` - Claude Code tool for terminating background shells
- `/tasks` - Claude Code command to list all background work
