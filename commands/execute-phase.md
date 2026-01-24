---
name: gsd-execute-phase
description: Execute the planned tasks for current phase
args: "[wave_number]"
---

# Execute Phase

You are executing tasks from a GSD project plan. Each task is executed with fresh context to prevent "context rot."

## Input

- **Wave number**: $ARGUMENTS (optional - execute specific wave, or continue from current state)

## Workflow

## Local Task Cache Strategy

To minimize context bloat from repeated TaskList queries, maintain a local task cache during execution:

### Cache Initialization
- Query TaskList ONCE at the start of execution
- Store all tasks matching the project/phase in local variables
- Track tasks by their Task API ID for quick lookup

### Cache Structure
```
task_cache = {
  tasks: [                    # All tasks for this project/phase
    {
      id: "<task-api-id>",
      subject: "...",
      status: "pending"|"in_progress"|"completed",
      blockedBy: ["<task-id>", ...],
      metadata: { gsd_project, gsd_phase, gsd_task_id, discovered, approved, ... }
    },
    ...
  ],
  completed_ids: Set(),       # IDs of completed tasks (for fast lookup)
  last_refresh: timestamp     # When cache was last populated from TaskList
}
```

### Cache Operations

**Initialize (once at start):**
```
cache = TaskList -> filter by project/phase
cache.completed_ids = Set(tasks where status == "completed")
cache.last_refresh = now()
```

**Find ready tasks (local filtering):**
```
ready_tasks = cache.tasks.filter(
  task.status == "pending" AND
  task.blockedBy.every(id => cache.completed_ids.has(id))
)
```

**Update on completion (local mutation):**
```
cache.tasks[task_id].status = "completed"
cache.completed_ids.add(task_id)
# DO NOT re-query TaskList
```

**Refresh (only when necessary):**
```
if ready_tasks.empty AND has_pending_tasks:
  # Re-query to detect deadlock or phase completion
  cache = TaskList -> filter by project/phase
  cache.last_refresh = now()
```

### When to Re-query TaskList
1. **Initial load** - Start of execute-phase
2. **Deadlock detection** - No ready tasks but pending tasks exist
3. **Final verification** - Phase completion check
4. **Discovered task creation** - After TaskCreate for new discovered tasks

### When NOT to Re-query
- After marking a task in_progress (local update only)
- After marking a task completed (local update + add to completed_ids)
- When finding next ready task (filter from cache)
- During batch completion reporting (use cache)

### Step 0: Get Active Project

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_or_select_project)
case $? in
  0) PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT" ;;
  1) # Use AskUserQuestion with $PROJECT (contains list of available projects) ;;
  2) # No projects - suggest /gsd:commands:new-project or /gsd:commands:discover-projects ;;
esac
```

**Exit code 0**: Project resolved - continue with `$PLANNING_DIR`

**Exit code 1**: Multiple projects need selection
- `$PROJECT` contains newline-separated list of available projects
- Use `AskUserQuestion` tool: "Which project would you like to execute?"
- After selection: `~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected>"`
- Re-run get_or_select_project to continue

**Exit code 2**: No projects found
- Suggest: `/gsd:commands:new-project` or `/gsd:commands:discover-projects`

### Step 1: Load State

**Initialize Task Cache (single query for entire execution)**

Query TaskList ONCE and cache locally:

```
# Initial cache population
all_tasks = TaskList
cache = {
  tasks: all_tasks.filter(
    task.metadata.gsd_project == current_project AND
    task.metadata.gsd_phase == current_phase
  ),
  completed_ids: Set(),
  last_refresh: now()
}

# Build completed set for fast dependency checking
for task in cache.tasks:
  if task.status == "completed":
    cache.completed_ids.add(task.id)
```

**Derive state from cache:**
```
ready_tasks = cache.tasks.filter(
  task.status == "pending" AND
  task.blockedBy.every(id => cache.completed_ids.has(id))
)
in_progress_tasks = cache.tasks.filter(task.status == "in_progress")
pending_tasks = cache.tasks.filter(task.status == "pending")
```

- If no tasks in cache: report "No tasks found"
- If no ready tasks and some in_progress: wait for current tasks
- If all tasks completed: report phase done

**No tasks in cache:**
If cache contains no tasks for the current project/phase, report:
```
No tasks found in Task API for project: [project-name], phase: [N]

This may indicate:
- A new session (tasks were not recreated)
- Phase not yet planned

Run:
  /gsd:commands:resume-work     Restore tasks from session snapshot
  /gsd:commands:plan-phase [N]  Create tasks for this phase
```

### Step 2: Execute Ready Tasks

**Find ready tasks from cache (no API query)**

```
ready_tasks = cache.tasks.filter(
  task.status == "pending" AND
  task.blockedBy.every(id => cache.completed_ids.has(id))
)
```

Ready tasks are those with no pending dependencies. Execute them, then find newly unblocked tasks from the local cache.

**Execution Loop (cache-based):**
```
while has_incomplete_tasks_in_cache:
  # Find ready tasks from LOCAL CACHE (no TaskList query)
  ready_tasks = cache.tasks.filter(
    status == "pending" AND
    all blockedBy IDs are in cache.completed_ids
  )

  if ready_tasks.empty:
    pending_count = cache.tasks.filter(status == "pending").length

    if pending_count > 0:
      # Possible deadlock or stale cache - RE-QUERY TaskList
      cache = refresh_cache_from_TaskList()
      ready_tasks = find_ready_tasks_from_cache()

      if ready_tasks.empty AND pending_count > 0:
        # Confirmed deadlock
        report_deadlock()
        break
    else:
      # All tasks complete
      break

  for task in ready_tasks:
    execute(task)
    # After execution, update cache locally (see below)

  # NO re-query here - cache already updated
```

**After task completion (local cache update):**
```
# After TaskUpdate marks task completed:
cache.tasks[task.id].status = "completed"
cache.completed_ids.add(task.id)
# This unblocks dependent tasks without re-querying
```

### Step 2.5: Handle Discovered Tasks

During execution, tasks may discover additional work that wasn't in the original plan. These "discovered tasks" require user approval before execution.

**Check for Discovered Tasks (from cache):**
```
discovered_unapproved = cache.tasks.filter(
  task.metadata.discovered == true AND
  task.metadata.approved != true
)
```

**After creating a new discovered task:**
```
# TaskCreate returns new task - add to cache manually
new_task = TaskCreate(...)
cache.tasks.push({
  id: new_task.id,
  subject: new_task.subject,
  status: "pending",
  blockedBy: [],
  metadata: new_task.metadata
})
# DO NOT re-query TaskList
```

**After approving a discovered task:**
```
# Update cache locally after TaskUpdate
cache.tasks[task.id].metadata.approved = true
# DO NOT re-query TaskList
```

**Discovered Task Metadata Schema:**
```typescript
{
  discovered: true;
  discoveredBy: string;     // Parent task ID that found this
  discoveredAt: string;     // ISO timestamp
  discoveryReason: "blocker" | "prerequisite" | "bug-fix";
  approved: boolean;        // User must approve
  priority: "critical" | "high" | "medium" | "low";
}
```

**Creating a Discovered Task:**
```
TaskCreate:
  subject: "[D] [project] Fix missing dependency"
  description: "Discovered during Task 2.1..."
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

**User Approval Flow:**
```
⚠ Discovered Task Requires Approval

Task: [D-001] Fix missing dependency
Reason: blocker (discovered by Task 2.1)
Priority: critical

Options:
1. Approve - Add to execution queue
2. Queue - Save for later batch approval
3. Reject - Mark as won't fix
4. Pause - Stop execution for investigation

Choice [1]:
```

**After Approval:**
```
TaskUpdate:
  taskId: "<discovered-task-id>"
  metadata:
    approved: true
  addBlockedBy: [<blocking-task-ids>]  # If it blocks current work
```

**Safety Limits:**
- Max 3 discovered tasks per batch before mandatory pause
- Critical blockers require immediate user decision
- Log discovered tasks in PROGRESS.md with `[D]` prefix

**PROGRESS.md Entry:**
```markdown
- [D] Task D-001: Fix missing dependency - discovered by 2.1 (approved)
```

**Per-Task Execution Pattern:**

```
1. MARK task in_progress via TaskUpdate
2. READ task details from TaskGet or PLAN.md
3. READ required source files
4. IMPLEMENT the changes
5. VERIFY against acceptance criteria
6. STAGE changed files using VCS
7. COMMIT with atomic message
8. MARK task completed via TaskUpdate (with commit hash)
9. UPDATE PROGRESS.md (audit trail)
10. REPORT completion
```

**Task API Integration:**

Before starting a task:
```
TaskUpdate:
  taskId: "<task-id>"
  status: "in_progress"
```

After completing a task:
```
TaskUpdate:
  taskId: "<task-id>"
  status: "completed"
  metadata:
    gsd_commit_hash: "<commit-hash>"
    gsd_completed_at: "<ISO-timestamp>"
```

**Note**: The Task API provides real-time status tracking. PROGRESS.md is updated as an audit trail.

### Step 3: Task Implementation

For each task, follow the executor agent guidelines:

#### 3.1 Understand the Task

**Use TaskGet for complete task context:**
```
task = TaskGet(taskId)
metadata = task.metadata

# Extract from metadata:
files = metadata.gsd_files           # Files to read/modify
action = metadata.gsd_action         # What to do
context = metadata.gsd_context       # Key context
acceptance = metadata.gsd_acceptance # How to verify
constraints = metadata.gsd_constraints # Project constraints
commit_type = metadata.gsd_commit_type # VCS commit type
```

**Note:** Task API is the sole source of truth for task state and context. PLAN.md is documentation only.

#### 3.2 Read Context

**With rich metadata:**
- Read only files listed in `gsd_files`
- Context snippet in `gsd_context` often sufficient
- Constraints in `gsd_constraints` guide implementation

**If task has minimal metadata:**
- Read source files listed in task description
- Read related source files if needed for understanding
- Note existing patterns to follow

#### 3.3 Implement Changes
- Make the specified changes
- Follow existing code style
- Keep changes minimal and focused
- Don't make changes outside task scope

#### 3.4 Verify
- Check acceptance criteria
- Run tests if specified
- Verify no regressions

#### 3.5 Commit
Use the VCS abstraction with explicit verification:

```bash
# 1. Check what changed
~/.claude/commands/gsd/scripts/vcs.sh vcs-status
```

**Compare against task specification:**
- The task in PLAN.md lists expected files under "Files:" or "Files to modify:"
- Stage files that match the task specification
- New files should only be staged if listed in the task spec

**Handle discrepancies:**
- **Expected file not modified**: May indicate incomplete implementation - verify before proceeding
- **Unexpected file modified**: Could be scope creep or unintended side effect - investigate before staging
- **Untracked files not in spec**: Do not stage - either add to .gitignore or note for future task

```bash
# 2. Stage each file listed in task spec
~/.claude/commands/gsd/scripts/vcs.sh vcs-stage <file1>
~/.claude/commands/gsd/scripts/vcs.sh vcs-stage <file2>

# 3. Verify staged changes match expectations
~/.claude/commands/gsd/scripts/vcs.sh vcs-diff-staged

# 4. Commit with standard format
~/.claude/commands/gsd/scripts/vcs.sh vcs-atomic-commit <type> <phase> <task> "<description>"
```

Commit types:
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Refactoring
- `docs` - Documentation
- `test` - Tests
- `chore` - Maintenance

### Step 4: Update Progress

**Primary: Task API (real-time tracking)**

After each task, update via Task API:
```
TaskUpdate:
  taskId: "<task-id>"
  status: "completed"
  metadata:
    gsd_commit_hash: "<commit-hash>"
    gsd_completed_at: "2024-01-15T14:30:00Z"
```

**Audit Trail: PROGRESS.md (write-only)**

Also update `$PLANNING_DIR/phases/phase-XX/PROGRESS.md` for git-visible history:

```markdown
### Wave 1
- [x] Task 1.1: [Title] - commit: abc123
- [x] Task 1.2: [Title] - commit: def456
- [ ] Task 1.3: [Title]
```

Note: Commits are automatically tagged with `[project-name]` by the VCS adapter.

**Audit Trail: STATE.md (write-only)**

Update `$PLANNING_DIR/STATE.md` for audit trail:

```markdown
## Current Status
- **Phase**: [N]
- **Task**: [Current task]
- **Status**: In Progress

## History
- [YYYY-MM-DD HH:MM] Task X.Y completed
```

**Note:** STATE.md and PROGRESS.md are write-only for audit purposes. Task API is the sole source of truth for reads.

### Step 5: Batch Completion

After completing a batch of ready tasks, report progress:

```
✓ Batch Complete

Tasks completed this batch: [N]
Commits: [list of commit hashes]

Progress:
  Completed: [X] / [Total]
  In Progress: [Y]
  Pending: [Z] (blocked by in-progress tasks)
  Ready: [W] (no blockers, can start now)

Next: [W] tasks ready to execute
Continue? [Y/n]
```

**Checking for newly unblocked tasks (from cache):**
```
# No TaskList query needed - cache already updated from completions
ready_tasks = cache.tasks.filter(
  task.status == "pending" AND
  task.blockedBy.every(id => cache.completed_ids.has(id))
)
```

If no ready tasks found but pending tasks remain, this triggers a cache refresh:
```
if ready_tasks.empty AND cache.tasks.some(t => t.status == "pending"):
  # Re-query to verify phase state or detect deadlock
  cache = refresh_cache_from_TaskList()
```

If user confirms, proceed to next batch. If not, update state for resume later.

### Step 5.5: Cleanup Background Work

Before proceeding to the next wave or completing the phase, check for any tracked background work.

#### 5.5.1 Check for Tracked Work

```bash
# List any tracked background work
~/.claude/commands/gsd/scripts/background.sh list_background
```

If no tracked work exists, skip to the next step.

#### 5.5.2 Poll Each Item

For each tracked item, check its status:

```
Use TaskOutput tool:
  task_id: "<id from tracked item>"
  block: false
  timeout: 1000
```

#### 5.5.3 Handle Still-Running Work

If any items are still running, prompt the user:

```
⚠ Background work still running:
  - shell:abc123 - cargo build (spawned 10:30:00)
  - task:xyz789 - log monitor (spawned 10:30:05)

Options:
1. Wait for completion (recommended)
2. Kill background processes and continue
3. Leave running and continue (not recommended - may cause leaks)

Choice [1]:
```

**Option 1 - Wait**: Use `TaskOutput` with `block: true` for each item until complete.

**Option 2 - Kill**: For shell items, use `KillShell` tool. Task agents cannot be killed but will eventually timeout.

**Option 3 - Continue**: Warn that this may cause resource leaks.

#### 5.5.4 Clear Tracking

After all background work is handled:

```bash
~/.claude/commands/gsd/scripts/background.sh clear_all_background
```

Log the cleanup in PROGRESS.md:
```markdown
[YYYY-MM-DD HH:MM] Background work cleanup: [N] items cleared
```

See `~/.claude/commands/gsd/docs/background-patterns.md` for detailed patterns.

### Step 6: Phase Completion

When all waves complete:

```
Phase [N] Complete - Project: [project-name]

All [N] tasks completed
[M] commits made (tagged with [project-name])

Updated files:
  $PLANNING_DIR/phases/phase-XX/PROGRESS.md
  $PLANNING_DIR/STATE.md

Next steps:
  1. Run /gsd:commands:verify-work to verify implementation
  2. Run /gsd:commands:plan-phase [N+1] to plan next phase
```

Update `$PLANNING_DIR/STATE.md`:

```markdown
## Current Status
- **Phase**: [N]
- **Task**: All complete
- **Status**: Verification pending
```

## Error Handling

If a task fails:

1. **Don't commit broken code**
2. Document the failure in PROGRESS.md:
   ```markdown
   - [!] Task 1.3: [Title] - BLOCKED: [reason]
   ```
3. Update STATE.md with blocked status
4. Report to user with details:
   ```
   ⚠ Task 1.3 Blocked

   Reason: [what went wrong]
   Attempted: [what was tried]

   Options:
   1. Fix the issue and retry
   2. Skip this task
   3. Pause and investigate
   ```

## Guidelines

- Each task gets fresh context - don't assume memory of previous tasks
- Be explicit about what you're doing
- Commit after each task, not in batches
- If uncertain, ask rather than guess
- Keep the user informed of progress
- Use VCS abstraction for all version control operations
