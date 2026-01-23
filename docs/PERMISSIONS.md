# GSD Permissions Setup

This guide explains how to configure Claude Code permissions for GSD to run without approval prompts.

## Why Permissions Are Needed

GSD performs several operations that Claude Code may ask for approval:

1. **Running scripts** - GSD uses shell scripts for project management, VCS operations, and file locking
2. **Git operations** - Checking status, staging files, creating commits, reading history
3. **File operations** - Reading and writing planning files in `~/.claude/planning/`

Without permission configuration, you'll be prompted to approve each operation. This guide shows how to pre-approve these operations.

## Quick Setup

### Option 1: Allow All GSD Operations (Recommended)

Add these permissions to your Claude Code settings:

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

### Option 2: Minimal Permissions

If you prefer more restrictive permissions:

```json
{
  "permissions": {
    "allow": [
      "Bash(~/.claude/commands/gsd/scripts/project.sh*)",
      "Bash(~/.claude/commands/gsd/scripts/vcs.sh*)",
      "Bash(git status)",
      "Bash(git rev-parse*)",
      "Read(~/.claude/planning/**)"
    ]
  }
}
```

Note: Minimal permissions may still trigger prompts for some operations.

## Configuration Methods

### Global Configuration

To enable GSD everywhere, add permissions to your global Claude settings:

**Location**: `~/.claude/settings.json`

1. Open or create the file:
   ```bash
   mkdir -p ~/.claude
   nano ~/.claude/settings.json
   ```

2. Add the permissions block (see Quick Setup above)

3. Save and restart Claude Code

### Per-Project Configuration

To enable GSD for a specific project only:

**Location**: `<your-project>/.claude/settings.local.json`

1. Create the file in your project:
   ```bash
   mkdir -p .claude
   nano .claude/settings.local.json
   ```

2. Add the permissions block

3. Add `.claude/settings.local.json` to your `.gitignore` if you don't want to share it

## What Each Permission Allows

### Script Execution
- `Bash(~/.claude/commands/gsd/**)` - Run GSD scripts (project management, VCS, locking)

### Git Operations
- `Bash(git status*)` - Check working tree status
- `Bash(git add*)` - Stage files for commit
- `Bash(git commit*)` - Create commits (with GSD project tags)
- `Bash(git log*)` - Read commit history (for project discovery)
- `Bash(git diff*)` - View changes
- `Bash(git rev-parse*)` - Get repository information

### File Operations
- `Read(~/.claude/planning/**)` - Read project plans, state, progress
- `Write(~/.claude/planning/**)` - Update state, create session files

## Verifying Permissions Work

After configuring permissions, test with:

```
/gsd:commands:progress
```

If configured correctly, this should run without any approval prompts.

## Troubleshooting

### Still Getting Prompts?

1. **Check file location**: Ensure settings file is in the correct location
2. **Validate JSON**: Use a JSON validator to check syntax
3. **Restart Claude Code**: Some changes require restart
4. **Check pattern matching**: Ensure patterns match actual commands

### Permission Denied Errors?

If you see permission errors (not approval prompts), check:
- File permissions on `~/.claude/planning/`
- GSD scripts are executable: `chmod +x ~/.claude/commands/gsd/**/*.sh`

## Security Considerations

These permissions allow Claude to:
- Execute GSD scripts (not arbitrary code)
- Run standard git commands
- Read/write to the planning directory

They do NOT allow:
- Arbitrary bash command execution
- Access to files outside the planning directory
- Network operations
- System modifications

## Template Files

Pre-made settings templates are available:
- `docs/settings-global.json` - For global configuration
- `docs/settings-project.json` - For per-project configuration

Copy the appropriate template to your settings location and restart Claude Code.
