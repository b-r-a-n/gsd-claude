#!/bin/bash
# VCS dispatcher - routes commands to the appropriate adapter

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GSD_DIR="$(dirname "$SCRIPT_DIR")"
export GSD_DIR
ADAPTER_DIR="$GSD_DIR/adapters"

# Detect VCS type
VCS_TYPE=$("$SCRIPT_DIR/detect-vcs.sh")

case "$VCS_TYPE" in
  git)
    source "$ADAPTER_DIR/git-adapter.sh"
    ;;
  hg)
    source "$ADAPTER_DIR/hg-adapter.sh"
    ;;
  none)
    echo "Error: No VCS detected in current directory" >&2
    exit 1
    ;;
  *)
    echo "Error: Unknown VCS type: $VCS_TYPE" >&2
    exit 1
    ;;
esac

# Execute the requested command
if [ $# -eq 0 ]; then
  echo "Usage: vcs.sh <command> [args...]"
  echo ""
  echo "Available commands:"
  echo "  vcs-status        Show working directory status"
  echo "  vcs-branch        Show current branch/bookmark"
  echo "  vcs-dirty         Exit 0 if clean, 1 if dirty"
  echo "  vcs-stage <file>  Stage file for commit"
  echo "  vcs-unstage <file> Unstage file"
  echo "  vcs-commit <msg>  Create commit"
  echo "  vcs-atomic-commit <type> <phase> <task> <desc>  Formatted commit"
  echo "  vcs-log [n]       Show last n commits"
  echo "  vcs-diff [file]   Show uncommitted changes"
  echo "  vcs-diff-staged   Show staged changes"
  echo "  vcs-bisect-start  Start bisect"
  echo "  vcs-bisect-good   Mark good revision"
  echo "  vcs-bisect-bad    Mark bad revision"
  echo "  vcs-bisect-reset  End bisect"
  echo "  vcs-root          Show repository root"
  echo "  vcs-current-rev   Show current revision"
  echo "  vcs-has-commits   Exit 0 if repo has commits"
  exit 0
fi

"$@"
