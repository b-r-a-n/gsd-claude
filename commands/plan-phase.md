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

### Step 0: Get Active Project

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_or_select_project)
```

Handle by exit code:

**Exit 0** - Project resolved (single, selected, or only one for repo):
```bash
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

**Exit 1** - Multiple projects, user selection needed:
- `$PROJECT` contains newline-separated list of available projects
- Use `AskUserQuestion` tool: "Which project would you like to plan?" with projects as options
- After selection, set and continue:
  ```bash
  ~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected>"
  PROJECT="<selected>"
  PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
  ```

**Exit 2** - No projects found:
```
No GSD projects found for this repository.

Run one of:
  /gsd:commands:new-project       Create a new project
  /gsd:commands:discover-projects Find projects from commits
```

### Step 1: Validate Planning Files Exist

Check that required planning files exist (but do not read them - the subagent will):

```bash
# Validate files exist
for file in PROJECT.md REQUIREMENTS.md ROADMAP.md; do
  if [[ ! -f "$PLANNING_DIR/$file" ]]; then
    echo "Missing: $file"
  fi
done
```

If any files are missing, inform the user and suggest running `/gsd:commands:new-project` first.

**IMPORTANT**: Do NOT read these files. The subagent will read them to preserve orchestrator context.

### Step 2: Delegate to Planner Subagent

Use the Task tool to spawn a Planner subagent that will do the heavy lifting:

```
Task tool parameters:
  description: "Plan phase [N] for [project-name]"
  subagent_type: "general-purpose"
  prompt: <use the Planner Subagent Prompt Template below>
```

#### Planner Subagent Prompt Template

Pass this prompt to the Task tool, replacing the placeholders:

```
# Planner Subagent: Phase [PHASE_NUMBER]

You are planning phase [PHASE_NUMBER] for the GSD project "[PROJECT_NAME]".

## Context

- **Planning Directory**: [PLANNING_DIR]
- **Phase Number**: [PHASE_NUMBER]

## Your Tasks

Execute ALL of the following steps autonomously. Do NOT return until complete.

### 1. Load Context

Read these files:
1. `[PLANNING_DIR]/PROJECT.md` - Goals and constraints
2. `[PLANNING_DIR]/REQUIREMENTS.md` - What needs to be built
3. `[PLANNING_DIR]/ROADMAP.md` - Phase overview

### 2. Identify Phase Scope

From ROADMAP.md, identify for Phase [PHASE_NUMBER]:
- Phase goal
- Deliverables for this phase
- Dependencies on previous phases
- Requirements addressed by this phase (map to REQ-xxx)

### 3. Design Tasks

Break the phase into atomic tasks following these criteria:
- Single responsibility
- Clear inputs and outputs
- Fits in fresh 200k context
- Has measurable acceptance criteria
- Specifies affected files

### 4. Organize by Dependencies

For each task, identify which tasks must complete first.
Tasks with no dependencies can run in parallel.
Group tasks into waves for documentation purposes.

### 5. Create Plan Files

Create `[PLANNING_DIR]/phases/phase-[NN]/PLAN.md` with:
- Phase goal
- Requirements addressed
- Prerequisites
- Context for executors
- Waves with tasks (each task has: Files, Action, Context, Acceptance)
- Dependency graph
- Verification criteria
- Rollback strategy
- Estimated task count

Task progress is tracked via the Task API. No separate progress file is needed.

### 6. Create Tasks via Task API

For EACH task in PLAN.md, call TaskCreate with rich metadata:

```
TaskCreate:
  subject: "[PROJECT_NAME] Phase [N] Task Y.Z: [Title]"
  description: |
    **Phase**: [N] - [Phase Title]
    **Wave**: [M]
    **Files**: [file1, file2]
    **Action**: [What to do]
    **Context**: [Key context for executor]
    **Acceptance**: [How to verify]
  activeForm: "[Title in present continuous form]"
  metadata:
    gsd_project: "[PROJECT_NAME]"
    gsd_planning_dir: "[PLANNING_DIR]"
    gsd_constraints: ["constraint 1", "constraint 2", "constraint 3"]
    gsd_phase: [N]
    gsd_phase_title: "[Phase Title]"
    gsd_phase_goal: "[What this phase achieves]"
    gsd_requirements: ["REQ-001", "REQ-002"]
    gsd_wave: [M]
    gsd_task_id: "Y.Z"
    gsd_files: ["file1", "file2"]
    gsd_action: "[What to do]"
    gsd_context: "[Key context snippet]"
    gsd_acceptance: "[acceptance criteria]"
    gsd_type: "task"
    gsd_commit_type: "feat|fix|refactor|docs|test|chore"
```

After creating all tasks, set up `blockedBy` relationships using TaskUpdate.

### 7. Update STATE.md

Append to `[PLANNING_DIR]/STATE.md`:
```markdown
## Current Status
- **Phase**: [N]
- **Task**: Not started
- **Status**: Planned

## History
- [YYYY-MM-DD HH:MM] Phase [N] planned
```

## Return Format

When complete, return ONLY this summary:

```
STATUS: success

PHASE: [N] - [Phase Title]
GOAL: [Brief phase goal]

TASKS_CREATED: [total count]
WAVES: [wave count]
  Wave 1: [N] tasks
  Wave 2: [N] tasks
  ...

REQUIREMENTS_ADDRESSED:
  - REQ-xxx: [Title]
  - REQ-yyy: [Title]

FILES_CREATED:
  - [PLANNING_DIR]/phases/phase-[NN]/PLAN.md

NOTES: [Any important notes or warnings]
```

If you encounter errors, return:

```
STATUS: error
REASON: [What went wrong]
SUGGESTION: [How to fix]
```
```

### Step 3: Display Results

When the subagent returns, display the summary to the user.

**For successful completion:**
```
Phase [N] Plan Created - Project: [project-name]

[Display GOAL from subagent]

Tasks: [TASKS_CREATED] tasks in [WAVES] waves
  [Wave breakdown from subagent]

Requirements addressed:
  [REQUIREMENTS_ADDRESSED from subagent]

Files created:
  [FILES_CREATED from subagent]

Note: Commits will be automatically tagged with [project-name]

[NOTES from subagent, if any]

Next: Run /gsd:commands:execute-phase to begin implementation
```

**For errors:**
```
Planning Failed

Error: [REASON from subagent]

Suggestion: [SUGGESTION from subagent]

Options:
1. Fix the issue and retry
2. Run planning manually
```

## Guidelines

- Keep tasks small enough for fresh context
- Be explicit about file paths
- Include enough context for executor to work independently
- Consider error cases in acceptance criteria
- Design for parallel execution where possible
- Always include rollback strategy
