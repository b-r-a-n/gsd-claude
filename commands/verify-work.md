---
name: gsd-verify-work
description: Verify completed work against requirements using goal-backward verification
args: "[phase_number]"
---

# Verify Work

You are performing goal-backward verification on completed work, ensuring implementation meets original requirements.

## Input

- **Phase number**: $ARGUMENTS (default: current phase from STATE.md)

## Philosophy: Goal-Backward Verification

Start from the original goals and trace forward to verify implementation, rather than reviewing code and assuming it's correct.

```
Requirements → Acceptance Criteria → Implementation → Tests
     ↓              ↓                    ↓            ↓
   Verify        Verify               Verify       Run
```

## Workflow

### Step 0: Get Active Project (with Ambiguity Handling)

First, check project status for this repository:

```bash
AMBIGUITY=$("~/.claude/commands/gsd/scripts/project.sh" check_project_ambiguity 2>/tmp/gsd-projects)
```

Handle each case:

**Case: "none"** - No projects for this repo:
```
No GSD projects found for this repository.

Run one of:
  /gsd:commands:new-project       Create a new project
  /gsd:commands:discover-projects Find projects from commits
```

**Case: "single" or "selected"** - Proceed normally:
```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

**Case: "ambiguous"** - Multiple projects, no explicit selection:
1. Read the project list from `/tmp/gsd-projects` (one project per line)
2. Use the `AskUserQuestion` tool to prompt the user:
   - Question: "Which project would you like to verify?"
   - Options: List each project from the file
3. After user selects, persist the choice:
   ```bash
   ~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected-project>"
   ```
4. Then get the active project and continue:
   ```bash
   PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
   PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
   ```

### Step 1: Load Requirements

Read verification context from the project's planning directory:
1. `$PLANNING_DIR/PROJECT.md` - Success criteria
2. `$PLANNING_DIR/REQUIREMENTS.md` - Detailed requirements
3. `$PLANNING_DIR/phases/phase-XX/PLAN.md` - What was planned

**Query Task API for completed work:**
```
TaskList -> filter by:
  - metadata.gsd_project == current_project
  - metadata.gsd_phase == phase_number
  - status == "completed"
```

This provides the authoritative list of what was completed, including commit hashes stored in task metadata.

**Note:** Do not read STATE.md or PROGRESS.md for completion status. Task API is the sole source of truth.

### Step 2: Map Requirements to Implementation

For each requirement addressed by this phase:

1. **Identify the requirement** (REQ-xxx)
2. **Find acceptance criteria** from requirements doc
3. **Locate implementation** (files, functions)
4. **Verify criteria are met**

Create a verification matrix:

| Requirement | Criteria | Implementation | Status |
|-------------|----------|----------------|--------|
| REQ-001 | User can login | auth.ts:login() | ✅ |
| REQ-002 | Passwords hashed | auth.ts:hashPassword() | ✅ |
| REQ-003 | Session expires | session.ts:checkExpiry() | ⚠️ Partial |

### Step 3: Run Automated Tests

If tests exist, run them:

```bash
# Detect and run appropriate test command
# npm test, pytest, cargo test, go test, etc.
```

Report results:
- Total tests
- Passed / Failed / Skipped
- Coverage (if available)

### Step 3.5: Check Background Work Status

Before generating the verification report, ensure all background work is complete.

#### 3.5.1 Check for Untracked Background Work

**IMPORTANT**: GSD tracking only knows about background work that was explicitly registered.
Use `/tasks` to check for any untracked running processes that may have been spawned during execution.

If untracked background work is found:
```
⚠ Warning: Untracked background work detected

The following processes were found via /tasks but are not in STATE.md tracking:
- [list untracked items]

These may have been spawned without proper tracking. Consider:
1. Waiting for them to complete before verification
2. Killing orphaned processes if no longer needed
3. Documenting any known issues in the verification report
```

#### 3.5.2 Check for Tracked Work

```bash
~/.claude/commands/gsd/scripts/background.sh list_background
```

#### 3.5.3 Poll and Wait for Completion

For any tracked items:

```
Use TaskOutput tool:
  task_id: "<id>"
  block: false
  timeout: 1000
```

If items are still running, wait for completion before proceeding:

```
⚠ Background work still running:
  - [list items]

Waiting for completion before generating verification report...
```

Use `TaskOutput` with `block: true` to wait, or `KillShell` for shell processes if they appear stuck.

#### 3.5.4 Record Status for Report

Note the final status of all background work for inclusion in the verification report:
- Items that completed successfully
- Items that failed or were killed
- Items that timed out

#### 3.5.5 Clear Tracking

After verification:

```bash
~/.claude/commands/gsd/scripts/background.sh clear_all_background
```

See `~/.claude/commands/gsd/docs/background-patterns.md` for detailed patterns.

### Step 4: Code Review

Review implementation for:

**Functionality**
- Does it do what was specified?
- Are edge cases handled?
- Are error messages helpful?

**Quality**
- Follows existing patterns?
- No obvious bugs?
- No security issues?

**Completeness**
- All tasks marked complete actually done?
- No TODO/FIXME left behind?
- Documentation updated if needed?

### Step 5: Generate Verification Report (Write-Only)

Create `$PLANNING_DIR/phases/phase-XX/VERIFICATION.md` (audit trail):

```markdown
# Verification Report: Phase [N]

**Date**: [YYYY-MM-DD]
**Verified by**: Claude (GSD Verifier)

## Summary

**Overall Status**: [PASS / PASS WITH WARNINGS / FAIL]

## Requirements Compliance

| Req ID | Title | Status | Evidence |
|--------|-------|--------|----------|
| REQ-001 | [Title] | ✅ PASS | [file:line or test] |
| REQ-002 | [Title] | ⚠️ PARTIAL | [what's missing] |
| REQ-003 | [Title] | ❌ FAIL | [reason] |

**Compliance Rate**: [X/Y] requirements fully met

## Automated Tests

| Metric | Value |
|--------|-------|
| Total | [N] |
| Passed | [N] |
| Failed | [N] |
| Skipped | [N] |
| Coverage | [X%] |

### Failed Tests
[Details of any failures, or "None"]

## Background Work Status

| Type | ID | Description | Status |
|------|-----|-------------|--------|
| shell | abc123 | cargo build | ✅ Completed |
| task | xyz789 | log monitor | ✅ Completed |

**Summary**: [N] background items tracked, [N] completed successfully, [N] failed/killed

## Code Review Findings

### Issues Found

#### Issue 1: [Title]
- **Severity**: [Critical/High/Medium/Low]
- **Location**: [file:line]
- **Description**: [What's wrong]
- **Recommendation**: [How to fix]

### Positive Observations
- [What was done well]

## Manual Verification Checklist

Items requiring human verification:

- [ ] [Item 1 - why it needs manual check]
- [ ] [Item 2]
- [ ] [Item 3]

## Recommendations

### Must Fix (Blocking)
- [Critical issues that must be addressed]

### Should Fix (Non-blocking)
- [Important issues to address soon]

### Consider (Optional)
- [Suggestions for improvement]

## Conclusion

[Summary paragraph about the verification results and next steps]
```

### Step 6: Update State (Audit Trail)

Update `$PLANNING_DIR/STATE.md` (write-only, for audit trail):

```markdown
## Current Status
- **Phase**: [N]
- **Task**: Verification complete
- **Status**: [Verified / Issues Found]

## History
- [YYYY-MM-DD HH:MM] Phase [N] verification: [PASS/FAIL]
```

**Note:** STATE.md is write-only for audit purposes. Task API is the source of truth for task status.

### Step 7: Report to User

```
✓ Verification Complete: Phase [N]

Status: [PASS / PASS WITH WARNINGS / FAIL]

Requirements: [X/Y] fully met
Tests: [passed/total] passed
Issues: [N] found ([critical], [high], [medium], [low])

Report: $PLANNING_DIR/phases/phase-XX/VERIFICATION.md

[If PASS]
Next: Run /gsd:commands:plan-phase [N+1] to continue

[If FAIL]
Action needed: Review issues in verification report
```

## Guidelines

- Always trace back to original requirements
- Don't just verify code compiles - verify it works
- Run actual tests, don't assume they pass
- Be specific about issues found
- Provide actionable recommendations
- Distinguish blocking vs non-blocking issues
