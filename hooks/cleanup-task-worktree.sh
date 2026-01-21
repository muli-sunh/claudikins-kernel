#!/bin/bash
# cleanup-task-worktree.sh - Utility script for worktree cleanup
# Called by orchestrator after task is fully resolved (merged or abandoned).
# NOT auto-triggered by hook event - orchestrator decides when to call.
#
# Usage: cleanup-task-worktree.sh <task_id>
# Exit codes:
#   0 - Cleanup successful
#   1 - Cleanup failed (non-blocking, just warning)

set -euo pipefail

TASK_ID="${1:-}"

if [ -z "$TASK_ID" ]; then
    echo "Usage: cleanup-task-worktree.sh <task_id>" >&2
    exit 1
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.claude/execute-state.json"
WORKTREE_BASE="/tmp/kernel-worktrees"

# Get worktree path from state file
WORKTREE_PATH=""
if [ -f "$STATE_FILE" ]; then
    WORKTREE_PATH=$(jq -r --arg taskId "$TASK_ID" \
        '.tasks[] | select(.id == $taskId) | .worktree_path // empty' \
        "$STATE_FILE")
fi

# If not in state, try to find by pattern
if [ -z "$WORKTREE_PATH" ]; then
    WORKTREE_PATH=$(find "$WORKTREE_BASE" -maxdepth 1 -type d -name "task-${TASK_ID}-*" 2>/dev/null | head -1)
fi

if [ -z "$WORKTREE_PATH" ] || [ ! -d "$WORKTREE_PATH" ]; then
    echo "No worktree found for task ${TASK_ID} - may already be cleaned up" >&2
    exit 0
fi

# Get branch name for this worktree
BRANCH_NAME=$(git worktree list --porcelain | grep -A2 "worktree $WORKTREE_PATH" | grep "branch" | sed 's/branch refs\/heads\///' || echo "")

# Remove worktree
echo "Removing worktree: $WORKTREE_PATH"
if git worktree remove "$WORKTREE_PATH" --force 2>/dev/null; then
    echo "Worktree removed successfully"
else
    # Force remove if git worktree remove fails
    rm -rf "$WORKTREE_PATH" 2>/dev/null || true
    git worktree prune 2>/dev/null || true
    echo "Worktree force-removed"
fi

# Optionally delete the branch if it was merged
# (Don't delete if not merged - keeps history)
if [ -n "$BRANCH_NAME" ]; then
    # Check if branch is merged to main/master
    MAIN_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

    if git branch --merged "$MAIN_BRANCH" 2>/dev/null | grep -q "$BRANCH_NAME"; then
        echo "Deleting merged branch: $BRANCH_NAME"
        git branch -d "$BRANCH_NAME" 2>/dev/null || true
    else
        echo "Keeping unmerged branch: $BRANCH_NAME"
    fi
fi

# Update state file to clear worktree path
if [ -f "$STATE_FILE" ]; then
    jq --arg taskId "$TASK_ID" \
       '.tasks = [.tasks[] | if .id == $taskId then del(.worktree_path) else . end]' \
       "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

echo "Cleanup complete for task ${TASK_ID}"
exit 0
