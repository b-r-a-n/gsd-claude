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

### Step 0: Get Active Project (with Ambiguity Handling)

First, check project status for this repository:

```bash
AMBIGUITY=$("~/.claude/commands/gsd/scripts/project.sh" check_project_ambiguity 2>/tmp/gsd-projects)
```

Handle each case:

**Case: "none"** - No projects for this repo:
```
No GSD projects found for this repository.

Run one of:
  /gsd:commands:new-project       Create a new project
  /gsd:commands:discover-projects Find projects from commits
```

**Case: "single" or "selected"** - Proceed normally:
```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

**Case: "ambiguous"** - Multiple projects, no explicit selection:
1. Read the project list from `/tmp/gsd-projects` (one project per line)
2. Use the `AskUserQuestion` tool to prompt the user:
   - Question: "Which project would you like to execute?"
   - Options: List each project from the file
3. After user selects, persist the choice:
   ```bash
   ~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected-project>"
   ```
4. Then get the active project and continue:
   ```bash
   PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
   PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
   ```

### Step 1: Load State

**Primary: Query Task API**

```
TaskList -> filter by:
  - metadata.gsd_project == current_project
  - metadata.gsd_phase == current_phase
```

This returns all tasks with their status, dependencies, and rich metadata.

**Determine what to execute:**
- Ready tasks = tasks where `status == "pending"` AND all `blockedBy` tasks are `completed`
- If no ready tasks and some in_progress: wait for current tasks
- If all tasks completed: report phase done

**Fallback: Read Planning Files**

If no tasks found in Task API (legacy project or migration in progress):
1. `$PLANNING_DIR/STATE.md` - Current phase and task
2. `$PLANNING_DIR/phases/phase-XX/PLAN.md` - Task details
3. `$PLANNING_DIR/phases/phase-XX/PROGRESS.md` - Completion status

Determine what to execute:
- If wave specified: execute that wave
- If continuing: find first incomplete wave
- If all complete: report phase done

### Step 2: Execute Ready Tasks

**Primary: Query Task API for unblocked tasks**

```
TaskList -> filter by:
  - metadata.gsd_project == current_project
  - metadata.gsd_phase == current_phase
  - status == "pending"
  - blockedBy.length == 0 (no blockers, or all blockers completed)
```

Ready tasks are those with no pending dependencies. Execute them, then re-query for newly unblocked tasks.

**Execution Loop:**
```
while has_incomplete_tasks:
  ready_tasks = TaskList.filter(
    gsd_project == project AND
    gsd_phase == phase AND
    status == "pending" AND
    all blockedBy tasks are "completed"
  )

  if ready_tasks.empty:
    if has_in_progress_tasks:
      wait for current tasks
    else:
      all tasks complete OR deadlock detected

  for task in ready_tasks:
    execute(task)  # Updates status to in_progress, then completed

  # Re-query for newly unblocked tasks
```

**Fallback: Parse PLAN.md waves**

If no tasks found in Task API (legacy project), parse waves from PLAN.md:
- Wave 1 tasks execute first (parallel)
- Wave 2 tasks execute after Wave 1 completes
- etc.

### Step 2.5: Handle Discovered Tasks

During execution, tasks may discover additional work that wasn't in the original plan. These "discovered tasks" require user approval before execution.

**Check for Discovered Tasks:**
```
TaskList -> filter by:
  - metadata.gsd_project == current_project
  - metadata.discovered == true
  - metadata.approved == false
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

**Primary: Use TaskGet (no PLAN.md read needed)**
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

**Fallback: Read from PLAN.md**
If task lacks rich metadata (`gsd_action` is null):
- Read the task specification from PLAN.md completely
- Identify all affected files
- Understand the acceptance criteria

#### 3.2 Read Context

**With rich metadata:**
- Read only files listed in `gsd_files`
- Context snippet in `gsd_context` often sufficient
- Constraints in `gsd_constraints` guide implementation

**Without rich metadata (fallback):**
- Read files listed in the task
- Read related files if needed for understanding
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

**Secondary: PROGRESS.md (audit trail)**

Also update `$PLANNING_DIR/phases/phase-XX/PROGRESS.md` for git-visible history:

```markdown
### Wave 1
- [x] Task 1.1: [Title] - commit: abc123
- [x] Task 1.2: [Title] - commit: def456
- [ ] Task 1.3: [Title]
```

Note: Commits are automatically tagged with `[project-name]` by the VCS adapter.

**Secondary: STATE.md (fallback)**

Update `$PLANNING_DIR/STATE.md` for legacy compatibility:

```markdown
## Current Status
- **Phase**: [N]
- **Task**: [Current task]
- **Status**: In Progress

## History
- [YYYY-MM-DD HH:MM] Task X.Y completed
```

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

**Checking for newly unblocked tasks:**
```
TaskList -> filter:
  - status == "pending"
  - all blockedBy tasks have status == "completed"
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
