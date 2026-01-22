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

### Step 0: Get Active Project

First, determine the active project:

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_active_project)
```

If no active project is found:
```
No active GSD project found.

Run one of:
  /gsd-new-project       Create a new project
  /gsd-set-project <name> Switch to an existing project
  /gsd-list-projects     See available projects
```

Set the planning directory based on active project:
```bash
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

### Step 1: Load Requirements

Read verification context from the project's planning directory:
1. `$PLANNING_DIR/PROJECT.md` - Success criteria
2. `$PLANNING_DIR/REQUIREMENTS.md` - Detailed requirements
3. `$PLANNING_DIR/phases/phase-XX/PLAN.md` - What was planned
4. `$PLANNING_DIR/phases/phase-XX/PROGRESS.md` - What was completed

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

### Step 5: Generate Verification Report

Create `$PLANNING_DIR/phases/phase-XX/VERIFICATION.md`:

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

### Step 6: Update State

Update `$PLANNING_DIR/STATE.md`:

```markdown
## Current Status
- **Phase**: [N]
- **Task**: Verification complete
- **Status**: [Verified / Issues Found]

## History
- [YYYY-MM-DD HH:MM] Phase [N] verification: [PASS/FAIL]
```

### Step 7: Report to User

```
✓ Verification Complete: Phase [N]

Status: [PASS / PASS WITH WARNINGS / FAIL]

Requirements: [X/Y] fully met
Tests: [passed/total] passed
Issues: [N] found ([critical], [high], [medium], [low])

Report: $PLANNING_DIR/phases/phase-XX/VERIFICATION.md

[If PASS]
Next: Run /gsd-plan-phase [N+1] to continue

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
