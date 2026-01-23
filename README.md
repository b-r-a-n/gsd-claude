# GSD - Get Shit Done for Claude Code

A structured workflow system for Claude Code that brings disciplined project planning, phase-based execution, and progress tracking to your AI-assisted development sessions.

## What is GSD?

GSD transforms how you work with Claude Code by introducing a systematic approach to project development:

- **Plan before you code** - Break projects into phases with clear objectives
- **Execute with focus** - Work through one phase at a time with full context
- **Track everything** - Automatic progress tracking and session management
- **Version control aware** - Seamless integration with Git and Mercurial

## Features

- **Phase-based planning** - Structure work into logical phases with dependencies
- **VCS abstraction** - Works with both Git and Mercurial through unified interface
- **Progress tracking** - Real-time visibility into completed and remaining work
- **Session management** - Pause and resume work with full context preservation
- **Multi-project support** - Manage multiple projects simultaneously
- **Codebase mapping** - Automatic discovery of project structure
- **Quick mode** - Fast-track simple tasks without full planning overhead
- **Verification system** - Validate completed work against phase requirements

## Quick Install

```bash
git clone https://github.com/b-r-a-n/gsd-claude.git ~/.claude/commands/gsd
cd ~/.claude/commands/gsd
./install.sh
```

## Prerequisites

- **Claude Code** - Anthropic's CLI for Claude
- **Bash 4.0+** - Required for associative arrays and modern features
- **Git or Mercurial** - At least one version control system
- **shasum** - For checksum verification (usually pre-installed)

## Permissions Setup

GSD runs shell scripts and git commands that may trigger Claude Code permission prompts. To run without prompts, add these permissions to your Claude Code settings:

**Quick setup** - Add to `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(~/.claude/commands/gsd/**)",
      "Bash(git status*)",
      "Bash(git add*)",
      "Bash(git commit*)",
      "Bash(git log*)",
      "Bash(git diff*)",
      "Bash(git rev-parse*)",
      "Read(~/.claude/planning/**)",
      "Write(~/.claude/planning/**)"
    ]
  }
}
```

For detailed setup options including per-project configuration, see [docs/PERMISSIONS.md](docs/PERMISSIONS.md).

Pre-made templates are available in `docs/settings-global.json` and `docs/settings-project.json`.

## Quick Start

### 1. Create a new project

```
/gsd:commands:new-project
```

Follow the prompts to name your project and describe what you're building.

### 2. Plan your first phase

```
/gsd:commands:plan-phase 1
```

Define what needs to be accomplished in phase 1, including objectives, deliverables, and success criteria.

### 3. Execute the phase

```
/gsd:commands:execute-phase
```

Claude will work through the phase systematically, tracking progress as tasks are completed.

### 4. Check progress

```
/gsd:commands:progress
```

See what's been completed and what remains.

## Commands Reference

| Command | Description |
|---------|-------------|
| `/gsd:commands:new-project` | Create a new GSD project with planning structure |
| `/gsd:commands:set-project` | Switch active project context |
| `/gsd:commands:list-projects` | Show all GSD projects |
| `/gsd:commands:discover-projects` | Scan directory for potential projects |
| `/gsd:commands:map-codebase` | Analyze and document codebase structure |
| `/gsd:commands:plan-phase` | Plan objectives and tasks for a phase |
| `/gsd:commands:execute-phase` | Execute the current phase with tracking |
| `/gsd:commands:verify-work` | Validate completed work against requirements |
| `/gsd:commands:progress` | Display current progress and status |
| `/gsd:commands:pause-work` | Save session state for later resumption |
| `/gsd:commands:resume-work` | Restore previous session context |
| `/gsd:commands:quick` | Quick mode for simple, single-session tasks |

## Documentation

- **[QUICKSTART.md](QUICKSTART.md)** - 5-minute getting started guide
- **[agents/](agents/)** - Agent behavior definitions
- **[commands/](commands/)** - Command specifications
- **[scripts/](scripts/)** - Core shell utilities

## Project Structure

```
~/.claude/commands/gsd/
├── adapters/           # VCS adapters (git, hg)
├── agents/             # Agent behavior specifications
├── commands/           # Command definitions (.md files)
├── scripts/            # Shell utilities
├── install.sh          # Installation script
├── uninstall.sh        # Uninstallation script
├── verify.sh           # Verification script
├── README.md           # This file
└── QUICKSTART.md       # Quick start guide

~/.claude/planning/
├── projects/           # Project-specific planning data
│   └── <project>/
│       ├── project.yml
│       ├── phases/
│       ├── progress/
│       └── sessions/
└── repos/              # Repo-scoped state (for session isolation)
    └── <repo-hash>/
        └── current-project
```

## How It Works

1. **Project Initialization** - GSD creates a planning structure for your project under `~/.claude/planning/projects/`

2. **Phase Planning** - You define phases with clear objectives, deliverables, and success criteria

3. **Execution** - During execution, GSD maintains context, tracks completed tasks, and updates progress files

4. **Verification** - After execution, verify that deliverables meet the defined criteria

5. **Session Management** - Pause work at any time and resume with full context restoration

## Multi-Session Usage

### GSD_PROJECT Environment Variable

When running multiple Claude sessions simultaneously, you can use the `GSD_PROJECT` environment variable to isolate each session to a specific project:

```bash
GSD_PROJECT=my-project claude
```

**Priority order for project detection:**
1. `GSD_PROJECT` environment variable (highest priority)
2. Repo-scoped `current-project` file (in `~/.claude/planning/repos/<hash>/`)
3. Auto-select if exactly one project exists for the current repo
4. Most recently active project for this repo (by `last-active` timestamp)
5. Most recent commit with `[project]` tag

This allows you to have multiple terminals working on different projects without interference.

## Concurrency

GSD is designed for safe concurrent usage by multiple Claude instances.

### File Locking

All state file operations (STATE.md, PROGRESS.md, repo-scoped `current-project`) use file locking to prevent race conditions:

- **Linux**: Uses `flock` for advisory locking
- **macOS**: Uses a custom lock file mechanism for compatibility

### Atomic Operations

Critical file updates use the "write-to-temp-then-rename" pattern:
1. Write new content to a temporary file
2. Atomically rename temp file to target path

This prevents partial writes and ensures file integrity.

### Project Isolation

For concurrent work on different projects:
- Use `GSD_PROJECT` environment variable (recommended)
- Or run `/gsd:commands:set-project` in each session

### What's Safe

- Multiple sessions working on **different projects** simultaneously
- Multiple sessions working on **different waves** of the same phase
- Running `verify.sh` concurrently

### Best Practices

1. Use `GSD_PROJECT=<name>` when launching sessions that work on different projects
2. Coordinate wave execution when multiple sessions work on the same project
3. Commits are tagged with `[project-name]` for traceability

For detailed testing procedures, see [docs/CONCURRENCY-TESTING.md](docs/CONCURRENCY-TESTING.md).

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please read the existing code style and submit pull requests for any improvements.
