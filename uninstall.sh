#!/usr/bin/env bash
#
# GSD Uninstallation Script
# Removes GSD - Get Shit Done for Claude Code
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GSD_DIR="$HOME/.claude/commands/gsd"
PLANNING_DIR="$HOME/.claude/planning"
PROJECTS_DIR="$HOME/.claude/planning/projects"

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}  GSD Uninstaller               ${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Check if GSD is installed
if [[ ! -d "$GSD_DIR" ]]; then
    echo -e "${YELLOW}GSD does not appear to be installed at $GSD_DIR${NC}"
    exit 0
fi

# Confirmation prompt
echo -e "${YELLOW}WARNING: This will remove GSD from your system.${NC}"
echo ""
echo "The following will be removed:"
echo "  - $GSD_DIR"
echo ""
read -p "Are you sure you want to uninstall GSD? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""

# Check for project data
if [[ -d "$PROJECTS_DIR" ]] && [[ "$(ls -A "$PROJECTS_DIR" 2>/dev/null)" ]]; then
    echo -e "${YELLOW}Found existing project data in $PROJECTS_DIR${NC}"
    echo ""

    # List projects
    echo "Projects found:"
    for project in "$PROJECTS_DIR"/*; do
        if [[ -d "$project" ]]; then
            echo "  - $(basename "$project")"
        fi
    done
    echo ""

    # Offer backup
    read -p "Would you like to backup your project data before uninstalling? [Y/n] " -n 1 -r
    echo ""

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        BACKUP_DIR="$HOME/gsd-backup-$(date +%Y%m%d-%H%M%S)"
        echo "Backing up to $BACKUP_DIR..."
        mkdir -p "$BACKUP_DIR"
        cp -r "$PROJECTS_DIR" "$BACKUP_DIR/"
        echo -e "${GREEN}Backup created at: $BACKUP_DIR${NC}"
        echo ""
    fi
fi

# Remove GSD directory
echo "Removing GSD installation..."
rm -rf "$GSD_DIR"
echo -e "${GREEN}Removed $GSD_DIR${NC}"

# Ask about planning directory
if [[ -d "$PLANNING_DIR" ]]; then
    echo ""
    echo "The planning directory still exists at: $PLANNING_DIR"
    echo ""
    read -p "Would you like to remove the planning directory as well? [y/N] " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Double-check if there's data
        if [[ -d "$PROJECTS_DIR" ]] && [[ "$(ls -A "$PROJECTS_DIR" 2>/dev/null)" ]]; then
            echo -e "${YELLOW}WARNING: This will permanently delete all project planning data!${NC}"
            read -p "Are you absolutely sure? [y/N] " -n 1 -r
            echo ""

            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$PLANNING_DIR"
                echo -e "${GREEN}Removed $PLANNING_DIR${NC}"
            else
                echo "Kept planning directory."
            fi
        else
            rm -rf "$PLANNING_DIR"
            echo -e "${GREEN}Removed $PLANNING_DIR${NC}"
        fi
    else
        echo "Kept planning directory."
    fi
fi

echo ""
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}  Uninstallation Complete       ${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "GSD has been removed from your system."
echo ""

if [[ -n "$BACKUP_DIR" ]] && [[ -d "$BACKUP_DIR" ]]; then
    echo "Your project data backup is at: $BACKUP_DIR"
    echo ""
fi

echo "To reinstall GSD:"
echo "  git clone https://github.com/username/gsd-claude.git ~/.claude/commands/gsd"
echo "  cd ~/.claude/commands/gsd && ./install.sh"
echo ""
