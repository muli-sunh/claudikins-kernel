#!/bin/bash
# execute-status.sh - UserPromptSubmit hook for /execute --status
# Shows current execution status when user requests it.
#
# Exit codes:
#   0 - Always (adds context, never blocks)

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
STATE_FILE="$CLAUDE_DIR/execute-state.json"

# Read input JSON from stdin
INPUT=$(cat)

# Extract prompt from JSON
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""')

# Only respond to /execute --status or /execute status
if ! echo "$PROMPT" | grep -qiE '^/execute.*(--status|status)'; then
    exit 0
fi

# Check if state file exists
if [ ! -f "$STATE_FILE" ]; then
    cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": "No active execution session found. Run /execute <plan.md> to start."
  }
}
EOF
    exit 0
fi

# Read state file
STATE=$(cat "$STATE_FILE")

# Extract key information
SESSION_ID=$(echo "$STATE" | jq -r '.session_id // "unknown"')
PLAN_SOURCE=$(echo "$STATE" | jq -r '.plan_source // "unknown"')
STARTED_AT=$(echo "$STATE" | jq -r '.started_at // "unknown"')
CURRENT_BATCH=$(echo "$STATE" | jq -r '.current_batch // 0')
TOTAL_BATCHES=$(echo "$STATE" | jq -r '.batches | length // 0')
STATUS=$(echo "$STATE" | jq -r '.status // "unknown"')

# Count tasks by status
TOTAL_TASKS=$(echo "$STATE" | jq -r '.tasks | length // 0')
COMPLETED_TASKS=$(echo "$STATE" | jq -r '[.tasks[] | select(.status == "completed")] | length // 0')
IN_PROGRESS_TASKS=$(echo "$STATE" | jq -r '[.tasks[] | select(.status == "in_progress")] | length // 0')
BLOCKED_TASKS=$(echo "$STATE" | jq -r '[.tasks[] | select(.status == "blocked")] | length // 0')
PENDING_TASKS=$(echo "$STATE" | jq -r '[.tasks[] | select(.status == "pending")] | length // 0')

# Get current batch tasks
CURRENT_BATCH_TASKS=$(echo "$STATE" | jq -r --argjson batch "$CURRENT_BATCH" '.batches[$batch - 1].tasks // [] | join(", ")' 2>/dev/null || echo "none")

# Calculate age
if [ "$STARTED_AT" != "unknown" ] && [ "$STARTED_AT" != "null" ]; then
    START_EPOCH=$(date -d "$STARTED_AT" +%s 2>/dev/null || echo "0")
    NOW_EPOCH=$(date +%s)
    AGE_MINUTES=$(( (NOW_EPOCH - START_EPOCH) / 60 ))
    AGE_DISPLAY="${AGE_MINUTES}m ago"
else
    AGE_DISPLAY="unknown"
fi

# Build status summary
read -r -d '' STATUS_SUMMARY << EOM || true
## Execution Status

**Session:** ${SESSION_ID}
**Plan:** ${PLAN_SOURCE}
**Started:** ${AGE_DISPLAY}
**Status:** ${STATUS}

### Progress

| Metric | Count |
|--------|-------|
| Total tasks | ${TOTAL_TASKS} |
| Completed | ${COMPLETED_TASKS} |
| In progress | ${IN_PROGRESS_TASKS} |
| Blocked | ${BLOCKED_TASKS} |
| Pending | ${PENDING_TASKS} |

### Current Batch

Batch ${CURRENT_BATCH}/${TOTAL_BATCHES}: ${CURRENT_BATCH_TASKS}
EOM

# Escape for JSON
STATUS_ESCAPED=$(echo "$STATUS_SUMMARY" | jq -Rs '.')

# Output context injection
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "UserPromptSubmit",
    "additionalContext": ${STATUS_ESCAPED}
  }
}
EOF

exit 0
