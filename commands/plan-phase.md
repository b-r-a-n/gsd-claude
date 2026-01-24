---
name: gsd-plan-phase
description: Create an executable plan for a project phase
args: "[phase_number]"
---

# Plan Phase

You are creating an executable plan for a GSD project phase.

## Input

- **Phase number**: $ARGUMENTS (default: current phase from STATE.md, or 1 if not set)

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
   - Question: "Which project would you like to plan?"
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

### Step 1: Load Context

Read these files from the project's planning directory to understand the project:
1. `$PLANNING_DIR/PROJECT.md` - Goals and constraints
2. `$PLANNING_DIR/REQUIREMENTS.md` - What needs to be built
3. `$PLANNING_DIR/ROADMAP.md` - Phase overview

If any files are missing, inform the user and suggest running `/gsd:commands:new-project` first.

**Note:** STATE.md is write-only (for audit trail). Do not read from STATE.md for current state.

### Step 2: Identify Phase Scope

From ROADMAP.md, identify:
- Phase goal
- Deliverables for this phase
- Dependencies on previous phases
- Requirements addressed by this phase (map to REQ-xxx)

### Step 3: Design Tasks

Break the phase into atomic tasks:

**Task Criteria:**
- Single responsibility
- Clear inputs and outputs
- Fits in fresh 200k context
- Has measurable acceptance criteria
- Specifies affected files

**Task Template:**
```markdown
#### Task X.Y: [Title]
- **Files**: [file1.ts, file2.ts]
- **Action**: [Specific action to take]
- **Context**: [What executor needs to know]
- **Acceptance**: [How to verify completion]
```

### Step 4: Organize by Dependencies

Identify task dependencies and group for documentation:

**Dependency Analysis:**
- For each task, identify which tasks must complete first
- Tasks with no dependencies can run in parallel
- Express dependencies explicitly (e.g., "Task 2.1 depends on 1.1, 1.2")

**Wave Grouping (for documentation):**
Waves are still documented in PLAN.md for human readability:
- **Wave 1**: Tasks with no dependencies (can run in parallel)
- **Wave 2**: Tasks depending only on Wave 1 tasks
- **Wave 3**: Tasks depending on Wave 2 tasks
- etc.

**Dependency Graph:**
Include a visual dependency graph in PLAN.md:
```
1.1 ──┬──> 2.1 ──> 3.1
1.2 ──┘
```

**Note**: Actual execution uses Task API `blockedBy` relationships, not rigid wave boundaries.

### Step 5: Create Plan File

Create `$PLANNING_DIR/phases/phase-XX/PLAN.md`:

```markdown
# Phase [N]: [Title]

## Goal
[Clear statement of what this phase achieves]

## Requirements Addressed
- REQ-001: [Title]
- REQ-002: [Title]

## Prerequisites
- [What must be true before starting]
- [Dependencies on previous phases]

## Context for Executors
[Key information any executor needs to know - architecture, patterns, constraints]

## Waves

### Wave 1: [Description]
[Tasks that can be executed in parallel]

#### Task 1.1: [Title]
- **Files**: [list]
- **Action**: [what to do]
- **Context**: [what to know]
- **Acceptance**: [how to verify]

#### Task 1.2: [Title]
...

### Wave 2: [Description]
[Depends on Wave 1]

#### Task 2.1: [Title]
...

## Verification
[How to verify the entire phase is complete]

## Rollback Strategy
[How to undo changes if something goes wrong]

## Estimated Tasks
- Total tasks: [N]
- Waves: [N]
```

Also create `$PLANNING_DIR/phases/phase-XX/PROGRESS.md`:

```markdown
# Phase [N] Progress

## Status: Not Started

## Tasks

### Wave 1
- [ ] Task 1.1: [Title]
- [ ] Task 1.2: [Title]

### Wave 2
- [ ] Task 2.1: [Title]

## Log
[YYYY-MM-DD HH:MM] Plan created
```

### Step 5.5: Create Tasks via Task API

After creating the plan files, register each task with Claude's Task API for real-time tracking:

**For each task in PLAN.md:**

```
TaskCreate:
  subject: "[project-name] Phase X Task Y.Z: [Title]"
  description: |
    **Phase**: [N] - [Phase Title]
    **Wave**: [M]
    **Files**: [file1.ts, file2.ts]
    **Action**: [What to do]
    **Context**: [Key context for executor]
    **Acceptance**: [How to verify]
  activeForm: "[Title in present continuous form]"
  metadata:
    # Project context (reduces need to read PROJECT.md)
    gsd_project: "[project-name]"
    gsd_planning_dir: "[path to planning directory]"
    gsd_constraints: ["constraint 1", "constraint 2", "constraint 3"]  # Top 3-5 constraints

    # Phase context (reduces need to read PLAN.md header)
    gsd_phase: [N]
    gsd_phase_title: "[Phase Title]"
    gsd_phase_goal: "[What this phase achieves]"
    gsd_requirements: ["REQ-001", "REQ-002"]  # Requirement IDs addressed

    # Task context (complete task specification)
    gsd_wave: [M]
    gsd_task_id: "Y.Z"
    gsd_files: ["file1.ts", "file2.ts"]
    gsd_action: "[What to do]"
    gsd_context: "[Key context snippet]"
    gsd_acceptance: "[acceptance criteria]"
    gsd_type: "task"

    # VCS context
    gsd_commit_type: "feat"  # feat, fix, refactor, docs, test, chore
```

**Rich Metadata Benefits:**
- Executor can use `TaskGet(taskId)` to retrieve complete context
- No need to read PLAN.md, PROJECT.md for routine tasks
- Only source files listed in `gsd_files` need to be read
- REQUIREMENTS.md consulted only for deep reference

**PLAN.md is documentation only:**
With rich metadata, PLAN.md becomes documentation rather than a required data source.
Keep PLAN.md for:
- Human-readable phase overview
- Git-visible planning history
- Detailed rationale and context not in metadata

**Example:**
```
TaskCreate:
  subject: "[my-app] Phase 1 Task 1.1: Add user authentication"
  description: |
    **Phase**: 1 - Core Features
    **Wave**: 1
    **Files**: src/auth.ts, src/middleware/auth.ts
    **Action**: Implement JWT-based authentication
    **Context**: Use existing User model, integrate with Express middleware
    **Acceptance**: Login endpoint returns valid JWT, protected routes reject invalid tokens
  activeForm: "Adding user authentication"
  metadata:
    # Project context
    gsd_project: "my-app"
    gsd_planning_dir: "~/.claude/planning/projects/my-app"
    gsd_constraints: ["TypeScript only", "No external auth services", "JWT tokens expire in 1h"]

    # Phase context
    gsd_phase: 1
    gsd_phase_title: "Core Features"
    gsd_phase_goal: "Implement authentication and basic user management"
    gsd_requirements: ["REQ-001", "REQ-002"]

    # Task context
    gsd_wave: 1
    gsd_task_id: "1.1"
    gsd_files: ["src/auth.ts", "src/middleware/auth.ts"]
    gsd_action: "Implement JWT-based authentication"
    gsd_context: "Use existing User model from src/models/user.ts, integrate with Express middleware pattern"
    gsd_acceptance: "Login endpoint returns valid JWT, protected routes reject invalid tokens"
    gsd_type: "task"

    # VCS context
    gsd_commit_type: "feat"
```

**Step 5.5.2: Set Up Dependencies**

After creating all tasks, establish `blockedBy` relationships based on the dependency analysis from Step 4:

```
# Map task IDs to Claude Task API IDs
task_id_map = {}
for each task:
  result = TaskCreate(...)
  task_id_map[task.gsd_task_id] = result.taskId

# Set up blockedBy relationships
for each task with dependencies:
  dependency_ids = [task_id_map[dep] for dep in task.dependencies]
  TaskUpdate:
    taskId: task_id_map[task.gsd_task_id]
    addBlockedBy: dependency_ids
```

**Example with Dependencies:**
```
# Create tasks first
TaskCreate(1.1: "Add auth") -> task_id_1_1
TaskCreate(1.2: "Add database") -> task_id_1_2
TaskCreate(2.1: "Add user API") -> task_id_2_1

# Then set up dependencies
TaskUpdate:
  taskId: task_id_2_1
  addBlockedBy: [task_id_1_1, task_id_1_2]  # 2.1 blocked by 1.1 and 1.2
```

**Note**: Tasks created via the Task API provide real-time progress tracking through `TaskList` and `TaskUpdate`. The PROGRESS.md file is still created for audit trail and git-visible history.

### Step 6: Update State

Update `$PLANNING_DIR/STATE.md`:

```markdown
## Current Status
- **Phase**: [N]
- **Task**: Not started
- **Status**: Planned

## History
- [YYYY-MM-DD HH:MM] Phase [N] planned
```

### Step 7: Summary

Report to user:

```
Phase [N] Plan Created - Project: [project-name]

Goal: [phase goal]

Tasks: [N] tasks in [M] waves
  Wave 1: [N] tasks (parallel)
  Wave 2: [N] tasks
  ...

Files created:
  $PLANNING_DIR/phases/phase-XX/PLAN.md
  $PLANNING_DIR/phases/phase-XX/PROGRESS.md

Note: Commits will be automatically tagged with [project-name]

Next: Run /gsd:commands:execute-phase to begin implementation
```

## Guidelines

- Keep tasks small enough for fresh context
- Be explicit about file paths
- Include enough context for executor to work independently
- Consider error cases in acceptance criteria
- Design for parallel execution where possible
- Always include rollback strategy
