#!/bin/bash
# create-task-branch.sh - SubagentStart hook for /execute
# Creates git branch when babyclaude spawns for task execution.
#
# Matcher: babyclaude (only triggers for this agent type)
# Exit codes:
#   0 - Branch created successfully (context added)
#   2 - Branch creation failed (blocks agent spawn, informs user)

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/execute-state.json"

# Read input JSON from stdin
INPUT=$(cat)

# Extract agent name
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // ""')

# Only act on babyclaude spawns
if [ "$AGENT_NAME" != "babyclaude" ]; then
    exit 0
fi

# Extract task info from prompt (passed by execute command)
# Format expected: TASK_ID: <id> TASK_SLUG: <slug>
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')
TASK_ID=$(echo "$PROMPT" | grep -oP 'TASK_ID:\s*\K[^\s]+' || echo "")
TASK_SLUG=$(echo "$PROMPT" | grep -oP 'TASK_SLUG:\s*\K[^\s]+' || echo "unknown")

# If no task ID, this isn't a task execution - allow spawn
if [ -z "$TASK_ID" ]; then
    exit 0
fi

# Verify we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "ERROR: Not in a git repository. Cannot create task branch." >&2
    echo "" >&2
    echo "The /execute command requires a git repository to manage task branches." >&2
    echo "Run 'git init' first, or navigate to an existing repository." >&2
    exit 2
fi

# Check for uncommitted changes that would prevent branch creation
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "ERROR: Uncommitted changes detected. Cannot create task branch." >&2
    echo "" >&2
    echo "Please commit or stash your changes before running /execute:" >&2
    echo "  git stash        # Temporarily store changes" >&2
    echo "  git commit -am 'WIP'  # Commit changes" >&2
    exit 2
fi

# Generate UUID suffix for collision prevention (per branch-collision-detection.md)
UUID_SUFFIX=$(uuidgen | cut -d'-' -f1)

# Create branch name: execute/task-{id}-{slug}-{uuid}
BRANCH_NAME="execute/task-${TASK_ID}-${TASK_SLUG}-${UUID_SUFFIX}"

# Attempt to create and checkout branch
if GIT_OUTPUT=$(git checkout -b "$BRANCH_NAME" 2>&1); then
    # Update state file with branch info
    if [ -f "$STATE_FILE" ]; then
        jq --arg branch "$BRANCH_NAME" --arg taskId "$TASK_ID" \
           '.tasks = [.tasks[] | if .id == $taskId then .branch = $branch else . end]' \
           "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi

    # Output context for babyclaude
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SubagentStart",
    "additionalContext": "You are working on branch: ${BRANCH_NAME}\n\nCommit all changes to this branch. Do not switch branches."
  }
}
EOF
    exit 0
else
    # Branch creation failed - block and inform user
    echo "ERROR: Failed to create task branch: $BRANCH_NAME" >&2
    echo "Git error: $GIT_OUTPUT" >&2
    echo "" >&2
    echo "Possible causes:" >&2
    echo "  - Branch name already exists (collision despite UUID - very rare)" >&2
    echo "  - Git repository is in a bad state" >&2
    echo "  - Insufficient permissions" >&2
    echo "" >&2
    echo "To recover:" >&2
    echo "  1. Check git status: git status" >&2
    echo "  2. List existing branches: git branch -a | grep execute/" >&2
    echo "  3. If stuck, try: git checkout main && git branch -D <stuck-branch>" >&2
    exit 2
fi
