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

Minimize context bloat by querying TaskList ONCE at execution start, then maintaining state locally.

**Cache operations:**
- **Initialize**: `cache = TaskList -> filter by project/phase`, build `completed_ids` set
- **Find ready**: Filter tasks where `status == "pending"` and all `blockedBy` IDs are in `completed_ids`
- **Update on completion**: Set `status = "completed"` in cache, add to `completed_ids` (NO re-query)
- **Refresh**: Only on deadlock detection (no ready tasks but pending remain) or discovered task creation

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

Initialize cache from TaskList (see Cache Strategy above), then derive execution state:
- **No tasks**: Suggest `/gsd:commands:resume-work` or `/gsd:commands:plan-phase`
- **No ready tasks + some in_progress**: Wait for current tasks
- **All completed**: Report phase done
- **Ready tasks available**: Proceed to execution

### Step 2: Execute Ready Tasks

**Execution Loop:**
1. Find ready tasks from cache (pending + all blockedBy IDs in completed_ids)
2. If no ready tasks but pending remain: refresh cache to detect deadlock
3. For each ready task: delegate to Executor subagent (Step 3), update cache on completion
4. Repeat until all tasks complete or deadlock detected

### Step 2.5: Handle Discovered Tasks

Tasks may discover additional work during execution. These require user approval:

1. **Detection**: Check cache for tasks with `metadata.discovered == true && !approved`
2. **Approval flow**: Present to user with options (Approve/Queue/Reject/Pause)
3. **After approval**: Update cache locally, set `approved: true`
4. **Safety**: Max 3 discovered tasks per batch; critical blockers need immediate decision
5. **Logging**: Mark in PROGRESS.md with `[D]` prefix

Discovered task metadata: `{ discovered: true, discoveredBy, discoveredAt, discoveryReason, approved, priority }`

### Step 3: Task Execution via Subagent

For each ready task, delegate execution to an Executor subagent. This keeps orchestrator context minimal while the subagent gets fresh context for implementation.

**Subagent Invocation:**

```
Task tool:
  description: "Execute task [gsd_task_id] for [project-name]"
  subagent_type: "general-purpose"
  prompt: |
    # Executor Subagent: Task [gsd_task_id]

    Execute a single GSD task autonomously.

    ## Input
    - **Task ID**: [task-api-id]
    - **Planning Directory**: [planning-dir-path]
    - **Phase Directory**: [phase-dir-path]

    ## Instructions
    1. TaskGet([task-id]) to retrieve full task specification
    2. Read only files listed in gsd_files metadata
    3. Implement changes per gsd_action
    4. Verify against gsd_acceptance criteria
    5. Stage and commit using VCS abstraction
    6. TaskUpdate to mark completed with commit hash
    7. Return structured result

    **⚠️ CRITICAL**: TaskUpdate is your final action. Implementation success means nothing until TaskUpdate marks the task completed. Without this call, the task remains in_progress and blocks all dependent tasks. Your mission is NOT complete until TaskUpdate has been called.

    Execute autonomously. Return ONLY the structured result format.
```

**Handling Subagent Response:**

The subagent returns a structured result:

```
# On success:
STATUS: success
TASK_ID: [task-api-id]
GSD_TASK: [gsd-task-id]
TITLE: [task title]
COMMIT_HASH: [short hash]
FILES_MODIFIED: [list]
SUMMARY: [description]

# On error:
STATUS: error
TASK_ID: [task-api-id]
REASON: [what went wrong]
SUGGESTION: [how to fix]

# On blocked:
STATUS: blocked
TASK_ID: [task-api-id]
BLOCKER: [what's blocking]
OPTIONS: [user choices]
```

**After Subagent Returns:**

1. **On success**: Update local cache, update PROGRESS.md, continue to next task
2. **On error**: Report to user, mark task as blocked, offer retry/skip options
3. **On blocked**: Present blocker and options to user for decision

**Note:** The subagent handles all implementation details including:
- Reading task context from TaskGet
- Reading source files
- Implementing changes
- Verifying acceptance criteria
- Committing via VCS abstraction
- Updating Task API status

### Step 4: Update Progress

After each successful subagent execution:

1. **Update local cache** (no TaskList query):
   ```
   cache.tasks[task.id].status = "completed"
   cache.completed_ids.add(task.id)
   ```

2. **Update PROGRESS.md** (audit trail):
   ```markdown
   - [x] Task 1.1: [Title] - commit: [hash from subagent]
   ```

**Note:** The subagent handles Task API updates (status, commit hash). The orchestrator only updates local cache and audit files.

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

### Step 5.4.5: Wave Reconciliation

After a wave completes, reconcile local cache with Task API to detect and fix discrepancies caused by subagent failures or incomplete updates.

#### 5.4.5.1 Query Authoritative State

Single TaskList query to get current API state:
```
api_tasks = TaskList -> filter by project
```

#### 5.4.5.2 Compare Cache vs API

Detect discrepancies between local cache and API:

| Type | Condition |
|------|-----------|
| **Stuck** | API: in_progress, but subagent returned (success/error/blocked) |
| **Cache ahead** | Cache: completed, API: in_progress/pending |
| **API ahead** | Cache: pending/in_progress, API: completed |
| **Missing in cache** | Task in API not in cache |
| **Missing in API** | Task in cache not in API (deleted) |

**Orchestrator tracking**: During wave execution, track subagent results:
```
wave_results = {
  task_id: {status, commit_hash, error_reason, blocker}
}
```

#### 5.4.5.3 Handle No Discrepancies

If cache and API match:
```
log_to_progress("Wave reconciliation: Cache and API in sync")
# Proceed to Step 5.5
```

#### 5.4.5.4 Present Discrepancies

If discrepancies detected, present to user:

```
⚠ Wave Reconciliation: Discrepancies Detected

STUCK TASKS (subagent completed but API not updated)
  Task 2.3: "Add auth middleware" - API: in_progress, Subagent: success (abc123)
  Task 2.4: "Update routes" - API: in_progress, Subagent: error

STATE MISMATCHES
  Task 2.5: Cache: completed, API: pending

Options:
  1. Auto-fix all (recommended) - Apply suggested resolutions
  2. Review each - Handle discrepancies one by one
  3. Trust API - Reset cache to match API state
  4. Skip - Continue with inconsistent state (not recommended)
```

#### 5.4.5.5 Resolution Strategies

**Auto-fix (default):**

| Discrepancy | Resolution |
|-------------|------------|
| Stuck (success) | TaskUpdate -> completed, add `gsd_reconciled` metadata |
| Stuck (error) | TaskUpdate -> pending, add `gsd_error` metadata |
| Stuck (blocked) | Keep in_progress, add blocker to metadata |
| Cache ahead | TaskUpdate API to match cache |
| API ahead | Update cache to match API |
| Missing in cache | Add to cache |
| Missing in API | Remove from cache |

**Review each:** Present individual choices per task

**Trust API:** Reset entire cache from API state

#### 5.4.5.6 Apply and Log

After resolution:
1. Execute TaskUpdate calls for API changes
2. Update local cache for consistency
3. Log to PROGRESS.md:

```markdown
### Wave Reconciliation [YYYY-MM-DD HH:MM]
| Task | Discrepancy | Resolution |
|------|-------------|------------|
| 2.3 | Stuck (success) | Marked completed (abc123) |
| 2.4 | Stuck (error) | Reset to pending |

Reconciliation complete: 2 discrepancies resolved
```

**Edge Cases:**
- **Task deleted externally**: Remove from cache, log warning
- **New task in API**: Add to cache, include in ready-task calculation
- **Duplicate completion**: Log but take no action (race condition)
- **Empty wave**: Skip stuck detection, still check cache-vs-API drift

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

### Step 5.6: VCS Clean Check

Before completing the phase, verify the working directory is clean. This ensures no uncommitted changes are left behind.

#### 5.6.1 Check Working Directory State

```bash
~/.claude/commands/gsd/scripts/vcs.sh vcs-dirty
```

**Exit code 0 (clean)**: Proceed to Step 6 (Phase Completion).

**Exit code 1 (dirty)**: Uncommitted changes detected - proceed to 5.6.2.

#### 5.6.2 Present Uncommitted Changes

Get the current status and present to the user:

```bash
~/.claude/commands/gsd/scripts/vcs.sh vcs-status
```

Display the changes with options:

```
⚠ Uncommitted changes detected:

[vcs-status output]

Options:
1. Commit changes - Stage and commit with a message
2. Stash changes - Save for later (git stash / hg shelve)
3. Discard changes - Revert all uncommitted changes (DESTRUCTIVE)
4. Continue anyway - Proceed with dirty working directory (not recommended)

Choice [1]:
```

#### 5.6.3 Handle User Choice

**Option 1 - Commit**:
- Ask for commit message
- Stage all changes: `vcs.sh vcs-stage .`
- Commit: `vcs.sh vcs-commit "<message>"`
- Log in PROGRESS.md: `[YYYY-MM-DD HH:MM] Manual commit before phase completion: <hash>`

**Option 2 - Stash**:
- For Git: `git stash push -m "GSD phase completion stash"`
- For Mercurial: `hg shelve -n "gsd-phase-completion"`
- Log in PROGRESS.md: `[YYYY-MM-DD HH:MM] Changes stashed before phase completion`

**Option 3 - Discard**:
- Confirm with user: "This will permanently discard all uncommitted changes. Are you sure? [y/N]"
- For Git: `git checkout -- . && git clean -fd`
- For Mercurial: `hg revert --all && hg purge`
- Log in PROGRESS.md: `[YYYY-MM-DD HH:MM] Uncommitted changes discarded`

**Option 4 - Continue anyway**:
- Warn: "Proceeding with uncommitted changes may cause issues in future phases."
- Log in PROGRESS.md: `[YYYY-MM-DD HH:MM] ⚠ Phase completed with uncommitted changes`
- Proceed to Step 6

After resolving (options 1-3), re-run `vcs-dirty` to confirm clean state before proceeding.

### Step 6: Phase Completion

**Prerequisite**: Step 5.6 (VCS Clean Check) must have been completed. If the user chose "Continue anyway" with a dirty working directory, include that status in the completion report.

When all waves complete:

```
Phase [N] Complete - Project: [project-name]

All [N] tasks completed
[M] commits made (tagged with [project-name])
VCS Status: [Clean | Dirty (user acknowledged)]

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
- **VCS**: [Clean | Dirty - user acknowledged]
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
