# VCS Interface Reference

This document defines the abstract VCS operations that all adapters must implement.

## Overview

The GSD system uses a VCS abstraction layer to support multiple version control systems. Currently supported:
- **Git** - `git-adapter.sh`
- **Mercurial** - `hg-adapter.sh`

## Usage

All VCS operations go through the dispatcher:

```bash
~/.claude/commands/gsd/scripts/vcs.sh <command> [args...]
```

The dispatcher automatically detects the VCS in use and routes to the correct adapter.

## Interface Operations

### Status & Information

| Function | Description | Return |
|----------|-------------|--------|
| `vcs-status` | Working directory status | Porcelain-style output |
| `vcs-branch` | Current branch/bookmark name | Branch name string |
| `vcs-dirty` | Check if working directory is clean | Exit 0 if clean, 1 if dirty |
| `vcs-root` | Repository root directory | Absolute path |
| `vcs-current-rev` | Current revision short hash | Hash string |
| `vcs-has-commits` | Check if repo has any commits | Exit 0 if yes, 1 if no |

### Staging & Committing

| Function | Arguments | Description |
|----------|-----------|-------------|
| `vcs-stage` | `<file>` | Stage file for commit |
| `vcs-unstage` | `<file>` | Unstage file |
| `vcs-commit` | `<message>` | Create commit with message |
| `vcs-atomic-commit` | `<type> <phase> <task> <desc>` | Formatted commit: `type(phase-task): desc` |

### History & Diff

| Function | Arguments | Description |
|----------|-----------|-------------|
| `vcs-log` | `[n]` | Show last n commits (default: 10) |
| `vcs-diff` | `[file]` | Show uncommitted changes |
| `vcs-diff-staged` | - | Show staged changes |

### Bisect

| Function | Arguments | Description |
|----------|-----------|-------------|
| `vcs-bisect-start` | - | Start bisect session |
| `vcs-bisect-good` | `[rev]` | Mark revision as good |
| `vcs-bisect-bad` | `[rev]` | Mark revision as bad |
| `vcs-bisect-reset` | - | End bisect session |

## Adding a New VCS

To add support for a new VCS (e.g., SVN):

1. Create `adapters/svn-adapter.sh` implementing all interface functions
2. Update `scripts/detect-vcs.sh` to detect the new VCS
3. Update `scripts/vcs.sh` to source the new adapter

### Template

```bash
#!/bin/bash
# SVN adapter implementing the VCS interface

vcs-status() {
  svn status
}

vcs-branch() {
  # Extract branch from URL
  svn info | grep 'Relative URL' | sed 's/.*\///'
}

vcs-dirty() {
  [ -z "$(svn status)" ]
}

# ... implement all other functions
```

## Commit Message Format

The `vcs-atomic-commit` function creates commits with a standard format:

```
<type>(<phase>-<task>): <description>
```

### Types

| Type | Usage |
|------|-------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code refactoring |
| `docs` | Documentation |
| `test` | Tests |
| `chore` | Maintenance tasks |

### Examples

```bash
vcs.sh vcs-atomic-commit feat 01 03 "Add user authentication"
# Creates: feat(01-03): Add user authentication

vcs.sh vcs-atomic-commit fix 02 01 "Resolve race condition in cache"
# Creates: fix(02-01): Resolve race condition in cache
```

## Notes

### Git-specific Behavior
- `vcs-stage` uses `git add`
- `vcs-diff-staged` uses `git diff --staged`

### Mercurial-specific Behavior
- `vcs-stage` uses `hg add` (no-op for tracked files)
- `vcs-diff-staged` shows all changes (Mercurial has no staging area)
- Bookmarks are preferred over branches for `vcs-branch`
