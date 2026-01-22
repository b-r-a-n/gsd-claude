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

First, determine the active project:

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
```

If no active project is found:
```
No active GSD project found.

Run one of:
  /gsd-new-project       Create a new project
  /gsd-set-project <name> Switch to an existing project
  /gsd-list-projects     See available projects
```

Set the planning directory based on active project:
```bash
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

### Step 1: Load Context

Read these files from the project's planning directory to understand the project:
1. `$PLANNING_DIR/PROJECT.md` - Goals and constraints
2. `$PLANNING_DIR/REQUIREMENTS.md` - What needs to be built
3. `$PLANNING_DIR/ROADMAP.md` - Phase overview
4. `$PLANNING_DIR/STATE.md` - Current state

If any files are missing, inform the user and suggest running `/gsd-new-project` first.

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

### Step 4: Organize into Waves

Group tasks by dependencies:
- **Wave 1**: Independent tasks (can run in parallel)
- **Wave 2**: Tasks depending on Wave 1
- **Wave 3**: Tasks depending on Wave 2
- etc.

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

Next: Run /gsd-execute-phase to begin implementation
```

## Guidelines

- Keep tasks small enough for fresh context
- Be explicit about file paths
- Include enough context for executor to work independently
- Consider error cases in acceptance criteria
- Design for parallel execution where possible
- Always include rollback strategy
