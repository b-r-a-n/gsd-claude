---
name: gsd-new-project
description: Initialize a new GSD project through guided discovery
args: "[project-name]"
---

# Initialize GSD Project

You are starting a new GSD (Get Shit Done) project. Follow this workflow to gather requirements and set up the project structure.

## Step 0: Detect and Confirm Repository

Before anything else, detect the repository and confirm with the user.

### Detect Repository

```bash
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || hg root 2>/dev/null || echo "")
```

### Confirm with User

If a repository is detected, ask the user to confirm:

```
Detected repository: [REPO_ROOT]

Is this the correct repository for this project? [Y/n]
```

- If user confirms (Y or Enter): proceed with this repository
- If user says no (n): ask them to `cd` to the correct repository and run the command again

If NO repository is detected:

```
No Git or Mercurial repository detected in current directory.

Please either:
  1. Navigate to a repository: cd /path/to/your/repo
  2. Initialize a new repository: git init

Then run /gsd:commands:new-project again.
```

Do NOT proceed without a confirmed repository.

## Project Name

If a project name is provided as: $ARGUMENTS - use that name.
Otherwise, ask the user for a short, kebab-case project name (e.g., "auth-refactor", "new-dashboard").

## Phase 1: Project Discovery

Ask the user these questions (adapt based on context):

### Core Questions
1. **What are you building?** (Brief description of the project/feature)
2. **What problem does it solve?** (The "why" behind the project)
3. **Who are the stakeholders?** (Users, teams, or systems affected)
4. **What are the key constraints?** (Time, technology, compatibility, etc.)
5. **What does success look like?** (Acceptance criteria)

### Technical Questions (if applicable)
6. **Is this a new project or modifying existing code?**
7. **What technologies/frameworks are required or preferred?**
8. **Are there existing patterns to follow?**
9. **What are the testing requirements?**

## Phase 2: Codebase Exploration (if existing code)

If this is an existing codebase, use the researcher agent approach:
1. Read root-level files (README, package.json, etc.)
2. Map directory structure
3. Identify tech stack
4. Find relevant modules
5. Document in research notes

## Phase 3: Register Project and Create Structure

### Step 3.1: Register the Project

Register the project using the project management system:

```bash
~/.claude/commands/gsd/scripts/project.sh register_project "<project-name>" "<brief description>"
```

This creates:
- `~/.claude/planning/projects/<project-name>/project.yml`
- `~/.claude/planning/projects/<project-name>/last-active`
- Sets this as the active project in `~/.claude/planning/.current-project`

### Step 3.2: Create Project Planning Structure

Create the project-specific planning directories:

```bash
PROJECT_DIR="$HOME/.claude/planning/projects/<project-name>"
mkdir -p "$PROJECT_DIR/phases" "$PROJECT_DIR/sessions" "$PROJECT_DIR/research"
```

Note: All project state is stored in `~/.claude/planning/projects/<project-name>/`, NOT in the repository's `.planning/` directory. This keeps project metadata external to the codebase.

### Create PROJECT.md

Create `~/.claude/planning/projects/<project-name>/PROJECT.md`:

```markdown
# Project: [Name]

## Vision
[One-paragraph description of what we're building and why]

## Stakeholders
- [Stakeholder 1]: [Their interest/concern]
- [Stakeholder 2]: [Their interest/concern]

## Constraints
- [Constraint 1]
- [Constraint 2]

## Success Criteria
- [ ] [Criterion 1]
- [ ] [Criterion 2]

## Out of Scope
- [What we're NOT doing]
```

### Create REQUIREMENTS.md

Create `~/.claude/planning/projects/<project-name>/REQUIREMENTS.md`:

```markdown
# Requirements

## Functional Requirements

### FR-001: [Title]
- **Description**: [What it does]
- **Acceptance**: [How to verify]
- **Priority**: [Must/Should/Could]

### FR-002: [Title]
...

## Non-Functional Requirements

### NFR-001: [Title]
- **Description**: [Quality attribute]
- **Measure**: [How to measure]
- **Target**: [Acceptable threshold]

## Technical Requirements

### TR-001: [Title]
- **Description**: [Technical constraint]
- **Rationale**: [Why this matters]
```

### Create ROADMAP.md

Create `~/.claude/planning/projects/<project-name>/ROADMAP.md`:

```markdown
# Roadmap

## Phase 1: [Name]
- **Goal**: [What this phase achieves]
- **Deliverables**:
  - [Deliverable 1]
  - [Deliverable 2]

## Phase 2: [Name]
- **Goal**: [What this phase achieves]
- **Depends on**: Phase 1
- **Deliverables**:
  - [Deliverable 1]

## Phase 3: [Name]
...
```

### Create STATE.md

Create `~/.claude/planning/projects/<project-name>/STATE.md`:

```markdown
# Project State

## Current Status
- **Phase**: Not started
- **Task**: None
- **Status**: Initializing

## History
- [YYYY-MM-DD HH:MM] Project initialized
```

## Phase 4: Summary

After creating all files, provide a summary:

```
GSD Project Initialized: [project-name]

Repository: [REPO_ROOT]
Project ID: [id from register_project]
Planning directory: ~/.claude/planning/projects/[project-name]/

Created:
  PROJECT.md      - Project goals and constraints
  REQUIREMENTS.md - Detailed requirements
  ROADMAP.md      - Phase overview
  STATE.md        - Current state tracker

This project is now the active project. All commits will be tagged with:
  [project-name] type(phase-task): description

Next steps:
  1. Review the generated documents
  2. Run /gsd:commands:plan-phase 1 to create Phase 1 plan
  3. Run /gsd:commands:execute-phase to begin implementation

Other commands:
  /gsd:commands:list-projects   - See all projects
  /gsd:commands:set-project     - Switch to another project
  /gsd:commands:progress        - Check current status
```

## Guidelines

- Ask questions conversationally, not as a form
- Adapt questions based on project type
- If the user is vague, ask clarifying questions
- For existing codebases, explore before writing requirements
- Keep documents concise but complete
- Use the user's terminology, not generic jargon
