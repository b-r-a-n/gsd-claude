---
name: gsd-resume-work
description: Continue from a paused session
args: "[session_id]"
---

# Resume Work

Continue working from a previously paused session.

## Input

- **Session ID**: $ARGUMENTS (optional - specific session to resume, defaults to most recent)

## Workflow

### Step 0: Get Active Project (with Ambiguity Handling)

First, check project status for this repository:

```bash
AMBIGUITY=$("~/.claude/commands/gsd/scripts/project.sh" check_project_ambiguity 2>/tmp/gsd-projects)
```

Handle each case:

**Case: "none"** - No projects for this repo:
```
No GSD projects found for this repository. Nothing to resume.

Run /gsd:commands:new-project to create a project first.
```

**Case: "single" or "selected"** - Proceed normally:
```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

**Case: "ambiguous"** - Multiple projects, no explicit selection:
1. Read the project list from `/tmp/gsd-projects` (one project per line)
2. Use the `AskUserQuestion` tool to prompt the user:
   - Question: "Which project would you like to resume?"
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

### Step 1: Find Session

If no session ID provided, find the most recent for this project:

```bash
# Pattern matches both old format (session-YYYY-MM-DD-HHMM.md) and
# new format (session-YYYY-MM-DD-HHMMSS-XXXX.md) per FR-009
ls -t "$PLANNING_DIR/sessions/session-"*.md 2>/dev/null | head -1
```

If session ID provided, look for matching file (supports partial match).

If no sessions found:
```
No paused sessions found for project: [project-name]

Check $PLANNING_DIR/STATE.md for current state, or run:
  /gsd:commands:progress      - See project status
  /gsd:commands:execute-phase - Continue execution
  /gsd:commands:list-projects - Switch to another project
```

### Step 2: Load Session

Read the session snapshot file and extract:
- Phase and task that was in progress
- Uncommitted changes (if any)
- Pending decisions
- Context and next steps

### Step 3: Verify State

Check current state matches expected:

```bash
# Check branch
~/.claude/commands/gsd/scripts/vcs.sh vcs-branch

# Check for uncommitted changes
~/.claude/commands/gsd/scripts/vcs.sh vcs-status

# Check current revision
~/.claude/commands/gsd/scripts/vcs.sh vcs-current-rev
```

Report any discrepancies:
```
⚠ State has changed since pause:
  - Branch was 'feature-x', now 'main'
  - Expected revision abc123, now def456
  - New uncommitted changes detected

Continue anyway? [y/N]
```

### Step 4: Display Resume Context

```
╔══════════════════════════════════════════════════════════════╗
║                     Resuming GSD Session                      ║
╠══════════════════════════════════════════════════════════════╣
║ Project: [project-name]                                      ║
║ Session: [session-ID]                                        ║
║ Paused:  [YYYY-MM-DD HH:MM] ([X hours/days] ago)            ║
╠══════════════════════════════════════════════════════════════╣
║ STATE AT PAUSE                                                ║
╠══════════════════════════════════════════════════════════════╣
║ Phase: [N] - [Name]                                          ║
║ Task:  [N.N] - [Title]                                       ║
║ Progress: [X/Y] tasks in phase complete                      ║
╠══════════════════════════════════════════════════════════════╣
║ CONTEXT                                                       ║
╠══════════════════════════════════════════════════════════════╣
║ [What was being worked on]                                    ║
║                                                               ║
║ Next steps:                                                   ║
║ • [Step 1]                                                    ║
║ • [Step 2]                                                    ║
╠══════════════════════════════════════════════════════════════╣
║ [If there was a note]                                         ║
║ NOTE: [User's note from pause]                               ║
╠══════════════════════════════════════════════════════════════╣
║ PENDING DECISIONS                                             ║
╠══════════════════════════════════════════════════════════════╣
║ • [Decision 1 needed]                                         ║
║ • [Decision 2 needed]                                         ║
╚══════════════════════════════════════════════════════════════╝
```

### Step 5: Handle Uncommitted Changes

If there were uncommitted changes at pause:

```
⚠ Uncommitted changes from previous session:
  - [file1.ts] (modified)
  - [file2.ts] (modified)

These changes are still present. Options:
1. Continue with changes as-is
2. Review changes before continuing
3. Discard changes and start fresh

Choice [1]:
```

### Step 6: Update State

Update `$PLANNING_DIR/STATE.md`:

```markdown
## Current Status
- **Phase**: [N]
- **Task**: [N.N]
- **Status**: In Progress (resumed)

## Session
- **Resumed at**: [YYYY-MM-DD HH:MM]
- **Resumed from**: sessions/session-${SESSION_ID}.md

## History
- [YYYY-MM-DD HH:MM] Work resumed from session-${SESSION_ID}
```

Also touch the project's last-active file to update access time:
```bash
touch "$PLANNING_DIR/last-active"
```

### Step 6.5: Session File Cleanup

After successfully resuming, offer to clean up the session file.

```
Session file: sessions/session-${SESSION_ID}.md

Options:
1. Keep session file (for history/reference)
2. Delete session file (clean up)

Choice [1]:
```

**If user chooses to keep (default)**:
- Mark the session as resumed by appending to the file:
  ```markdown
  ---
  **Status**: Resumed on [YYYY-MM-DD HH:MM]
  ```
- This distinguishes it from orphaned sessions that were never resumed

**If user chooses to delete**:
```bash
rm "$PLANNING_DIR/sessions/session-${SESSION_ID}.md"
```

Log the action in STATE.md history:
```markdown
- [YYYY-MM-DD HH:MM] Session file session-${SESSION_ID}.md [kept/deleted]
```

**Tip**: To clean up old session files across all projects, use:
```bash
~/.claude/commands/gsd/scripts/session-gc.sh list_stale_sessions 7
~/.claude/commands/gsd/scripts/session-gc.sh clean_stale_sessions 7
```

### Step 7: Ready to Continue

```
Session Resumed - Project: [project-name]

Ready to continue:
  Phase [N], Task [N.N]: [Title]

Files to work with:
  - [file1.ts]
  - [file2.ts]

Commits will be tagged with: [project-name]

Run /gsd:commands:execute-phase to continue execution
```

## Session Selection

If multiple sessions exist, user can:
1. Resume most recent (default)
2. Specify session ID
3. List available sessions

```
Available sessions:
  1. session-2024-01-15-143022-a1b2 (2 hours ago) - Phase 2, Task 2.3
  2. session-2024-01-14-170015-c3d4 (yesterday) - Phase 2, Task 2.1
  3. session-2024-01-10-090030-e5f6 (5 days ago) - Phase 1, Task 1.5

Resume which session? [1]:
```

## Guidelines

- Always verify state before resuming
- Warn about any discrepancies
- Show enough context to resume effectively
- Handle edge cases (missing files, state changes)
- Keep session history for reference
