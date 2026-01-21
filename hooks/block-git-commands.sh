#!/bin/bash
# block-git-commands.sh - PreToolUse hook for babyclaude agent
# Blocks ALL git commands. Exit 2 = block, stderr fed back to Claude.

# Read JSON input from stdin
INPUT=$(cat)

# Extract the command field from tool_input
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
    exit 0
fi

# Block any git commands:
# - Starts with "git "
# - Contains "| git " (piped)
# - Contains "&& git " or "; git " (chained)
# - Contains "$(git " (subshell)
if echo "$COMMAND" | grep -qE '(^git\s|[|;&]\s*git\s|\$\(git\s)'; then
    echo "Git commands are not permitted. You work in an isolated worktree - the orchestrator handles all git operations (commit, merge, push)." >&2
    exit 2
fi

exit 0
