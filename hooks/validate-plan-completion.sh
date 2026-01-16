#!/bin/bash
# validate-plan-completion.sh - Stop hook for claudikins-kernel
# Validates plan session completion when main agent stops
#
# Checks if an active planning session exists and whether it completed properly.
# Provides feedback to Claude if plan is incomplete.

set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
PLAN_STATE="$CLAUDE_DIR/plan-state.json"

# Read input from stdin (Stop hook receives session info)
INPUT=$(cat)

# If no plan state exists, nothing to validate
if [ ! -f "$PLAN_STATE" ]; then
    exit 0
fi

# Read current state
STATUS=$(jq -r '.status // "unknown"' "$PLAN_STATE" 2>/dev/null || echo "unknown")
PHASE=$(jq -r '.phase // "unknown"' "$PLAN_STATE" 2>/dev/null || echo "unknown")
SESSION_ID=$(jq -r '.session_id // "unknown"' "$PLAN_STATE" 2>/dev/null || echo "unknown")

# If session is already completed or abandoned, nothing to check
if [ "$STATUS" = "completed" ] || [ "$STATUS" = "abandoned" ]; then
    exit 0
fi

# If session is active and we're stopping, check if plan is complete
if [ "$STATUS" = "active" ] || [ "$STATUS" = "interrupted" ]; then
    # Check what phase we're in
    case "$PHASE" in
        "review"|"completed")
            # Plan reached final phase, mark as complete
            jq '.status = "completed" | .completed_at = now | .completed_at = (now | strftime("%Y-%m-%dT%H:%M:%SZ"))' "$PLAN_STATE" > "${PLAN_STATE}.tmp" 2>/dev/null && \
                mv "${PLAN_STATE}.tmp" "$PLAN_STATE" || true
            ;;
        "brain-jam"|"research"|"approaches"|"draft")
            # Plan is incomplete - provide feedback to Claude
            cat <<EOF
{
  "decision": "block",
  "reason": "Planning session ${SESSION_ID} is incomplete (phase: ${PHASE}). Please complete the plan or explicitly abandon it before stopping.",
  "systemMessage": "Active planning session detected in '${PHASE}' phase. Options: (1) Continue to complete the plan, (2) Use AskUserQuestion to confirm abandonment, (3) Mark session as paused for later resume."
}
EOF
            exit 2
            ;;
        *)
            # Unknown phase, don't block
            ;;
    esac
fi

exit 0
