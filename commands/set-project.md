---
name: gsd-set-project
description: Set the active GSD project
args: "<project-name>"
---

# Set Active Project

Switch to working on a different GSD project.

## Usage

The project name is provided as: $ARGUMENTS

## Workflow

### Step 1: Validate Project Exists

Check if the project is registered:

```bash
~/.claude/commands/gsd/scripts/project.sh project_exists "$ARGUMENTS"
```

If the project doesn't exist in `~/.claude/planning/projects/`, inform the user:

```
Project '[name]' is not registered.

To register it, run: /gsd-new-project [name]

Or to discover projects from commit history: /gsd-discover-projects
```

### Step 2: Set Active Project

```bash
~/.claude/commands/gsd/scripts/project.sh set_active_project "$ARGUMENTS"
```

This will:
1. Update `~/.claude/planning/.current-project` with the project name
2. Touch the project's `last-active` file for tracking

### Step 3: Display Confirmation

Show the project status:

```
Active project set: [project-name]

Project details:
  Repository: [repo path from project.yml]
  Status: [status from project.yml]
  Last accessed: [timestamp]

Planning directory: ~/.claude/planning/projects/[project-name]/

Available commands:
  /gsd-progress        Show project status
  /gsd-execute-phase   Continue execution
  /gsd-plan-phase      Plan next phase
```

### Step 4: Load Project State

Read the project's current state from:
- `~/.claude/planning/projects/[name]/STATE.md`
- `~/.claude/planning/projects/[name]/ROADMAP.md`

Display a brief summary of where work left off:

```
Current state:
  Phase: [N] - [Name]
  Task: [N.N] - [Title] (if in progress)
  Status: [status]
```

## Guidelines

- Always validate the project exists before switching
- Update the last-active timestamp when switching
- Show helpful next steps based on project state
- If project has paused sessions, mention them
