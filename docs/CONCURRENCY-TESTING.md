# Concurrency Testing Checklist

Manual testing procedures for verifying GSD concurrent operations work correctly on your system.

## Prerequisites

- Two or more terminal windows
- GSD installed and verified (`./verify.sh` passes)
- At least one GSD project created

## Test 1: Concurrent verify.sh

**Purpose**: Verify the verification script doesn't interfere with itself when run in parallel.

**Steps**:
```bash
cd ~/.claude/commands/gsd
./verify.sh & ./verify.sh & wait
echo "Exit codes: $?"
```

**Expected**: Both runs complete successfully with exit code 0.

**Failure indicators**:
- Errors about missing temp directories
- "directory not found" messages
- Different pass/fail counts between runs

## Test 2: Project Isolation with GSD_PROJECT

**Purpose**: Verify environment variable provides session isolation.

**Steps**:

Terminal 1:
```bash
export GSD_PROJECT=project-a
~/.claude/commands/gsd/scripts/project.sh get_active_project
# Should output: project-a
```

Terminal 2:
```bash
export GSD_PROJECT=project-b
~/.claude/commands/gsd/scripts/project.sh get_active_project
# Should output: project-b
```

**Expected**: Each terminal reports its own project, regardless of `.current-project` file contents.

## Test 3: Concurrent Project Switching

**Purpose**: Verify atomic project switching doesn't corrupt state.

**Setup**: Create two test projects first.

**Steps**:

Terminal 1:
```bash
for i in {1..20}; do
  ~/.claude/commands/gsd/scripts/project.sh set_active_project test-project-1
  sleep 0.1
done
```

Terminal 2 (simultaneously):
```bash
for i in {1..20}; do
  ~/.claude/commands/gsd/scripts/project.sh set_active_project test-project-2
  sleep 0.1
done
```

**Verification**:
```bash
cat ~/.claude/planning/.current-project
```

**Expected**: File contains a valid project name (either test-project-1 or test-project-2), not corrupted or partial content.

**Failure indicators**:
- Empty file
- Partial project name
- Mixed content from both projects

## Test 4: Concurrent Project Registration

**Purpose**: Verify only one registration succeeds when two sessions try to register the same project name simultaneously.

**Steps** (run as close to simultaneously as possible):

Terminal 1:
```bash
~/.claude/commands/gsd/scripts/project.sh register_project "concurrent-test-$$" 2>&1
echo "Terminal 1 exit: $?"
```

Terminal 2:
```bash
~/.claude/commands/gsd/scripts/project.sh register_project "concurrent-test-$$" 2>&1
echo "Terminal 2 exit: $?"
```

**Expected**:
- One terminal succeeds (exit 0)
- One terminal fails gracefully with "already exists" message
- No partial project directories

**Cleanup**:
```bash
rm -rf ~/.claude/planning/projects/concurrent-test-*
```

## Test 5: Atomic File Writes

**Purpose**: Verify file locking prevents corruption during concurrent writes.

**Steps**:
```bash
# Create test file
echo "initial" > /tmp/gsd-test-file

# Run concurrent writes
for i in {1..10}; do
  (
    source ~/.claude/commands/gsd/scripts/lock.sh
    gsd_atomic_write /tmp/gsd-test-file "content-from-process-$$-iteration-$i"
  ) &
done
wait

# Check result
cat /tmp/gsd-test-file
```

**Expected**: File contains complete content from one of the processes, not mixed or partial content.

**Cleanup**:
```bash
rm -f /tmp/gsd-test-file
```

## Test 6: Session File Uniqueness

**Purpose**: Verify pause-work creates unique session files even when run rapidly.

**Steps**:
```bash
# Note: This requires an active project with a valid phase
# The session files should have unique names

ls -la ~/.claude/planning/projects/*/sessions/ | head -20
# Check that filenames include seconds and random suffix
```

**Expected**: Session files have names like `session-YYYYMMDD-HHMMSS-XXXX.md` where XXXX is a random suffix.

## Test 7: VCS Commit Tagging Consistency

**Purpose**: Verify commits are tagged with the correct project even during concurrent operations.

**Steps**:

Terminal 1:
```bash
export GSD_PROJECT=project-a
# Make and commit a change
echo "test" >> /tmp/test-file
~/.claude/commands/gsd/scripts/vcs.sh vcs-atomic-commit test 1 1.1 "test commit" project-a
```

Terminal 2 (simultaneously, different project):
```bash
export GSD_PROJECT=project-b
# Make and commit a different change
echo "test2" >> /tmp/test-file2
~/.claude/commands/gsd/scripts/vcs.sh vcs-atomic-commit test 1 1.2 "test commit" project-b
```

**Verification**:
```bash
git log --oneline -5
```

**Expected**: Each commit has the correct `[project-name]` tag matching the project that made it.

## Troubleshooting

### Lock Files Not Released

If operations seem stuck, check for stale lock files:
```bash
ls -la ~/.claude/planning/*.lock 2>/dev/null
```

Remove stale locks only if you're certain no GSD operations are running:
```bash
rm -f ~/.claude/planning/*.lock
```

### File Permission Issues

Ensure the planning directory is writable:
```bash
ls -la ~/.claude/planning/
# Should show your user as owner with write permissions
```

### macOS-Specific Issues

macOS doesn't have `flock` by default. GSD uses a custom lock mechanism. If you see locking errors:
1. Check if `lockfile` command is available
2. Verify `/tmp` is writable

## Reporting Issues

If you encounter concurrency issues:
1. Note the exact commands and timing
2. Capture any error messages
3. Check for orphaned lock files
4. Report at https://github.com/anthropics/claude-code/issues
