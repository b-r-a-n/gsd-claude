#!/bin/bash
#
# Test script for GSD locking utilities
# Run: ./scripts/test-lock.sh
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the lock utilities
source "$SCRIPT_DIR/lock.sh"

# Test directory
TEST_DIR=$(mktemp -d)
trap 'rm -rf "$TEST_DIR"' EXIT

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
# Lock Tests
# =============================================================================

echo ""
echo "================================"
echo "  GSD Lock Utility Tests"
echo "================================"
echo ""
echo "Platform: $GSD_PLATFORM"
echo "Test directory: $TEST_DIR"
echo ""

echo "--- Basic Lock Operations ---"

# Test 1: Basic lock acquire and release
test_start "basic lock acquire/release"
LOCK_FILE="$TEST_DIR/test1"
if gsd_lock_acquire "$LOCK_FILE" 5; then
  if [ -d "${LOCK_FILE}.lock" ]; then
    gsd_lock_release "$LOCK_FILE"
    if [ ! -d "${LOCK_FILE}.lock" ]; then
      test_pass
    else
      test_fail "Lock directory not removed after release"
    fi
  else
    test_fail "Lock directory not created"
  fi
else
  test_fail "Could not acquire lock"
fi

# Test 2: Lock check function
test_start "lock check function"
LOCK_FILE="$TEST_DIR/test2"
gsd_lock_acquire "$LOCK_FILE" 5
if gsd_lock_check "$LOCK_FILE"; then
  gsd_lock_release "$LOCK_FILE"
  if ! gsd_lock_check "$LOCK_FILE"; then
    test_pass
  else
    test_fail "Lock check returned true after release"
  fi
else
  test_fail "Lock check returned false while locked"
  gsd_lock_release "$LOCK_FILE"
fi

# Test 3: Lock holder PID
test_start "lock holder PID tracking"
LOCK_FILE="$TEST_DIR/test3"
gsd_lock_acquire "$LOCK_FILE" 5
HOLDER=$(gsd_lock_holder "$LOCK_FILE")
if [ "$HOLDER" = "$$" ]; then
  test_pass
else
  test_fail "Expected PID $$, got $HOLDER"
fi
gsd_lock_release "$LOCK_FILE"

# Test 4: Lock blocks second acquisition
test_start "lock blocks concurrent acquisition"
LOCK_FILE="$TEST_DIR/test4"
gsd_lock_acquire "$LOCK_FILE" 5

# Try to acquire in background with short timeout
(
  if gsd_lock_acquire "$LOCK_FILE" 1; then
    gsd_lock_release "$LOCK_FILE"
    exit 0  # Should not happen
  else
    exit 1  # Expected - timeout
  fi
) &
BG_PID=$!
wait $BG_PID
BG_RESULT=$?

gsd_lock_release "$LOCK_FILE"

if [ $BG_RESULT -eq 1 ]; then
  test_pass
else
  test_fail "Second process acquired lock (should have timed out)"
fi

# Test 5: Lock timeout
test_start "lock timeout works"
LOCK_FILE="$TEST_DIR/test5"
gsd_lock_acquire "$LOCK_FILE" 5

START=$(date +%s)
(gsd_lock_acquire "$LOCK_FILE" 2) &
BG_PID=$!
wait $BG_PID
END=$(date +%s)
ELAPSED=$((END - START))

gsd_lock_release "$LOCK_FILE"

if [ $ELAPSED -ge 1 ] && [ $ELAPSED -le 4 ]; then
  test_pass
else
  test_fail "Timeout took ${ELAPSED}s (expected ~2s)"
fi

# Test 6: Stale lock cleanup
test_start "stale lock detection and cleanup"
LOCK_FILE="$TEST_DIR/test6"
# Create a fake stale lock with a non-existent PID
mkdir -p "${LOCK_FILE}.lock"
echo "99999999" > "${LOCK_FILE}.lock/pid"

if gsd_lock_acquire "$LOCK_FILE" 2; then
  HOLDER=$(gsd_lock_holder "$LOCK_FILE")
  if [ "$HOLDER" = "$$" ]; then
    test_pass
  else
    test_fail "Lock acquired but PID wrong"
  fi
  gsd_lock_release "$LOCK_FILE"
else
  test_fail "Could not acquire lock over stale lock"
fi

echo ""
echo "--- Atomic Write Operations ---"

# Test 7: Basic atomic write
test_start "basic atomic write"
TEST_FILE="$TEST_DIR/atomic1.txt"
gsd_atomic_write "$TEST_FILE" "Hello, World!"
CONTENT=$(cat "$TEST_FILE")
if [ "$CONTENT" = "Hello, World!" ]; then
  test_pass
else
  test_fail "Content mismatch: '$CONTENT'"
fi

# Test 8: Atomic write with piped input
test_start "atomic write with piped input"
TEST_FILE="$TEST_DIR/atomic2.txt"
echo "Piped content" | gsd_atomic_write "$TEST_FILE"
CONTENT=$(cat "$TEST_FILE")
if [ "$CONTENT" = "Piped content" ]; then
  test_pass
else
  test_fail "Content mismatch: '$CONTENT'"
fi

# Test 9: Atomic write creates parent directories
test_start "atomic write creates directories"
TEST_FILE="$TEST_DIR/subdir/deep/atomic3.txt"
gsd_atomic_write "$TEST_FILE" "Nested content"
if [ -f "$TEST_FILE" ]; then
  test_pass
else
  test_fail "File not created in nested directory"
fi

# Test 10: Atomic write overwrites existing file
test_start "atomic write overwrites existing"
TEST_FILE="$TEST_DIR/atomic4.txt"
gsd_atomic_write "$TEST_FILE" "First"
gsd_atomic_write "$TEST_FILE" "Second"
CONTENT=$(cat "$TEST_FILE")
if [ "$CONTENT" = "Second" ]; then
  test_pass
else
  test_fail "Content not overwritten: '$CONTENT'"
fi

echo ""
echo "--- Locked Convenience Functions ---"

# Test 11: Locked write
test_start "locked write function"
TEST_FILE="$TEST_DIR/locked1.txt"
gsd_locked_write "$TEST_FILE" "Locked content"
CONTENT=$(cat "$TEST_FILE")
if [ "$CONTENT" = "Locked content" ] && ! gsd_lock_check "$TEST_FILE"; then
  test_pass
else
  test_fail "Content wrong or lock not released"
fi

# Test 12: Locked read
test_start "locked read function"
TEST_FILE="$TEST_DIR/locked2.txt"
echo "Read me" > "$TEST_FILE"
CONTENT=$(gsd_locked_read "$TEST_FILE")
if [ "$CONTENT" = "Read me" ]; then
  test_pass
else
  test_fail "Content mismatch: '$CONTENT'"
fi

# Test 13: Locked read of non-existent file
test_start "locked read non-existent file"
if gsd_locked_read "$TEST_DIR/nonexistent.txt" 2>/dev/null; then
  test_fail "Should have returned error"
else
  test_pass
fi

# Test 14: Locked update
test_start "locked update function"
TEST_FILE="$TEST_DIR/locked3.txt"
gsd_locked_write "$TEST_FILE" "old value"
gsd_locked_update "$TEST_FILE" sed 's/old/new/g'
CONTENT=$(cat "$TEST_FILE")
if [ "$CONTENT" = "new value" ]; then
  test_pass
else
  test_fail "Content not updated: '$CONTENT'"
fi

# Test 15: gsd_with_lock function
test_start "gsd_with_lock helper"
LOCK_FILE="$TEST_DIR/withlock"
RESULT=$(gsd_with_lock "$LOCK_FILE" echo "executed")
if [ "$RESULT" = "executed" ] && ! gsd_lock_check "$LOCK_FILE"; then
  test_pass
else
  test_fail "Command not executed or lock not released"
fi

echo ""
echo "--- Concurrent Write Test ---"

# Test 16: Concurrent atomic writes don't corrupt
test_start "concurrent writes don't corrupt"
TEST_FILE="$TEST_DIR/concurrent.txt"
gsd_atomic_write "$TEST_FILE" ""

# Start multiple background writers
for i in {1..5}; do
  (
    for j in {1..10}; do
      gsd_locked_write "$TEST_FILE" "Writer $i iteration $j"
    done
  ) &
done

# Wait for all writers
wait

# Check file is not corrupted (should have valid content)
CONTENT=$(cat "$TEST_FILE")
if [[ "$CONTENT" =~ ^Writer\ [0-9]+\ iteration\ [0-9]+$ ]]; then
  test_pass
else
  test_fail "File may be corrupted: '$CONTENT'"
fi

# =============================================================================
# Summary
# =============================================================================

echo ""
echo "================================"
echo "  Test Summary"
echo "================================"
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
