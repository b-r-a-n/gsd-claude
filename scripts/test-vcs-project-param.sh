#!/bin/bash
#
# Test script for VCS project parameter in vcs-atomic-commit (FR-008)
# Run: ./scripts/test-vcs-project-param.sh
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSD_DIR="$(dirname "$SCRIPT_DIR")"
export GSD_DIR

# Create temporary git repo for testing
TEST_REPO=$(mktemp -d)
trap 'rm -rf "$TEST_REPO"' EXIT

cd "$TEST_REPO" || exit 1
git init -q
git config user.email "test@example.com"
git config user.name "Test User"

# Create initial commit
echo "initial" > file.txt
git add file.txt
git commit -q -m "Initial commit"

# Source the git adapter directly since we're in a test git repo
source "$GSD_DIR/adapters/git-adapter.sh"

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

# =============================================================================
# VCS Project Parameter Tests
# =============================================================================

echo ""
echo "=========================================="
echo "  VCS Project Parameter Tests (FR-008)"
echo "=========================================="
echo ""
echo "Test repository: $TEST_REPO"
echo ""

# Test 1: Commit with explicit project parameter
test_start "commit with explicit project parameter"
echo "change1" > file.txt
git add file.txt
vcs-atomic-commit "feat" "1" "1.1" "test change" "explicit-project"
COMMIT_MSG=$(git log -1 --format=%s)
if [[ "$COMMIT_MSG" == "[explicit-project] feat(1-1.1): test change" ]]; then
  test_pass
else
  test_fail "Expected '[explicit-project]' in message, got: $COMMIT_MSG"
fi

# Test 2: Commit with different project name
test_start "commit with different project name"
echo "change2" > file.txt
git add file.txt
vcs-atomic-commit "fix" "2" "2.1" "another change" "other-project"
COMMIT_MSG=$(git log -1 --format=%s)
if [[ "$COMMIT_MSG" == "[other-project] fix(2-2.1): another change" ]]; then
  test_pass
else
  test_fail "Expected '[other-project]' in message, got: $COMMIT_MSG"
fi

# Test 3: Empty project parameter falls back (no tag if no active project)
test_start "empty project parameter uses fallback"
# Unset GSD_PROJECT if set, and ensure no .current-project file
unset GSD_PROJECT
rm -f "$HOME/.claude/planning/.current-project" 2>/dev/null

echo "change3" > file.txt
git add file.txt
vcs-atomic-commit "chore" "3" "3.1" "no project" ""
COMMIT_MSG=$(git log -1 --format=%s)
# Should either have no tag or have the active project tag
if [[ "$COMMIT_MSG" =~ (chore\(3-3\.1\):\ no\ project|\[.*\]\ chore\(3-3\.1\):\ no\ project) ]]; then
  test_pass
else
  test_fail "Unexpected message format: $COMMIT_MSG"
fi

# Test 4: Project with spaces works
test_start "project name with special characters"
echo "change4" > file.txt
git add file.txt
vcs-atomic-commit "docs" "4" "4.1" "docs update" "my-project-v2"
COMMIT_MSG=$(git log -1 --format=%s)
if [[ "$COMMIT_MSG" == "[my-project-v2] docs(4-4.1): docs update" ]]; then
  test_pass
else
  test_fail "Expected '[my-project-v2]' in message, got: $COMMIT_MSG"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "=========================================="
echo "  Test Summary"
echo "=========================================="
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
