---
name: gsd-quick
description: Quick single-task execution without full planning
args: "<task_description>"
---

# Quick Task Execution

You are coordinating a quick task. Your role is to:
1. Understand the task
2. Delegate execution to a subagent
3. Report the results

**CRITICAL**: Do NOT read files, search code, or make changes yourself.
Delegate ALL execution to the subagent to preserve your context.

## Input

- **Task description**: $ARGUMENTS

## When to Use

Use `/gsd:commands:quick` for:
- Bug fixes
- Small features
- Refactoring
- Documentation updates
- Single-file changes
- Tasks that don't need multi-step planning

Use full GSD workflow (`/gsd:commands:new-project` → `/gsd:commands:plan-phase` → `/gsd:commands:execute-phase`) for:
- New features requiring multiple files
- Architectural changes
- Multi-day projects
- Work requiring coordination

## Workflow

### Step 1: Understand the Task

Parse the task description to understand what's being asked.
If the task is unclear, ask clarifying questions using AskUserQuestion.

**Do NOT:**
- Read any files
- Search the codebase
- Start implementing

### Step 2: Delegate to Subagent

Use the Task tool to spawn an executor subagent:

```
Task tool parameters:
  description: "Execute: <brief 3-5 word task summary>"
  subagent_type: "general-purpose"
  prompt: <use the subagent prompt template below, inserting the task description>
```

#### Subagent Prompt Template

Pass this prompt to the Task tool, replacing `<TASK_DESCRIPTION>` with the actual task from $ARGUMENTS:

```
# Quick Task Executor

You are executing a quick task autonomously. Complete it fully and return a summary.

## Task
<TASK_DESCRIPTION>

## Execution Steps

### 1. Research (if needed)
- Search for relevant files using Glob
- Read related code to understand patterns
- Keep research focused on what's needed

### 2. Plan
- Identify files to modify
- Plan the changes
- Define acceptance criteria

### 3. Implement
- Read the files you need to modify
- Make the changes using Edit or Write
- Keep changes minimal and focused

### 4. Verify
- Ensure changes work as expected
- Check acceptance criteria

### 5. Commit
Use these VCS commands:

# Check what changed
~/.claude/commands/gsd/scripts/vcs.sh vcs-status

# Stage files (only files you intentionally changed)
~/.claude/commands/gsd/scripts/vcs.sh vcs-stage <file>

# Verify staged changes
~/.claude/commands/gsd/scripts/vcs.sh vcs-diff-staged

# Commit
~/.claude/commands/gsd/scripts/vcs.sh vcs-commit "<type>: <description>"

Commit types: feat, fix, refactor, docs, test, chore

## Return Format

When done, return ONLY this summary (the orchestrator will display it):

STATUS: [success|error|too-complex]

FILES_CHANGED:
- <file1>: <what changed>
- <file2>: <what changed>

COMMIT: <hash> - <message>

NOTES: <any relevant notes or follow-up suggestions>

If the task is too complex for quick execution, return:

STATUS: too-complex

REASON: <why this needs full GSD workflow>

SUGGESTION: Use /gsd:commands:new-project to plan this properly

## Guidelines
- Keep it simple - this is for quick tasks
- Follow existing code patterns
- Don't over-engineer
- If uncertain, make reasonable assumptions rather than blocking
```

### Step 3: Report Results

When the subagent returns, display its summary to the user.

**For successful completion:**
```
✓ Task Complete

Changes:
  [from FILES_CHANGED in subagent summary]

Commit: [from COMMIT in subagent summary]

[NOTES from subagent summary, if any]
```

**For errors:** See Error Handling section below.

## Error Handling

### STATUS: error

If the subagent returns an error:

```
⚠ Task Failed

Error: [from subagent summary]

Options:
1. Retry with more context
2. Use full GSD workflow for better planning
3. Investigate manually
```

Ask the user which option they prefer.

### STATUS: too-complex

If the subagent determines the task is too complex:

```
⚠ Task Too Complex for Quick Execution

Reason: [from REASON in subagent summary]

Recommendation: [from SUGGESTION in subagent summary]

Would you like to:
1. Start a new GSD project with /gsd:commands:new-project
2. Try anyway with quick execution (may fail)
3. Break down the task into smaller pieces
```

Ask the user which option they prefer.

## Examples

### Example 1: Bug Fix
```
User: /gsd:commands:quick fix the null pointer in user.ts line 42

Orchestrator:
1. Understands: fix null pointer bug in user.ts
2. Delegates to subagent with Task tool
3. Subagent returns:
   STATUS: success
   FILES_CHANGED:
   - user.ts: added null check on line 42
   COMMIT: abc123 - fix: add null check in user.ts
   NOTES: Consider adding similar checks elsewhere
4. Reports to user:
   ✓ Task Complete
   Changes: user.ts - added null check on line 42
   Commit: abc123 - fix: add null check in user.ts
```

### Example 2: Add Function
```
User: /gsd:commands:quick add a formatDate utility function to utils.ts

Orchestrator:
1. Understands: add formatDate function to utils.ts
2. Delegates to subagent with Task tool
3. Subagent returns:
   STATUS: success
   FILES_CHANGED:
   - utils.ts: added formatDate(date, format) function
   COMMIT: def456 - feat: add formatDate utility function
   NOTES: none
4. Reports to user:
   ✓ Task Complete
   Changes: utils.ts - added formatDate(date, format) function
   Commit: def456 - feat: add formatDate utility function
```

### Example 3: Too Complex Task
```
User: /gsd:commands:quick rewrite the entire authentication system

Orchestrator:
1. Understands: rewrite authentication system (large scope)
2. Delegates to subagent with Task tool
3. Subagent returns:
   STATUS: too-complex
   REASON: Authentication rewrite affects 15+ files and requires architectural decisions
   SUGGESTION: Use /gsd:commands:new-project to plan this properly
4. Reports to user:
   ⚠ Task Too Complex for Quick Execution
   Reason: Authentication rewrite affects 15+ files...
   Recommendation: Use /gsd:commands:new-project
```

## Guidelines

- Keep it simple - this is for quick tasks
- Don't over-engineer
- Follow existing code patterns
- Commit with clear messages
- If the task is too big, suggest using full GSD workflow
- If uncertain about scope, ask before delegating
- **Remember: Do NOT read files yourself - always delegate**
