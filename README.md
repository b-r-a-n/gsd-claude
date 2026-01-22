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

## Quick Start

### 1. Create a new project

```
/gsd-new-project
```

Follow the prompts to name your project and describe what you're building.

### 2. Plan your first phase

```
/gsd-plan-phase 1
```

Define what needs to be accomplished in phase 1, including objectives, deliverables, and success criteria.

### 3. Execute the phase

```
/gsd-execute-phase
```

Claude will work through the phase systematically, tracking progress as tasks are completed.

### 4. Check progress

```
/gsd-progress
```

See what's been completed and what remains.

## Commands Reference

| Command | Description |
|---------|-------------|
| `/gsd-new-project` | Create a new GSD project with planning structure |
| `/gsd-set-project` | Switch active project context |
| `/gsd-list-projects` | Show all GSD projects |
| `/gsd-discover-projects` | Scan directory for potential projects |
| `/gsd-map-codebase` | Analyze and document codebase structure |
| `/gsd-plan-phase` | Plan objectives and tasks for a phase |
| `/gsd-execute-phase` | Execute the current phase with tracking |
| `/gsd-verify-work` | Validate completed work against requirements |
| `/gsd-progress` | Display current progress and status |
| `/gsd-pause-work` | Save session state for later resumption |
| `/gsd-resume-work` | Restore previous session context |
| `/gsd-quick` | Quick mode for simple, single-session tasks |

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
└── projects/           # Project-specific planning data
    └── <project>/
        ├── overview.md
        ├── phases/
        ├── progress/
        └── sessions/
```

## How It Works

1. **Project Initialization** - GSD creates a planning structure for your project under `~/.claude/planning/projects/`

2. **Phase Planning** - You define phases with clear objectives, deliverables, and success criteria

3. **Execution** - During execution, GSD maintains context, tracks completed tasks, and updates progress files

4. **Verification** - After execution, verify that deliverables meet the defined criteria

5. **Session Management** - Pause work at any time and resume with full context restoration

## License

MIT License - See [LICENSE](LICENSE) for details.

## Contributing

Contributions welcome! Please read the existing code style and submit pull requests for any improvements.
