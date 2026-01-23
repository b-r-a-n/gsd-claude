---
name: gsd-quick
description: Quick single-task execution without full planning
args: "<task_description>"
---

# Quick Task Execution

You are executing a single task quickly without the full GSD planning workflow. This is for small, well-defined tasks that don't need multi-phase planning.

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

Parse the task description to understand:
- What needs to be done
- What files are likely involved
- What the acceptance criteria are

If the task is unclear, ask clarifying questions.

### Step 2: Research (if needed)

If you need to understand the codebase:
1. Search for relevant files
2. Read related code
3. Identify patterns to follow

### Step 3: Plan Briefly

Create a mental plan:
- What files to modify
- What changes to make
- How to verify

For simple tasks, this can be just a few bullet points. Don't over-plan.

### Step 4: Execute

Implement the changes:
1. Read the relevant files
2. Make the changes
3. Verify the changes work

### Step 5: Commit

Use the VCS abstraction to commit:

```bash
# Check what changed
~/.claude/commands/gsd/scripts/vcs.sh vcs-status

# Stage files
~/.claude/commands/gsd/scripts/vcs.sh vcs-stage <file>

# Commit with descriptive message
~/.claude/commands/gsd/scripts/vcs.sh vcs-commit "<type>: <description>"
```

Commit message format for quick tasks:
```
<type>: <description>

[optional body with more detail]
```

Types:
- `feat` - New feature
- `fix` - Bug fix
- `refactor` - Refactoring
- `docs` - Documentation
- `test` - Tests
- `chore` - Maintenance

### Step 6: Report

```
✓ Task Complete

Changes:
  [file1]: [what changed]
  [file2]: [what changed]

Commit: [hash] - [message]

[Any notes or follow-up suggestions]
```

## Examples

### Example 1: Bug Fix
```
User: /gsd:commands:quick fix the null pointer in user.ts line 42

Claude:
1. Reads user.ts
2. Identifies the null pointer issue
3. Adds null check
4. Commits: "fix: add null check in user.ts"
```

### Example 2: Add Function
```
User: /gsd:commands:quick add a formatDate utility function to utils.ts

Claude:
1. Reads utils.ts to understand patterns
2. Adds formatDate function following existing style
3. Commits: "feat: add formatDate utility function"
```

### Example 3: Documentation
```
User: /gsd:commands:quick update README with new installation steps

Claude:
1. Reads README.md
2. Updates installation section
3. Commits: "docs: update installation steps in README"
```

## Guidelines

- Keep it simple - this is for quick tasks
- Don't over-engineer
- Follow existing code patterns
- Commit with clear messages
- If the task is too big, suggest using full GSD workflow
- If uncertain about scope, ask before implementing
