# GSD Quick Start Guide

Get up and running with GSD in 5 minutes.

## Prerequisites

Before starting, ensure you have:

- Claude Code installed and working
- Bash 4.0+ (`bash --version`)
- Git or Mercurial installed
- A project directory to work with

## Step 1: Verify Installation

Run the verification script to ensure everything is set up correctly:

```bash
~/.claude/commands/gsd/verify.sh
```

You should see all checks passing. If not, run the install script:

```bash
~/.claude/commands/gsd/install.sh
```

## Step 2: Create Your First Project

Start Claude Code in your project directory, then create a new GSD project:

```
/gsd:commands:new-project
```

Claude will ask you for:
- **Project name**: A short identifier (e.g., "my-api", "web-app")
- **Description**: What you're building
- **Goals**: What you want to accomplish

This creates a planning structure under `~/.claude/planning/projects/<project-name>/`.

## Step 3: Plan Your First Phase

Plan what you want to accomplish in phase 1:

```
/gsd:commands:plan-phase 1
```

You'll define:
- **Objectives**: What this phase should achieve
- **Tasks**: Specific work items
- **Deliverables**: What will exist when complete
- **Success criteria**: How to verify completion

### Example Phase Plan

```
Phase 1: Project Setup

Objectives:
- Initialize project structure
- Set up development environment
- Create basic configuration

Tasks:
1. Create directory structure
2. Initialize package.json
3. Set up TypeScript configuration
4. Add ESLint and Prettier
5. Create initial README

Deliverables:
- Working build system
- Linting passes
- Project compiles

Success Criteria:
- `npm run build` succeeds
- `npm run lint` passes
- All config files present
```

## Step 4: Execute the Phase

Start working through the phase:

```
/gsd:commands:execute-phase
```

Claude will:
1. Load the phase context
2. Work through tasks systematically
3. Track progress in real-time
4. Update completion status

During execution, you can check progress anytime with `/gsd:commands:progress`.

## Step 5: Check Progress

View your current status:

```
/gsd:commands:progress
```

This shows:
- Current phase and task
- Completed vs remaining items
- Overall project progress
- Any blockers or notes

## Quick Mode

For simple, single-session tasks that don't need full planning:

```
/gsd:commands:quick
```

Quick mode is perfect for:
- Bug fixes
- Small features
- Code reviews
- Documentation updates

It still tracks your work but skips the formal planning phase.

## Commands Reference

| Command | Description | When to Use |
|---------|-------------|-------------|
| `/gsd:commands:new-project` | Create project | Starting a new project |
| `/gsd:commands:set-project` | Switch project | Working on different project |
| `/gsd:commands:list-projects` | Show projects | See all your projects |
| `/gsd:commands:discover-projects` | Find projects | Scan for existing codebases |
| `/gsd:commands:map-codebase` | Analyze code | Understand project structure |
| `/gsd:commands:plan-phase` | Plan phase | Before starting new phase |
| `/gsd:commands:execute-phase` | Execute phase | Ready to do the work |
| `/gsd:commands:verify-work` | Check work | After completing phase |
| `/gsd:commands:progress` | Show status | Check current state |
| `/gsd:commands:pause-work` | Save state | Need to stop working |
| `/gsd:commands:resume-work` | Restore state | Coming back to work |
| `/gsd:commands:quick` | Quick mode | Simple, fast tasks |

## Example Workflow

Here's a complete example building a REST API:

```
# Start in your project directory
cd ~/projects/my-api

# Create the GSD project
/gsd:commands:new-project
> Name: my-api
> Description: REST API for user management
> Goals: CRUD operations, authentication, tests

# Plan phase 1
/gsd:commands:plan-phase 1
> Phase: Project Setup
> Tasks: Init npm, TypeScript, Express setup, folder structure

# Execute phase 1
/gsd:commands:execute-phase
[Claude works through setup tasks]

# Check progress
/gsd:commands:progress

# Plan phase 2
/gsd:commands:plan-phase 2
> Phase: Core API
> Tasks: User routes, controllers, models, validation

# Execute phase 2
/gsd:commands:execute-phase
[Claude builds the API]

# Need to stop? Pause your work
/gsd:commands:pause-work

# Coming back later? Resume
/gsd:commands:resume-work

# Verify the completed work
/gsd:commands:verify-work
```

## Troubleshooting

### "Project not found" error

Make sure you've created a project first:
```
/gsd:commands:new-project
```

Or set an existing project:
```
/gsd:commands:list-projects
/gsd:commands:set-project <project-name>
```

### "No active phase" error

You need to plan a phase before executing:
```
/gsd:commands:plan-phase 1
```

### Scripts not executable

Run the install script to fix permissions:
```bash
~/.claude/commands/gsd/install.sh
```

### VCS not detected

Make sure you're in a directory with Git or Mercurial:
```bash
git init
# or
hg init
```

### Commands not appearing in Claude Code

Ensure the commands directory is in the right location:
```bash
ls ~/.claude/commands/gsd/commands/
```

You should see `.md` files for each command.

## Next Steps

1. **Read the full README**: `~/.claude/commands/gsd/README.md`
2. **Explore agent behaviors**: `~/.claude/commands/gsd/agents/`
3. **Customize for your workflow**: Edit the command files as needed
4. **Join the community**: Share your experience and improvements

## Tips for Success

1. **Start with clear goals** - The better your project description, the better Claude can help

2. **Keep phases small** - Aim for phases that can be completed in one session

3. **Use quick mode for small tasks** - Don't over-plan simple fixes

4. **Pause before stopping** - Always `/gsd:commands:pause-work` to save context

5. **Verify after each phase** - Use `/gsd:commands:verify-work` to ensure quality

6. **Review progress regularly** - `/gsd:commands:progress` keeps you oriented

Happy shipping!
