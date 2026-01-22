#!/usr/bin/env bash
#
# GSD Verification Script
# Verifies the GSD installation is complete and functional
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GSD_DIR="$HOME/.claude/commands/gsd"
PLANNING_DIR="$HOME/.claude/planning/projects"

# Counters
ERRORS=0
WARNINGS=0
PASSES=0

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  GSD Verification              ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to print status and update counters
check_pass() {
    echo -e "  ${GREEN}[PASS]${NC} $1"
    ((PASSES++))
}

check_fail() {
    echo -e "  ${RED}[FAIL]${NC} $1"
    ((ERRORS++))
}

check_warn() {
    echo -e "  ${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

# ============================================
# Check Required Files
# ============================================
echo "Checking required files..."
echo ""

# Scripts
SCRIPTS=(
    "scripts/detect-vcs.sh"
    "scripts/project.sh"
    "scripts/vcs.sh"
    "scripts/lock.sh"
)

for script in "${SCRIPTS[@]}"; do
    if [[ -f "$GSD_DIR/$script" ]]; then
        check_pass "$script exists"
    else
        check_fail "$script missing"
    fi
done

echo ""

# Adapters
ADAPTERS=(
    "adapters/git-adapter.sh"
    "adapters/hg-adapter.sh"
    "adapters/vcs-interface.md"
)

for adapter in "${ADAPTERS[@]}"; do
    if [[ -f "$GSD_DIR/$adapter" ]]; then
        check_pass "$adapter exists"
    else
        check_fail "$adapter missing"
    fi
done

echo ""

# Commands
COMMANDS=(
    "commands/new-project.md"
    "commands/set-project.md"
    "commands/list-projects.md"
    "commands/discover-projects.md"
    "commands/map-codebase.md"
    "commands/plan-phase.md"
    "commands/execute-phase.md"
    "commands/verify-work.md"
    "commands/progress.md"
    "commands/pause-work.md"
    "commands/resume-work.md"
    "commands/quick.md"
)

for cmd in "${COMMANDS[@]}"; do
    if [[ -f "$GSD_DIR/$cmd" ]]; then
        check_pass "$cmd exists"
    else
        check_fail "$cmd missing"
    fi
done

echo ""

# Agents
AGENTS=(
    "agents/planner.md"
    "agents/executor.md"
    "agents/verifier.md"
    "agents/researcher.md"
    "agents/codebase-mapper.md"
)

for agent in "${AGENTS[@]}"; do
    if [[ -f "$GSD_DIR/$agent" ]]; then
        check_pass "$agent exists"
    else
        check_warn "$agent missing (optional)"
    fi
done

echo ""

# ============================================
# Check Scripts are Executable
# ============================================
echo "Checking script permissions..."
echo ""

EXECUTABLES=(
    "scripts/detect-vcs.sh"
    "scripts/project.sh"
    "scripts/vcs.sh"
    "scripts/lock.sh"
    "adapters/git-adapter.sh"
    "adapters/hg-adapter.sh"
)

for script in "${EXECUTABLES[@]}"; do
    if [[ -x "$GSD_DIR/$script" ]]; then
        check_pass "$script is executable"
    elif [[ -f "$GSD_DIR/$script" ]]; then
        check_warn "$script exists but is not executable"
    fi
done

echo ""

# ============================================
# Test VCS Detection
# ============================================
echo "Testing VCS detection..."
echo ""

if [[ -x "$GSD_DIR/scripts/detect-vcs.sh" ]]; then
    # Test in a git directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR" || exit 1

    # Initialize a test git repo
    if command -v git &> /dev/null; then
        git init -q . 2>/dev/null
        VCS_RESULT=$("$GSD_DIR/scripts/detect-vcs.sh" 2>/dev/null)
        if [[ "$VCS_RESULT" == "git" ]]; then
            check_pass "VCS detection works for git"
        else
            check_warn "VCS detection returned '$VCS_RESULT' instead of 'git'"
        fi
        rm -rf .git
    else
        check_warn "Git not installed, skipping git detection test"
    fi

    # Test in a hg directory
    if command -v hg &> /dev/null; then
        hg init . 2>/dev/null
        VCS_RESULT=$("$GSD_DIR/scripts/detect-vcs.sh" 2>/dev/null)
        if [[ "$VCS_RESULT" == "hg" ]]; then
            check_pass "VCS detection works for hg"
        else
            check_warn "VCS detection returned '$VCS_RESULT' instead of 'hg'"
        fi
        rm -rf .hg
    else
        check_warn "Mercurial not installed, skipping hg detection test"
    fi

    # Test in non-VCS directory
    VCS_RESULT=$("$GSD_DIR/scripts/detect-vcs.sh" 2>/dev/null)
    if [[ -z "$VCS_RESULT" ]] || [[ "$VCS_RESULT" == "none" ]]; then
        check_pass "VCS detection returns empty/none for non-VCS directory"
    else
        check_warn "VCS detection in non-VCS directory returned: '$VCS_RESULT'"
    fi

    # Cleanup
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
else
    check_fail "detect-vcs.sh not executable, cannot test VCS detection"
fi

echo ""

# ============================================
# Test project.sh Functions
# ============================================
echo "Testing project.sh functions..."
echo ""

if [[ -f "$GSD_DIR/scripts/project.sh" ]]; then
    # Source the script to test functions
    source "$GSD_DIR/scripts/project.sh" 2>/dev/null

    # Test ensure_planning_dirs
    if type ensure_planning_dirs &>/dev/null; then
        ensure_planning_dirs 2>/dev/null
        if [[ -d "$HOME/.claude/planning/projects" ]]; then
            check_pass "ensure_planning_dirs creates directory structure"
        else
            check_fail "ensure_planning_dirs did not create expected directories"
        fi
    else
        check_warn "ensure_planning_dirs function not found"
    fi

    # Test list_projects
    if type list_projects &>/dev/null; then
        # This should run without error
        list_projects &>/dev/null
        if [[ $? -eq 0 ]]; then
            check_pass "list_projects function runs without error"
        else
            check_warn "list_projects function returned non-zero exit code"
        fi
    else
        check_warn "list_projects function not found"
    fi

    # Test get_project_planning_dir if it exists
    if type get_project_planning_dir &>/dev/null; then
        check_pass "get_project_planning_dir function exists"
    else
        check_warn "get_project_planning_dir function not found (optional)"
    fi

else
    check_fail "project.sh not found"
fi

echo ""

# ============================================
# Check Planning Directory
# ============================================
echo "Checking planning directory..."
echo ""

if [[ -d "$PLANNING_DIR" ]]; then
    check_pass "Planning directory exists at $PLANNING_DIR"
else
    check_warn "Planning directory not found (will be created on first use)"
fi

echo ""

# ============================================
# Summary
# ============================================
echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  Verification Summary          ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""
echo -e "  ${GREEN}Passed:${NC}   $PASSES"
echo -e "  ${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "  ${RED}Errors:${NC}   $ERRORS"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}All checks passed! GSD is ready to use.${NC}"
    else
        echo -e "${GREEN}GSD is functional with $WARNINGS warning(s).${NC}"
    fi
    echo ""
    exit 0
else
    echo -e "${RED}Verification failed with $ERRORS error(s).${NC}"
    echo "Please run install.sh to fix missing components."
    echo ""
    exit 1
fi
