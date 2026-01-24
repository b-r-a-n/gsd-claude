---
name: gsd-pause-work
description: Save current session state for later resumption
args: "[note]"
---

# Pause Work

Save the current work session state so it can be resumed later.

## Input

- **Note**: $ARGUMENTS (optional - note about why pausing or what to do next)

## Purpose

When you need to stop working on a GSD project:
- End of day
- Context switch to another task
- Waiting for input/feedback
- Taking a break

This command captures the current state so you can resume seamlessly.

## Workflow

### Step 0: Get Active Project

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_or_select_project)
```

Handle by exit code:

**Exit 0** - Project found, proceed:
```bash
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

**Exit 1** - Multiple projects, user selection needed:
- `$PROJECT` contains the list of available projects (one per line)
- Use `AskUserQuestion` tool: "Which project would you like to pause?"
- After selection, persist and continue:
  ```bash
  ~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected>"
  PROJECT="<selected>"
  PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
  ```

**Exit 2** - No projects found:
```
No GSD projects found for this repository. Nothing to pause.

Run /gsd:commands:new-project to create a project first.
```

### Step 1: Capture Current State

Gather information about current work from the Task API:

**Query TaskList for current work:**
```
TaskList -> filter by:
  - metadata.gsd_project == current_project
```

Extract only:
1. **in_progress_task_ids** - List of Task API IDs for tasks with status == "in_progress"
2. **phase_number** - From metadata.gsd_phase of in_progress tasks
3. **progress_counts** - X/Y format (completed tasks / total tasks)

Additional context to capture:
4. **Work in progress** - any uncommitted changes (via VCS)
5. **Pending decisions** - things waiting for input
6. **Next steps** - what should happen when resuming

**Note:** Do NOT capture task subject, description, metadata, or blockedBy. The Task API is the source of truth for task details.

### Step 2: Check for Uncommitted Work

```bash
~/.claude/commands/gsd/scripts/vcs.sh vcs-status
```

If there are uncommitted changes:
- Warn the user
- Ask if they want to:
  1. Commit the changes now
  2. Stash/shelve them
  3. Leave them uncommitted

### Step 3: Create Session Snapshot

Generate a unique session filename with seconds and random suffix to prevent collisions (FR-009):
```bash
# Generate unique session ID: YYYYMMDD-HHMMSS-XXXX (XXXX = 4 random hex chars)
SESSION_ID=$(date +%Y-%m-%d-%H%M%S)-$(head -c 2 /dev/urandom | xxd -p)
```

Create `$PLANNING_DIR/sessions/session-${SESSION_ID}.md`:

```markdown
# Session Snapshot

**Project**: [project-name]
**Paused**: [YYYY-MM-DD HH:MM]
**Branch**: [current branch]
**Revision**: [current commit hash]

## State at Pause

### Current Work
- **Phase**: [N] - [Name]
- **Wave**: [N]
- **Task**: [N.N] - [Title]
- **Status**: [In Progress / Blocked / etc.]

### Progress Summary
- Phase [N]: [X/Y] tasks complete
- Current wave: [X/Y] tasks complete

### Task API References

Store only task IDs for reference (full data available via TaskList/TaskGet):

- **In-progress task IDs**: [list from TaskList query]
- **Phase number**: [current phase]
- **Progress**: [X/Y] tasks complete

**Note**: Tasks are NOT stored in session files. The Task API is the source of truth.

### Uncommitted Changes
[List of modified files, or "None"]

### Pending Decisions
- [Decision 1 needed]
- [Decision 2 needed]

## Context for Resume

### What was being worked on
[Description of the current task and what's been done]

### What was about to happen
[Next steps that were planned]

### Open questions
[Any questions that need answers]

### Important notes
[User's note if provided: $ARGUMENTS]

## Resume Instructions

When resuming this session:
1. Run: /gsd:commands:set-project [project-name]
2. Run: /gsd:commands:resume-work (queries Task API for current state)
3. Check out branch: [branch]
4. Review uncommitted changes (if any)
5. Continue with: [specific next action]

---
Session ID: [timestamp]
Project: [project-name]
```

### Step 4: Update STATE.md (Audit Trail)

Update `$PLANNING_DIR/STATE.md` with pause information (write-only, for audit trail):

```markdown
## Current Status
- **Phase**: [N]
- **Task**: [N.N]
- **Status**: Paused

## Session
- **Paused at**: [YYYY-MM-DD HH:MM]
- **Session file**: sessions/session-${SESSION_ID}.md
- **Note**: [user's note]

## History
- [YYYY-MM-DD HH:MM] Work paused: [reason]
```

**Note:** This is a write-only update for audit purposes. The session snapshot file contains the complete state for recovery.

### Step 5: Report

```
Session Paused - Project: [project-name]

State saved to: $PLANNING_DIR/sessions/session-[timestamp].md

Current state:
  Phase: [N] - [Name]
  Task: [N.N] - [Title]
  Progress: [X/Y] tasks complete

[If uncommitted changes]
Uncommitted changes:
  - [file1]
  - [file2]

Note: [user's note or "No note provided"]

To resume this project: /gsd:commands:resume-work
To switch projects: /gsd:commands:set-project <name>
To list all projects: /gsd:commands:list-projects
```

## Quick Pause vs Detailed Pause

**Quick pause** (no note):
- Captures minimal state
- Good for short breaks

**Detailed pause** (with note):
- Captures full context
- Good for end of day or longer breaks
- Include the note in the session file

## Backward Compatibility

Session files created before this change may contain full task snapshots (JSON).
These can still be resumed - the Task Snapshot section will be ignored.
Task state is always retrieved from the Task API, not from session files.

## Guidelines

- Always warn about uncommitted changes
- Capture enough context to resume cold
- Include specific next steps
- Note any blockers or pending decisions
- Keep session files for history/reference
