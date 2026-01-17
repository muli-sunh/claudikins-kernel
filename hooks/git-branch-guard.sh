#!/bin/bash
# git-branch-guard.sh - PreToolUse hook for /execute
# Blocks dangerous git operations during task execution.
#
# Matcher: Bash (only checks bash commands)
# Exit codes:
#   0 - Command allowed
#   2 - Command blocked (dangerous git operation)

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/execute-state.json"

# Read input JSON from stdin
INPUT=$(cat)

# Extract tool name
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# Only check Bash tool
if [ "$TOOL_NAME" != "Bash" ]; then
    exit 0
fi

# Check if we're in an active execution session
if [ ! -f "$STATE_FILE" ]; then
    exit 0  # No active session, allow all
fi

STATUS=$(jq -r '.status // ""' "$STATE_FILE" 2>/dev/null || echo "")
if [ "$STATUS" != "executing" ]; then
    exit 0  # Not actively executing, allow all
fi

# Extract the command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# Skip if not a git command
if ! echo "$COMMAND" | grep -qE '^\s*git\s'; then
    exit 0
fi

# Dangerous git operations to block during execution
# These patterns could corrupt task branches or lose work

# Pattern: git checkout without -b (switching branches)
# Note: Split into two conditions - grep -E doesn't support Perl lookaheads
if echo "$COMMAND" | grep -qE 'git\s+checkout\s' && ! echo "$COMMAND" | grep -qE 'git\s+checkout\s+-b'; then
    # Allow checkout of specific files (git checkout -- file)
    if ! echo "$COMMAND" | grep -qE 'git\s+checkout\s+--\s'; then
        echo "BLOCKED: Branch switching during task execution" >&2
        echo "" >&2
        echo "Command: $COMMAND" >&2
        echo "" >&2
        echo "During /execute, agents must stay on their task branch." >&2
        echo "Allowed: git checkout -b <new-branch> (create new)" >&2
        echo "Allowed: git checkout -- <file> (restore file)" >&2
        echo "" >&2
        echo "If you need to switch branches, abort the task first." >&2
        exit 2
    fi
fi

# Pattern: git switch (always switches branches)
if echo "$COMMAND" | grep -qE 'git\s+switch\s'; then
    echo "BLOCKED: Branch switching during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "During /execute, agents must stay on their task branch." >&2
    exit 2
fi

# Pattern: git reset --hard (destructive)
if echo "$COMMAND" | grep -qE 'git\s+reset\s+--hard'; then
    echo "BLOCKED: Destructive reset during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Hard reset would destroy uncommitted work." >&2
    echo "If you need to undo changes, use: git checkout -- <file>" >&2
    exit 2
fi

# Pattern: git clean -fd (deletes untracked files)
if echo "$COMMAND" | grep -qE 'git\s+clean\s+-[fd]'; then
    echo "BLOCKED: Destructive clean during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "This would delete untracked files which may include new work." >&2
    exit 2
fi

# Pattern: git push --force (rewrites history)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*--force'; then
    echo "BLOCKED: Force push during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Force pushing rewrites remote history and is not allowed during execution." >&2
    exit 2
fi

# Pattern: git rebase (history rewrite)
if echo "$COMMAND" | grep -qE 'git\s+rebase'; then
    echo "BLOCKED: Rebase during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Rebasing changes history and could cause merge conflicts." >&2
    echo "Rebasing is done at merge time, not during task execution." >&2
    exit 2
fi

# Pattern: git merge (could cause conflicts mid-task)
if echo "$COMMAND" | grep -qE 'git\s+merge'; then
    echo "BLOCKED: Merge during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Merging is done at batch completion, not during task execution." >&2
    echo "Complete your task first, then merging happens at checkpoint." >&2
    exit 2
fi

# Pattern: git stash (could lose work)
if echo "$COMMAND" | grep -qE 'git\s+stash'; then
    echo "BLOCKED: Stash during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Stashing during execution could lose track of work." >&2
    echo "Commit your changes instead: git add && git commit" >&2
    exit 2
fi

# Pattern: git branch -d or -D (delete branch)
if echo "$COMMAND" | grep -qE 'git\s+branch\s+-[dD]'; then
    echo "BLOCKED: Branch deletion during task execution" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Branch cleanup happens after batch completion, not during execution." >&2
    exit 2
fi

# Pattern: git push to protected branches (main, master, develop)
if echo "$COMMAND" | grep -qE 'git\s+push\s+.*(main|master|develop)'; then
    echo "BLOCKED: Direct push to protected branch" >&2
    echo "" >&2
    echo "Command: $COMMAND" >&2
    echo "" >&2
    echo "Direct pushes to main/master/develop are not allowed." >&2
    echo "Work on your task branch. Merging happens at checkpoint." >&2
    exit 2
fi

# Command is safe - allow it
exit 0
