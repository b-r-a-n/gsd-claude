---
name: gsd-progress
description: Show current GSD project status
---

# Show Progress

Display the current status of the GSD project.

## Workflow

### Step 1: Get Active Project

First, determine the active project:

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
```

If no active project is found:
```
No active GSD project found.

Run one of:
  /gsd:commands:new-project       Create a new project
  /gsd:commands:set-project <name> Switch to an existing project
  /gsd:commands:list-projects     See available projects
  /gsd:commands:discover-projects Find projects from commits
```

Set the planning directory based on active project:
```bash
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

### Step 2: Load State Files

Read from the project's planning directory:
1. `$PLANNING_DIR/STATE.md` - Current state
2. `$PLANNING_DIR/ROADMAP.md` - All phases
3. `$PLANNING_DIR/phases/*/PROGRESS.md` - Phase completion

### Step 3: Calculate Progress

For each phase:
- Count total tasks
- Count completed tasks
- Calculate percentage

Overall:
- Current phase
- Overall completion

### Step 4: Display Status

```
╔══════════════════════════════════════════════════════════════╗
║                      GSD Project Status                       ║
╠══════════════════════════════════════════════════════════════╣
║ Project: [project-name] (active)                             ║
║ Planning: ~/.claude/planning/projects/[project-name]/        ║
║ Current Phase: [N] - [Phase Name]                            ║
║ Status: [In Progress / Blocked / Verification Pending]       ║
╠══════════════════════════════════════════════════════════════╣
║ ROADMAP                                                       ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║ Phase 1: [Name]                    ████████████████████ 100%  ║
║   └─ [X/X tasks complete]                          ✓ Done    ║
║                                                               ║
║ Phase 2: [Name]                    ████████░░░░░░░░░░░░  40%  ║
║   └─ [4/10 tasks complete]                    ◉ Current      ║
║   └─ Wave 2, Task 2.3 in progress                            ║
║                                                               ║
║ Phase 3: [Name]                    ░░░░░░░░░░░░░░░░░░░░   0%  ║
║   └─ Not started                               ○ Pending     ║
║                                                               ║
╠══════════════════════════════════════════════════════════════╣
║ OVERALL PROGRESS                                              ║
╠══════════════════════════════════════════════════════════════╣
║                                                               ║
║ Tasks: [14/30] complete                                       ║
║ ███████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  47%  ║
║                                                               ║
╠══════════════════════════════════════════════════════════════╣
║ RECENT ACTIVITY                                               ║
╠══════════════════════════════════════════════════════════════╣
║ [2024-01-15 14:30] Task 2.2 completed                        ║
║ [2024-01-15 14:15] Task 2.1 completed                        ║
║ [2024-01-15 13:00] Phase 2 started                           ║
╚══════════════════════════════════════════════════════════════╝

Current task: Task 2.3 - [Title]
Files: [file1.ts, file2.ts]

Commits are tagged with: [project-name]

Commands:
  /gsd:commands:execute-phase    Continue execution
  /gsd:commands:pause-work       Save and pause
  /gsd:commands:verify-work      Verify phase 1
  /gsd:commands:set-project      Switch to another project
  /gsd:commands:list-projects    See all projects
```

### Simplified Output (for quick checks)

If state is simple or minimal data:

```
GSD Status: [project-name] (active)

Phase 2/3: [Phase Name]
Progress: 14/30 tasks (47%)
Current: Task 2.3 - [Title]
Status: In Progress
Commits tagged: [project-name]

Next: /gsd:commands:execute-phase to continue
```

### No Active Work

If project exists but no active phase:

```
GSD Status: [Project Name]

Phase 1/3: [Phase Name]
Status: Not started

Next: /gsd:commands:plan-phase 1 to create phase plan
```

## Progress Indicators

Use these symbols consistently:

| Symbol | Meaning |
|--------|---------|
| ✓ | Completed |
| ◉ | Current/Active |
| ○ | Pending |
| ⚠ | Blocked/Warning |
| ✗ | Failed |

Progress bars:
- `█` - Completed
- `░` - Remaining

## Guidelines

- Keep output concise but informative
- Show what's actionable
- Highlight blockers prominently
- Show recent activity for context
- Always suggest next command
