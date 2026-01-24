# Background Work Patterns in GSD

This document describes patterns for correctly handling background tasks and processes in GSD commands to prevent resource leaks.

## Overview

Background work in Claude Code can be spawned via:
- `Bash` tool with `run_in_background: true` - spawns a background shell process
- `Task` tool with `run_in_background: true` - spawns a background agent

Both return an ID that must be tracked for later cleanup.

## Recommended: Task API Metadata Tracking

**NEW**: Background work should be tracked in task metadata using the Task API.

### Background Work Metadata Schema

```typescript
{
  backgroundWork: [
    {
      id: string;           // "shell:abc123" or "task:xyz789"
      type: "shell" | "task";
      description: string;
      spawnedAt: string;    // ISO timestamp
      status: "running" | "completed" | "failed";
      outputFile?: string;
    }
  ];
  backgroundSummary: {
    total: number;
    running: number;
    completed: number;
  };
}
```

### Tracking via TaskUpdate

```
# After spawning a background shell
Use Bash tool:
  command: "cargo build 2>&1 | tee /tmp/build.log"
  run_in_background: true
# Returns: { "shell_id": "abc123", "output_file": "/path/to/output" }

# Track in task metadata
TaskUpdate:
  taskId: "<current-task-id>"
  metadata:
    backgroundWork:
      - id: "shell:abc123"
        type: "shell"
        description: "cargo build"
        spawnedAt: "2024-01-15T14:30:00Z"
        status: "running"
        outputFile: "/path/to/output"
```

### Polling and Completion

```
# Check status via TaskOutput
result = TaskOutput(task_id: "abc123", block: false)

if result.complete:
  # Update metadata to reflect completion
  TaskUpdate:
    taskId: "<current-task-id>"
    metadata:
      backgroundWork:
        - id: "shell:abc123"
          status: "completed"
          ...
```

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

**CRITICAL**: Always track spawned background work **immediately** after spawning via TaskUpdate metadata. This is a **required 2-step process** - GSD cannot automatically detect untracked background work.

**Why this matters:**
- Task metadata's `backgroundWork` array is the authoritative tracking location
- verify-work and execute-phase cleanup only operate on tracked items
- Untracked processes become orphaned and may cause resource leaks
- The `/tasks` command shows all running work, but GSD commands only check task metadata

### Background Shell (Bash)

```
# 1. Spawn the background process
Use Bash tool:
  command: "cargo build 2>&1 | tee /tmp/build.log"
  run_in_background: true

# Tool returns: { "shell_id": "abc123", "output_file": "/path/to/output" }

# 2. Track it immediately in task metadata
TaskUpdate:
  taskId: "<current-task-id>"
  metadata:
    backgroundWork:
      - id: "shell:abc123"
        type: "shell"
        description: "cargo build"
        spawnedAt: "2024-01-15T14:30:00Z"
        status: "running"
        outputFile: "/path/to/output"
```

### Background Task (Agent)

```
# 1. Spawn the background agent
Use Task tool:
  prompt: "Monitor the build log and report errors"
  subagent_type: "general-purpose"
  run_in_background: true

# Tool returns: { "task_id": "xyz789", "output_file": "/path/to/output" }

# 2. Track it immediately in task metadata
TaskUpdate:
  taskId: "<current-task-id>"
  metadata:
    backgroundWork:
      - id: "task:xyz789"
        type: "task"
        description: "build monitor agent"
        spawnedAt: "2024-01-15T14:30:00Z"
        status: "running"
        outputFile: "/path/to/output"
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
1. Check for tracked background work in task metadata:
   task = TaskGet(taskId)
   backgroundWork = task.metadata.backgroundWork

2. For each item, poll status:
   Use TaskOutput with block: false

3. Update metadata with completion status:
   TaskUpdate:
     taskId: "<task-id>"
     metadata:
       backgroundWork: [updated items with status: "completed"]

4. If still running, decide:
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

# Update metadata to reflect completion/cleanup
task = TaskGet(taskId)
updated_work = [item for item in task.metadata.backgroundWork if item.id != "shell:abc123"]
TaskUpdate:
  taskId: "<task-id>"
  metadata:
    backgroundWork: updated_work
```

### Cleanup All Background Work

```
# 1. Get list of tracked items from task metadata
task = TaskGet(taskId)
backgroundWork = task.metadata.backgroundWork

# 2. For each item, kill if needed
for item in backgroundWork:
  if item.type == "shell" and item.status == "running":
    Use KillShell tool with shell_id: item.id.replace("shell:", "")
  # Note: Task agents cannot be killed, only awaited

# 3. Clear tracking in metadata
TaskUpdate:
  taskId: "<task-id>"
  metadata:
    backgroundWork: []
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

After each batch completion:
1. Query `TaskGet(taskId).metadata.backgroundWork` for all tasks
2. Poll each running item via `TaskOutput`
3. Prompt user if items are still running
4. Update metadata with final statuses

### verify-work.md

Before generating verification report:
1. Check for any tracked background work in task metadata
2. Ensure all items complete before finalizing
3. Include background work status in report

### Executor Agents

When implementing tasks that need background work:
1. Consider if background is truly necessary
2. Track immediately after spawning via TaskUpdate
3. Include completion check before marking task done
4. Report tracked work to orchestrator

## Discovered Tasks

Tasks may discover additional work during execution. Track these as discovered tasks:

### Discovered Task Metadata Schema

```typescript
{
  discovered: true;
  discoveredBy: string;     // Parent task ID
  discoveredAt: string;     // ISO timestamp
  discoveryReason: "blocker" | "prerequisite" | "bug-fix";
  approved: boolean;        // User must approve
  priority: "critical" | "high" | "medium" | "low";
}
```

### Creating a Discovered Task

```
TaskCreate:
  subject: "[D] [project] Fix missing dependency"
  description: "Discovered during Task 2.1: The authentication module requires..."
  metadata:
    gsd_project: "my-app"
    gsd_phase: 1
    gsd_task_id: "D-001"
    gsd_type: "task"
    discovered: true
    discoveredBy: "task_id_2_1"
    discoveredAt: "2024-01-15T14:30:00Z"
    discoveryReason: "blocker"
    approved: false
    priority: "critical"
```

### Approval Flow

User must approve discovered tasks before execution:
- **Approve**: Add to execution queue with appropriate blockedBy
- **Queue**: Save for later batch approval
- **Reject**: Mark as won't fix
- **Pause**: Stop execution for investigation

Safety limit: Max 3 discovered tasks per batch before mandatory pause.

## Troubleshooting

### Check Current Background Work

```
# Query task metadata for background work
task = TaskGet(taskId)
backgroundWork = task.metadata.backgroundWork

# Check each item's status
for item in backgroundWork:
  if item.status == "running":
    result = TaskOutput(task_id: item.id, block: false)
    # Update status based on result
```

### Clear Stale Entries

```
# Clear all background work from task metadata
TaskUpdate:
  taskId: "<task-id>"
  metadata:
    backgroundWork: []
```

### Find Orphaned Processes
Use `/tasks` command in Claude Code to see all running background work (both tracked and untracked).

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

### Task API
- `TaskCreate` - Create tasks with metadata for tracking
- `TaskUpdate` - Update task status and metadata (including backgroundWork)
- `TaskGet` - Retrieve task details including background work
- `TaskList` - List all tasks, filter by project/phase
- `TaskOutput` - Poll background work for completion
- `TaskStop` - Stop a running background task

### Claude Code Built-in
- `KillShell` - Terminate background shells
- `/tasks` - List all background work (both tracked and untracked)
