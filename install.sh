#!/usr/bin/env bash
#
# GSD Installation Script
# Installs GSD - Get Shit Done for Claude Code
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GSD_REPO="https://github.com/b-r-a-n/gsd-claude.git"
GSD_DIR="$HOME/.claude/commands/gsd"
PLANNING_DIR="$HOME/.claude/planning/projects"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  GSD - Get Shit Done Installer ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Function to print status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "ok")
            echo -e "  ${GREEN}[OK]${NC} $message"
            ;;
        "fail")
            echo -e "  ${RED}[FAIL]${NC} $message"
            ;;
        "warn")
            echo -e "  ${YELLOW}[WARN]${NC} $message"
            ;;
        "info")
            echo -e "  ${BLUE}[INFO]${NC} $message"
            ;;
    esac
}

# Check prerequisites
echo "Checking prerequisites..."
echo ""

PREREQ_FAILED=0

# Check Bash version
BASH_VERSION_NUM="${BASH_VERSION%%[^0-9.]*}"
BASH_MAJOR="${BASH_VERSION_NUM%%.*}"
if [[ "$BASH_MAJOR" -ge 4 ]]; then
    print_status "ok" "Bash version $BASH_VERSION_NUM (4.0+ required)"
else
    print_status "fail" "Bash version $BASH_VERSION_NUM (4.0+ required)"
    PREREQ_FAILED=1
fi

# Check for Git or Mercurial
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    print_status "ok" "Git installed (version $GIT_VERSION)"
    HAS_VCS=1
elif command -v hg &> /dev/null; then
    HG_VERSION=$(hg --version | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
    print_status "ok" "Mercurial installed (version $HG_VERSION)"
    HAS_VCS=1
else
    print_status "fail" "No VCS found (Git or Mercurial required)"
    PREREQ_FAILED=1
fi

# Check for both VCS if available
if command -v git &> /dev/null && command -v hg &> /dev/null; then
    print_status "ok" "Both Git and Mercurial available"
fi

# Check for shasum
if command -v shasum &> /dev/null; then
    print_status "ok" "shasum available"
elif command -v sha256sum &> /dev/null; then
    print_status "ok" "sha256sum available (will use as shasum alternative)"
else
    print_status "warn" "shasum not found (optional, used for checksums)"
fi

echo ""

# Exit if prerequisites failed
if [[ $PREREQ_FAILED -eq 1 ]]; then
    echo -e "${RED}Prerequisites check failed. Please install missing dependencies.${NC}"
    exit 1
fi

echo -e "${GREEN}All prerequisites met!${NC}"
echo ""

# Create directories
echo "Creating directories..."

# Create ~/.claude/commands/ if it doesn't exist
if [[ ! -d "$HOME/.claude/commands" ]]; then
    mkdir -p "$HOME/.claude/commands"
    print_status "ok" "Created ~/.claude/commands/"
else
    print_status "info" "~/.claude/commands/ already exists"
fi

# Create planning directories
if [[ ! -d "$PLANNING_DIR" ]]; then
    mkdir -p "$PLANNING_DIR"
    print_status "ok" "Created ~/.claude/planning/projects/"
else
    print_status "info" "~/.claude/planning/projects/ already exists"
fi

echo ""

# Clone or update repository
echo "Installing GSD..."

if [[ -d "$GSD_DIR" ]]; then
    print_status "info" "GSD directory exists, checking for updates..."
    if [[ -d "$GSD_DIR/.git" ]]; then
        cd "$GSD_DIR"
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || print_status "warn" "Could not pull updates"
        cd - > /dev/null
    else
        print_status "warn" "Existing installation is not a git repo, skipping update"
    fi
else
    echo "Cloning from $GSD_REPO..."
    git clone "$GSD_REPO" "$GSD_DIR"
    print_status "ok" "Cloned GSD repository"
fi

echo ""

# Make scripts executable
echo "Setting permissions..."

# Make all .sh files in scripts/ executable
if [[ -d "$GSD_DIR/scripts" ]]; then
    chmod +x "$GSD_DIR/scripts"/*.sh 2>/dev/null || true
    print_status "ok" "Made scripts/*.sh executable"
fi

# Make all .sh files in adapters/ executable
if [[ -d "$GSD_DIR/adapters" ]]; then
    chmod +x "$GSD_DIR/adapters"/*.sh 2>/dev/null || true
    print_status "ok" "Made adapters/*.sh executable"
fi

# Make install/uninstall/verify scripts executable
chmod +x "$GSD_DIR/install.sh" 2>/dev/null || true
chmod +x "$GSD_DIR/uninstall.sh" 2>/dev/null || true
chmod +x "$GSD_DIR/verify.sh" 2>/dev/null || true
print_status "ok" "Made management scripts executable"

echo ""

# Run verification
echo "Running verification..."
echo ""

if [[ -x "$GSD_DIR/verify.sh" ]]; then
    "$GSD_DIR/verify.sh" || true
else
    print_status "warn" "verify.sh not found or not executable"
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Installation Complete!        ${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "Next steps:"
echo ""
echo "  1. Start Claude Code in your project directory"
echo ""
echo "  2. Create your first GSD project:"
echo "     /gsd:commands:new-project"
echo ""
echo "  3. Plan your first phase:"
echo "     /gsd:commands:plan-phase 1"
echo ""
echo "  4. Execute the phase:"
echo "     /gsd:commands:execute-phase"
echo ""
echo "For quick start guide, see: ~/.claude/commands/gsd/QUICKSTART.md"
echo ""
