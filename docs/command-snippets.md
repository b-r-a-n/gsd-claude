# GSD Command Snippets

Reusable patterns for GSD command files.

## Step 0: Get Active Project (with Ambiguity Handling)

Use this pattern at the start of commands that need an active project.

### Implementation

```markdown
### Step 0: Get Active Project

First, check if there are any projects for this repository and handle ambiguity:

\`\`\`bash
AMBIGUITY=$("~/.claude/commands/gsd/scripts/project.sh" check_project_ambiguity 2>/tmp/gsd-projects)
\`\`\`

Handle each case:

**Case: "none"** - No projects for this repo
\`\`\`
No GSD projects found for this repository.

Run one of:
  /gsd:commands:new-project       Create a new project
  /gsd:commands:discover-projects Find projects from commits
\`\`\`

**Case: "single" or "selected"** - Unambiguous, proceed normally
\`\`\`bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
\`\`\`

**Case: "ambiguous"** - Multiple projects, no explicit selection

When ambiguous, use the `AskUserQuestion` tool to prompt the user to select a project.
Read the project list from `/tmp/gsd-projects` and present as options.

After user selects, persist the choice:
\`\`\`bash
~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected-project>"
\`\`\`

Then proceed with `get_active_project` to get the now-selected project.
```

### Example Usage in Commands

Commands should check ambiguity first, then either proceed or prompt:

```markdown
### Step 0: Get Active Project

First, check project status for this repository:

\`\`\`bash
AMBIGUITY=$("~/.claude/commands/gsd/scripts/project.sh" check_project_ambiguity 2>/tmp/gsd-projects)
\`\`\`

- If `AMBIGUITY` is "none": Display "No GSD projects found" message and stop
- If `AMBIGUITY` is "single" or "selected": Continue to get the active project
- If `AMBIGUITY` is "ambiguous":
  1. Read project list from `/tmp/gsd-projects`
  2. Use `AskUserQuestion` tool to prompt: "Which project would you like to work on?"
  3. Present each project as an option
  4. After selection, run: `set_active_project "<selected>"`
  5. Then continue with the command

Once project is determined:
\`\`\`bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
\`\`\`
```

## Notes

- The `check_project_ambiguity` function outputs the project list to stderr when ambiguous
- Redirect stderr to a temp file to capture the list: `2>/tmp/gsd-projects`
- The `AskUserQuestion` tool is a Claude Code tool, not a bash command
- Always call `set_active_project` after user selection to persist the choice
