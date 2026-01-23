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

Read current state from the project's planning directory:
1. `$PLANNING_DIR/STATE.md` - Current phase and task
2. `$PLANNING_DIR/phases/phase-XX/PLAN.md` - Task details
3. `$PLANNING_DIR/phases/phase-XX/PROGRESS.md` - Completion status

Determine what to execute:
- If wave specified: execute that wave
- If continuing: find first incomplete wave
- If all complete: report phase done

### Step 2: Execute Wave

For each wave, process tasks. For parallel execution capability, note which tasks can run simultaneously.

**Per-Task Execution Pattern:**

```
1. ANNOUNCE task start
2. READ task details from PLAN.md
3. READ required source files
4. IMPLEMENT the changes
5. VERIFY against acceptance criteria
6. STAGE changed files using VCS
7. COMMIT with atomic message
8. UPDATE PROGRESS.md
9. REPORT completion
```

### Step 3: Task Implementation

For each task, follow the executor agent guidelines:

#### 3.1 Understand the Task
- Read the task specification completely
- Identify all affected files
- Understand the acceptance criteria

#### 3.2 Read Context
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

After each task, update `$PLANNING_DIR/phases/phase-XX/PROGRESS.md`:

```markdown
### Wave 1
- [x] Task 1.1: [Title] - commit: abc123
- [x] Task 1.2: [Title] - commit: def456
- [ ] Task 1.3: [Title]
```

Note: Commits are automatically tagged with `[project-name]` by the VCS adapter.

And update `$PLANNING_DIR/STATE.md`:

```markdown
## Current Status
- **Phase**: [N]
- **Task**: [Current task]
- **Status**: In Progress

## History
- [YYYY-MM-DD HH:MM] Task X.Y completed
```

### Step 5: Wave Completion

After completing a wave:

```
✓ Wave [N] Complete

Tasks completed: [N]
Commits: [list of commit hashes]

Next: Wave [N+1] has [M] tasks
Continue? [Y/n]
```

If user confirms, proceed to next wave. If not, update state for resume later.

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
