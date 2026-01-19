#!/bin/bash
# pre-task-gate.sh - Block Task tool if previous task failed review
# Constraint C-4: Review Verdict Gate
# See: docs/constraints.md#c-4

TOOL_INPUT=$(cat -)

AGENT_TYPE=$(echo "$TOOL_INPUT" | jq -r '.tool_input.subagent_type // empty')

# Match both "babyclaude" and "claudikins-kernel:babyclaude"
if ! echo "$AGENT_TYPE" | grep -qE '(^|:)babyclaude$'; then
  exit 0  # Not babyclaude, allow
fi

STATE_FILE=".claude/execute-state.json"
if [ ! -f "$STATE_FILE" ]; then
  exit 0  # No state file, allow
fi

# Check for unresolved failures (BOTH spec and code review)
SPEC_FAILURES=$(jq '[.tasks[] | select(.status == "implemented" and .spec_review == "FAIL")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
CODE_FAILURES=$(jq '[.tasks[] | select(.status == "implemented" and .code_review == "FAIL")] | length' "$STATE_FILE" 2>/dev/null || echo "0")
TOTAL_FAILURES=$((SPEC_FAILURES + CODE_FAILURES))

if [ "$TOTAL_FAILURES" -gt 0 ]; then
  cat << EOF
{
  "permissionDecision": "deny",
  "permissionDecisionReason": "Cannot start new task - $TOTAL_FAILURES task(s) failed review ($SPEC_FAILURES spec, $CODE_FAILURES code). Fix failures before continuing."
}
EOF
  exit 0
fi

exit 0  # All clear, allow
