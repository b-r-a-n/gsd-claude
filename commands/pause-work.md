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
```

Set the planning directory based on active project:
```bash
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

### Step 1: Capture Current State

Gather information about current work:

1. **Current phase and task** from `$PLANNING_DIR/STATE.md`
2. **Work in progress** - any uncommitted changes
3. **Pending decisions** - things waiting for input
4. **Next steps** - what should happen when resuming

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
2. Check out branch: [branch]
3. Review uncommitted changes (if any)
4. Continue with: [specific next action]

---
Session ID: [timestamp]
Project: [project-name]
```

### Step 4: Update STATE.md

Update `$PLANNING_DIR/STATE.md` with pause information:

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

## Guidelines

- Always warn about uncommitted changes
- Capture enough context to resume cold
- Include specific next steps
- Note any blockers or pending decisions
- Keep session files for history/reference
