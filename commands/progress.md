---
name: gsd-progress
description: Show current GSD project status
---

# Show Progress

Display the current status of the GSD project.

## Workflow

### Step 0: Get Active Project

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_or_select_project)
case $? in
  0) PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT" ;;
  1) # $PROJECT contains newline-separated list of available projects
     # Use AskUserQuestion tool to prompt: "Which project?" with options from $PROJECT
     # After selection, run: ~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected>"
     # Then re-run get_or_select_project ;;
  2) # No projects found
     echo "No GSD projects found. Run /gsd:commands:new-project or /gsd:commands:discover-projects" ;;
esac
```

### Step 2: Load State (Task API Only)

**Query Task API:**

```
TaskList
```

Filter tasks by metadata:
- `gsd_project` matches current project
- Group by `gsd_phase` for per-phase counts
- Count by status: pending, in_progress, completed

**No tasks found:**
If TaskList returns no tasks for the current project, display:
```
No progress data available (new session or tasks not loaded).

Run:
  /gsd:commands:resume-work     Restore tasks from session snapshot
  /gsd:commands:plan-phase [N]  Create tasks for a phase
```

### Step 3: Calculate Progress

**From Task API:**
```
For each phase in grouped tasks:
  total = count(tasks where gsd_phase == phase)
  completed = count(tasks where gsd_phase == phase AND status == "completed")
  in_progress = count(tasks where gsd_phase == phase AND status == "in_progress")
  percentage = (completed / total) * 100
```

Overall:
- Current phase (phase with in_progress tasks, or highest incomplete phase)
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

Data source: Task API (real-time)
```

### Task API Progress Display

When using Task API data, show current task details:

```
Current Task: Task 2.3 - [Title]
  Status: in_progress
  Files: [file1.ts, file2.ts]
  Started: 2024-01-15 14:30

Pending in Phase 2:
  - Task 2.4: [Title] (blocked by 2.3)
  - Task 2.5: [Title] (blocked by 2.3, 2.4)
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
