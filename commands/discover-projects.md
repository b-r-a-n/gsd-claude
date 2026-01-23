---
name: gsd-discover-projects
description: Discover GSD projects from commit history
---

# Discover Projects

Scan git commit history for [project-name] tags and offer to register them.

## Workflow

### Step 1: Scan Commit History

```bash
~/.claude/commands/gsd/scripts/project.sh discover_projects_from_commits
```

This runs:
```bash
git log --oneline -200 | grep -o '\[[^]]*\]' | tr -d '[]' | sort -u
```

If no projects found:
```
No project tags found in recent commit history.

Project tags look like: [project-name] in commit messages
Example: "[my-feature] feat(phase1-task1): Add new component"

To create a new project: /gsd:commands:new-project
```

### Step 2: Check Registration Status

For each discovered tag, check if already registered:

```bash
~/.claude/commands/gsd/scripts/project.sh project_exists "<tag>"
```

### Step 3: Display Discovered Projects

```
Discovered Project Tags
=======================

Found in recent 200 commits:

  [my-feature]
    Commits: 23
    Status: REGISTERED
    Last commit: 2 hours ago

  [api-refactor]
    Commits: 15
    Status: NOT REGISTERED
    Last commit: 3 days ago

  [bugfix-auth]
    Commits: 5
    Status: NOT REGISTERED
    Last commit: 1 week ago

Summary: 3 project tags found (1 registered, 2 unregistered)
```

### Step 4: Offer Registration

For unregistered projects:

```
Would you like to register the unregistered projects?

Unregistered projects:
  1. api-refactor (15 commits)
  2. bugfix-auth (5 commits)

Options:
  - Enter numbers to register (e.g., "1 2" or "all")
  - Enter "skip" to skip registration
  - Enter project name to register a specific one

Your choice:
```

### Step 5: Register Selected Projects

For each project to register:

```bash
~/.claude/commands/gsd/scripts/project.sh register_project "<name>" "Discovered from commit history"
```

Create the project directory structure:
- `~/.claude/planning/projects/<name>/project.yml`
- `~/.claude/planning/projects/<name>/last-active`

### Step 6: Confirmation

```
Registered Projects
===================

  api-refactor
    ID: a1b2c3d4e5f6
    Directory: ~/.claude/planning/projects/api-refactor/

  bugfix-auth
    ID: f6e5d4c3b2a1
    Directory: ~/.claude/planning/projects/bugfix-auth/

Projects are registered but need setup. For each project:
  1. Run /gsd:commands:set-project <name> to switch to it
  2. Create PROJECT.md, REQUIREMENTS.md, ROADMAP.md manually
     or run /gsd:commands:new-project to set up from scratch

Commands:
  /gsd:commands:set-project <name>   Switch to a project
  /gsd:commands:list-projects        Show all projects
```

## Commit Tag Analysis

When analyzing commits, gather:
- Total commit count per tag
- Date of most recent commit
- Types of commits (feat, fix, refactor, etc.)

This helps the user understand the scope of each discovered project.

## Guidelines

- Only scan recent history (200 commits) to keep it fast
- Clearly distinguish registered vs unregistered
- Show commit counts to indicate project size/activity
- Make registration optional and non-destructive
- Registered projects need manual setup of planning docs
