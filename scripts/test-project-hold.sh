#!/bin/bash
#
# Test script for GSD project hold/release functions (FR-007)
# Run: ./scripts/test-project-hold.sh
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the project utilities
source "$SCRIPT_DIR/project.sh"

# Test directory - create a temporary projects area
TEST_PROJECTS_DIR=$(mktemp -d)
ORIGINAL_PROJECTS_DIR="$PROJECTS_DIR"
PROJECTS_DIR="$TEST_PROJECTS_DIR"
trap 'rm -rf "$TEST_PROJECTS_DIR"; PROJECTS_DIR="$ORIGINAL_PROJECTS_DIR"' EXIT

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Test helper functions
test_start() {
  echo -n "  Testing: $1 ... "
  ((TESTS_RUN++))
}

test_pass() {
  echo -e "${GREEN}PASS${NC}"
  ((TESTS_PASSED++))
}

test_fail() {
  echo -e "${RED}FAIL${NC}"
  echo "    Reason: $1"
  ((TESTS_FAILED++))
}

# Create test project
create_test_project() {
  local name="$1"
  mkdir -p "$PROJECTS_DIR/$name"
  echo "name: $name" > "$PROJECTS_DIR/$name/project.yml"
}

# =============================================================================
# Project Hold/Release Tests
# =============================================================================

echo ""
echo "========================================"
echo "  GSD Project Hold/Release Tests (FR-007)"
echo "========================================"
echo ""
echo "Test projects directory: $TEST_PROJECTS_DIR"
echo ""

# Test 1: gsd_project_hold succeeds for existing project
test_start "gsd_project_hold succeeds for existing project"
create_test_project "test-project-1"
LOCK_FILE=$(gsd_project_hold "test-project-1" 5)
RESULT=$?
if [ $RESULT -eq 0 ] && [ -n "$LOCK_FILE" ]; then
  gsd_project_release "$LOCK_FILE"
  test_pass
else
  test_fail "Expected success (0), got $RESULT"
fi

# Test 2: gsd_project_hold fails for non-existent project
test_start "gsd_project_hold fails for non-existent project"
LOCK_FILE=$(gsd_project_hold "nonexistent-project" 2 2>/dev/null)
RESULT=$?
if [ $RESULT -ne 0 ]; then
  test_pass
else
  gsd_project_release "$LOCK_FILE" 2>/dev/null
  test_fail "Expected failure (1), got success"
fi

# Test 3: Project directory protected while held
test_start "project cannot be modified while held"
create_test_project "test-project-2"
LOCK_FILE=$(gsd_project_hold "test-project-2" 5)

# Try to acquire lock from another "process" (same shell, but tests blocking)
(
  # This should fail/timeout because lock is held
  if gsd_project_hold "test-project-2" 1 >/dev/null 2>&1; then
    exit 0  # Acquired - unexpected
  else
    exit 1  # Blocked/timeout - expected
  fi
) &
BG_PID=$!
wait $BG_PID
BG_RESULT=$?

gsd_project_release "$LOCK_FILE"

if [ $BG_RESULT -eq 1 ]; then
  test_pass
else
  test_fail "Second process should have been blocked"
fi

# Test 4: gsd_project_release properly releases lock
test_start "gsd_project_release properly releases lock"
create_test_project "test-project-3"
LOCK_FILE=$(gsd_project_hold "test-project-3" 5)

# Release the lock
gsd_project_release "$LOCK_FILE"

# Now should be able to acquire again
LOCK_FILE2=$(gsd_project_hold "test-project-3" 2)
RESULT=$?

if [ $RESULT -eq 0 ]; then
  gsd_project_release "$LOCK_FILE2"
  test_pass
else
  test_fail "Could not re-acquire lock after release"
fi

# Test 5: Hold returns correct lock file path
test_start "hold returns correct lock file path"
create_test_project "test-project-4"
LOCK_FILE=$(gsd_project_hold "test-project-4" 5)

if [[ "$LOCK_FILE" == *"test-project-4/.project-lock" ]]; then
  gsd_project_release "$LOCK_FILE"
  test_pass
else
  gsd_project_release "$LOCK_FILE" 2>/dev/null
  test_fail "Lock file path incorrect: $LOCK_FILE"
fi

# Test 6: Empty project name returns error
test_start "empty project name returns error"
if gsd_project_hold "" 1 2>/dev/null; then
  test_fail "Should have failed with empty name"
else
  test_pass
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo ""
echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
echo -e "  Total:  $TESTS_RUN"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
else
  echo -e "${RED}Some tests failed.${NC}"
  exit 1
fi
