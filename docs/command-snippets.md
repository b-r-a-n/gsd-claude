# GSD Command Snippets

Reusable patterns for GSD command files.

## Project Selection Pattern

Use this pattern at the start of any command that needs an active project:

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_or_select_project)
EXIT_CODE=$?

case $EXIT_CODE in
  0)
    # Project found - proceed
    PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
    ;;
  1)
    # No active project - prompt user to select
    # $PROJECT contains newline-separated list of available projects
    # Use AskUserQuestion to let user choose
    ;;
  2)
    # No projects exist
    echo "No GSD projects found. Run /gsd:commands:new-project first."
    ;;
esac
```

**Key points:**
- Single function call replaces complex ambiguity checking
- Exit codes are self-documenting
- Caller handles user prompting (keeps shell script simple)

### After User Selection

When exit code is 1 and user selects a project, persist the choice:

```bash
~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected-project>"
```

Then re-run `get_or_select_project` or use the selected project directly.

## Notes

- The `get_or_select_project` function handles all project lookup logic
- Exit code 1 outputs the project list to stdout for the caller to parse
- The `AskUserQuestion` tool is a Claude Code tool, not a bash command
- Always call `set_active_project` after user selection to persist the choice

## TaskList Local Cache Pattern

Use this pattern when a command needs to query TaskList multiple times. Caching reduces context bloat from repeated full task list retrieval.

### When to Use
- Commands with execution loops (execute-phase)
- Commands that filter tasks multiple ways
- Any command querying TaskList more than twice

### Implementation

```markdown
### Initialize Task Cache

Query TaskList ONCE and maintain local state:

\`\`\`
# Single query at command start
all_tasks = TaskList
cache = {
  tasks: all_tasks.filter(task.metadata.gsd_project == project),
  completed_ids: Set(tasks.filter(t => t.status == "completed").map(t => t.id)),
  last_refresh: now()
}
\`\`\`

### Find Ready Tasks (from cache)

\`\`\`
ready = cache.tasks.filter(
  task.status == "pending" AND
  task.blockedBy.every(id => cache.completed_ids.has(id))
)
\`\`\`

### Update Cache Locally

After TaskUpdate completes a task:
\`\`\`
cache.tasks[task_id].status = "completed"
cache.completed_ids.add(task_id)
\`\`\`

### Refresh Cache (only when needed)

\`\`\`
if no_ready_tasks AND has_pending_tasks:
  # Re-query to detect deadlock or external changes
  cache = refresh_from_TaskList()
\`\`\`
```

### Cache Invalidation Rules

| Event | Action |
|-------|--------|
| Task marked in_progress | Local update only |
| Task marked completed | Local update + add to completed_ids |
| Task created (discovered) | Add to cache.tasks |
| Task metadata updated | Local update only |
| No ready tasks found | Refresh from TaskList |
| Phase completion check | Refresh from TaskList |
