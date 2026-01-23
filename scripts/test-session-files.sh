#!/bin/bash
#
# Test script for session file uniqueness (FR-009)
# Run: ./scripts/test-session-files.sh
#

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

# Function to generate session ID (same as in pause-work.md)
generate_session_id() {
  # Generate unique session ID: YYYY-MM-DD-HHMMSS-XXXX (XXXX = 4 random hex chars)
  echo "$(date +%Y-%m-%d-%H%M%S)-$(head -c 2 /dev/urandom | xxd -p)"
}

# =============================================================================
# Session File Uniqueness Tests
# =============================================================================

echo ""
echo "=========================================="
echo "  Session File Uniqueness Tests (FR-009)"
echo "=========================================="
echo ""

# Test 1: Session ID format is correct
test_start "session ID format matches expected pattern"
SESSION_ID=$(generate_session_id)
# Expected format: YYYY-MM-DD-HHMMSS-XXXX (where XXXX is 4 hex chars)
if [[ "$SESSION_ID" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}-[0-9a-f]{4}$ ]]; then
  test_pass
else
  test_fail "Format incorrect: $SESSION_ID"
fi

# Test 2: Session IDs include seconds
test_start "session ID includes seconds"
SESSION_ID=$(generate_session_id)
# Extract the time portion (after the date, before the random suffix)
TIME_PART=$(echo "$SESSION_ID" | cut -d'-' -f4)
if [ ${#TIME_PART} -eq 6 ]; then
  test_pass
else
  test_fail "Time part should be 6 digits (HHMMSS), got: $TIME_PART"
fi

# Test 3: Session IDs include random suffix
test_start "session ID includes random suffix"
SESSION_ID=$(generate_session_id)
SUFFIX=$(echo "$SESSION_ID" | cut -d'-' -f5)
if [ ${#SUFFIX} -eq 4 ] && [[ "$SUFFIX" =~ ^[0-9a-f]+$ ]]; then
  test_pass
else
  test_fail "Random suffix should be 4 hex chars, got: $SUFFIX"
fi

# Test 4: Generate 100 unique session IDs
test_start "100 generated session IDs are all unique"
# Use a temp file instead of associative array for compatibility
TEMP_IDS=$(mktemp)
DUPLICATES=0

for i in {1..100}; do
  SESSION_ID=$(generate_session_id)
  if grep -q "^${SESSION_ID}$" "$TEMP_IDS" 2>/dev/null; then
    ((DUPLICATES++))
  fi
  echo "$SESSION_ID" >> "$TEMP_IDS"
done
rm -f "$TEMP_IDS"

if [ $DUPLICATES -eq 0 ]; then
  test_pass
else
  test_fail "Found $DUPLICATES duplicate session IDs"
fi

# Test 5: Rapid generation produces unique IDs
test_start "rapid generation in same second produces unique IDs"
TEMP_IDS=$(mktemp)
DUPLICATES=0

# Generate 20 IDs as fast as possible
for i in {1..20}; do
  SESSION_ID=$(generate_session_id)
  if grep -q "^${SESSION_ID}$" "$TEMP_IDS" 2>/dev/null; then
    ((DUPLICATES++))
  fi
  echo "$SESSION_ID" >> "$TEMP_IDS"
done
rm -f "$TEMP_IDS"

if [ $DUPLICATES -eq 0 ]; then
  test_pass
else
  test_fail "Found $DUPLICATES duplicate session IDs in rapid generation"
fi

# Test 6: Session filename would be valid
test_start "session filename is valid for filesystem"
SESSION_ID=$(generate_session_id)
FILENAME="session-${SESSION_ID}.md"
# Check for invalid characters
if [[ "$FILENAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  test_pass
else
  test_fail "Filename contains invalid characters: $FILENAME"
fi

# Test 7: Old format still matches glob pattern
test_start "old format (session-YYYY-MM-DD-HHMM.md) matches pattern"
OLD_FORMAT="session-2024-01-15-1430.md"
if [[ "$OLD_FORMAT" == session-*.md ]]; then
  test_pass
else
  test_fail "Old format should match session-*.md pattern"
fi

# Test 8: New format matches glob pattern
test_start "new format matches pattern"
NEW_FORMAT="session-2024-01-15-143022-a1b2.md"
if [[ "$NEW_FORMAT" == session-*.md ]]; then
  test_pass
else
  test_fail "New format should match session-*.md pattern"
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
