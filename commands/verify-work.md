---
name: gsd-verify-work
description: Verify completed work against requirements using goal-backward verification
args: "[phase_number]"
---

# Verify Work

You are COORDINATING verification of completed work. Your role is to:
1. Determine project and phase to verify
2. Delegate ALL verification work to a subagent
3. Report the results to the user

**CRITICAL**: Do NOT read requirements, run tests, or perform code review yourself.
Delegate ALL verification work to the subagent to preserve your context.

## Input

- **Phase number**: $ARGUMENTS (optional - defaults to most recent phase with completed tasks)

## Philosophy: Goal-Backward Verification

The verifier subagent will start from the original goals and trace forward to verify implementation, rather than reviewing code and assuming it's correct.

```
Requirements → Acceptance Criteria → Implementation → Tests
     ↓              ↓                    ↓            ↓
   Verify        Verify               Verify       Run
```

## Workflow

### Step 0: Get Active Project

```bash
PROJECT=$("~/.claude/commands/gsd/scripts/project.sh" get_or_select_project)
```

Handle the exit code:

**Exit 0** - Project resolved (single, selected, or auto-selected):
```bash
PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
```

**Exit 1** - Multiple projects, user selection required:
- `$PROJECT` contains newline-separated list of available projects
- Use `AskUserQuestion` tool: "Which project would you like to verify?" with projects as options
- After selection, set and get active project:
  ```bash
  ~/.claude/commands/gsd/scripts/project.sh set_active_project "<selected>"
  PROJECT="<selected>"
  PLANNING_DIR="$HOME/.claude/planning/projects/$PROJECT"
  ```

**Exit 2** - No projects found:
```
No GSD projects found for this repository.

Run one of:
  /gsd:commands:new-project       Create a new project
  /gsd:commands:discover-projects Find projects from commits
```

### Step 1: Determine Phase to Verify

**If phase number provided via $ARGUMENTS:**
- Use that phase number directly
- Verify the phase directory exists: `$PLANNING_DIR/phases/phase-XX/`

**If no phase number provided:**
- Query Task API to find the most recent phase with completed tasks:
  ```
  TaskList -> filter by:
    - metadata.gsd_project == PROJECT
    - status == "completed"
  -> find highest gsd_phase value
  ```
- If no completed tasks found, report error (see Error Handling)

### Step 2: Delegate to Verifier Subagent

Use the Task tool to spawn a verifier subagent:

```
Task tool parameters:
  description: "Verify: Phase [N] of [project-name]"
  subagent_type: "general-purpose"
  prompt: <use the subagent prompt template below>
```

#### Subagent Prompt Template

Pass this prompt to the Task tool, replacing placeholders with actual values:

```
# Verification Subagent

You are performing goal-backward verification on completed work for a GSD project.

## Context

- **Project**: <PROJECT_NAME>
- **Phase**: <PHASE_NUMBER>
- **Planning Directory**: <PLANNING_DIR>

## Instructions

Follow the detailed verification workflow from the verifier agent specification.

### Step 1: Load Requirements

Read these files:
1. <PLANNING_DIR>/PROJECT.md - Success criteria
2. <PLANNING_DIR>/REQUIREMENTS.md - Detailed requirements
3. <PLANNING_DIR>/phases/phase-<PHASE_NUMBER>/PLAN.md - What was planned

Query Task API for completed tasks:
```
TaskList -> filter by:
  - metadata.gsd_project == "<PROJECT_NAME>"
  - metadata.gsd_phase == <PHASE_NUMBER>
  - status == "completed"
```

### Step 2: Map Requirements to Implementation

Create a verification matrix mapping each requirement to its implementation.
Trace from requirements → acceptance criteria → implementation → evidence.

### Step 3: Run Automated Tests

Detect and run the appropriate test command for this project:
- npm test, pytest, cargo test, go test, etc.

Report: total, passed, failed, skipped, coverage (if available).

### Step 4: Check Background Work Status

```bash
~/.claude/commands/gsd/scripts/background.sh list_background
```

For any tracked items, use TaskOutput to check/wait for completion.

### Step 5: Code Review

Review implementation for:
- Functionality: Does it work as specified?
- Quality: Follows patterns, no bugs, no security issues?
- Completeness: All tasks done, no inappropriate TODOs?

Classify issues as: Critical, High, Medium, Low

### Step 6: Generate Verification Report

Write: <PLANNING_DIR>/phases/phase-<PHASE_NUMBER>/VERIFICATION.md

Include all sections: Summary, Requirements Compliance, Test Results,
Background Work Status, Code Review Findings, Manual Checklist, Recommendations.

### Step 7: Update State

Update <PLANNING_DIR>/STATE.md with verification result.

## Return Format

Return ONLY this structured format:

STATUS: [PASS | PASS_WITH_WARNINGS | FAIL]

REQUIREMENTS_MET: [X]/[Y]

TEST_RESULTS:
  total: [N]
  passed: [N]
  failed: [N]
  skipped: [N]
  coverage: [X%]

ISSUES_FOUND:
  critical: [N]
  high: [N]
  medium: [N]
  low: [N]

BLOCKING_ISSUES:
- [Issue 1 brief description]
- Or "None"

REPORT_PATH: [full path to VERIFICATION.md]

RECOMMENDATIONS:
- [Recommendation 1]
- [Recommendation 2]

## Status Definitions

- PASS: All requirements met, tests passing, no critical/high issues
- PASS_WITH_WARNINGS: Requirements met, tests passing, but medium/low issues found
- FAIL: Requirements not met, OR tests failing, OR critical/high issues found
```

### Step 3: Report Results

When the subagent returns, parse and display the results.

**For STATUS: PASS**
```
✓ Verification Complete: Phase [N] - [project-name]

Status: PASS

Requirements: [X]/[Y] fully met
Tests: [passed]/[total] passed ([coverage])
Issues: [N] found (0 critical, 0 high, [M] medium, [L] low)

Report: [REPORT_PATH]

Next: Run /gsd:commands:plan-phase [N+1] to continue
```

**For STATUS: PASS_WITH_WARNINGS**
```
✓ Verification Complete: Phase [N] - [project-name]

Status: PASS WITH WARNINGS

Requirements: [X]/[Y] fully met
Tests: [passed]/[total] passed ([coverage])
Issues: [N] found (0 critical, 0 high, [M] medium, [L] low)

Recommendations:
  [list from subagent]

Report: [REPORT_PATH]

Next: Consider addressing warnings, then run /gsd:commands:plan-phase [N+1]
```

**For STATUS: FAIL**
```
⚠ Verification Failed: Phase [N] - [project-name]

Status: FAIL

Requirements: [X]/[Y] fully met
Tests: [passed]/[total] passed ([coverage])
Issues: [N] found ([C] critical, [H] high, [M] medium, [L] low)

Blocking Issues:
  [list from subagent]

Recommendations:
  [list from subagent]

Report: [REPORT_PATH]

Action Required: Address blocking issues before proceeding
```

## Error Handling

### No Completed Tasks Found

If querying for completed tasks returns none:

```
⚠ No Completed Tasks Found

No completed tasks found for project [project-name].

This may indicate:
- Phase execution hasn't started
- Tasks are still in progress

Run:
  /gsd:commands:execute-phase    Execute tasks for current phase
  /gsd:commands:progress         Check current status
```

### Subagent Timeout or Failure

If the subagent times out or returns an error:

```
⚠ Verification Subagent Error

Error: [error details]

Options:
1. Retry verification
2. Run manual verification (read files yourself)
3. Skip verification and proceed

Choose [1-3]:
```

Use AskUserQuestion to get the user's choice:
- Option 1: Re-invoke the Task tool with the same prompt
- Option 2: Fall back to reading requirements, running tests, and doing code review directly (not recommended - context heavy)
- Option 3: Skip verification, warn about risks

### Phase Directory Not Found

If the specified phase directory doesn't exist:

```
⚠ Phase Not Found

Phase [N] directory not found at: $PLANNING_DIR/phases/phase-[N]/

Available phases:
  [list existing phase directories]

Run:
  /gsd:commands:plan-phase [N]   Plan this phase first
```

## Guidelines

- **Delegate, don't execute**: All verification work happens in the subagent
- Always trace back to original requirements
- Don't just verify code compiles - verify it works
- Be specific about issues found
- Provide actionable recommendations
- Distinguish blocking vs non-blocking issues
