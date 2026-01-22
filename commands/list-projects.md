---
name: gsd-list-projects
description: List all registered GSD projects
---

# List Projects

Show all registered GSD projects and their status.

## Workflow

### Step 1: Check for Projects

Read `~/.claude/planning/projects/` directory. If empty or doesn't exist:

```
No GSD projects registered.

To create a new project: /gsd-new-project
To discover projects from commits: /gsd-discover-projects
```

### Step 2: Get Active Project

```bash
~/.claude/commands/gsd/scripts/project.sh get_active_project
```

This returns the currently active project (if any).

### Step 3: List Projects

```bash
~/.claude/commands/gsd/scripts/project.sh list_projects
```

For each project in `~/.claude/planning/projects/`, read its `project.yml` and display:

```
GSD Projects
============

* my-feature (active)
    Repository: /path/to/repo
    Status: active
    Created: 2024-01-15
    Last accessed: 2 hours ago
    Phase: 2/3 - Implementation

  other-project
    Repository: /path/to/other-repo
    Status: paused
    Created: 2024-01-10
    Last accessed: 3 days ago
    Phase: 1/2 - Planning

  archived-work
    Repository: /path/to/archived
    Status: completed
    Created: 2024-01-01
    Last accessed: 2 weeks ago
    Phase: Complete

Projects: 3 total (1 active, 1 paused, 1 completed)

Commands:
  /gsd-set-project <name>   Switch to a project
  /gsd-new-project          Create new project
  /gsd-discover-projects    Find projects from commits
```

### Step 4: Project Details

For each project, extract from `project.yml`:
- `name`: Project name
- `repository`: Repository path
- `status`: active/paused/completed
- `created`: Creation timestamp
- `last_accessed`: Last access timestamp (from last-active file)

And from the project's STATE.md (if exists):
- Current phase
- Current task status

### Display Format

Mark the active project with `*` prefix.

Show relative timestamps for accessibility:
- "2 hours ago"
- "yesterday"
- "3 days ago"
- "2 weeks ago"

## Guidelines

- Sort projects by last accessed (most recent first)
- Clearly mark the currently active project
- Show enough info to help user choose
- Include helpful commands at the bottom
