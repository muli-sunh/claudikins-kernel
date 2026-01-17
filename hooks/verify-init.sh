#!/bin/bash
# verify-init.sh - SessionStart hook for /verify
# Validates that /execute has completed before allowing /verify to run.
# This enforces the /plan -> /execute -> /verify -> /ship flow (C-14).
#
# Matcher: /verify
# Exit codes:
#   0 - Execute state valid, proceed with /verify
#   2 - Execute state missing or incomplete, block /verify

set -euo pipefail

# Get project directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
EXECUTE_STATE="$CLAUDE_DIR/execute-state.json"
VERIFY_STATE="$CLAUDE_DIR/verify-state.json"

# Read input JSON from stdin
INPUT=$(cat)

# Check for --resume flag (allow resuming existing verify session)
USER_PROMPT=$(echo "$INPUT" | jq -r '.user_prompt // ""')
if [[ "$USER_PROMPT" =~ --resume ]] || [[ "$USER_PROMPT" =~ --session-id ]]; then
    # Check if verify state exists for resume
    if [ -f "$VERIFY_STATE" ]; then
        SESSION_ID=$(jq -r '.session_id // ""' "$VERIFY_STATE" 2>/dev/null || echo "")
        if [ -n "$SESSION_ID" ]; then
            cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Resuming verify session: ${SESSION_ID}"
  }
}
EOF
            exit 0
        fi
    fi
fi

# === Cross-Command Gate (C-14) ===
# Check execute-state.json exists
if [ ! -f "$EXECUTE_STATE" ]; then
    cat <<EOF >&2
ERROR: /execute has not been run

You must run /execute before /verify.
The verification command requires completed execution state.

Run: /execute [plan-file]
EOF
    exit 2
fi

# Validate execute state is complete
EXECUTE_STATUS=$(jq -r '.status // "unknown"' "$EXECUTE_STATE" 2>/dev/null || echo "unknown")
if [ "$EXECUTE_STATUS" != "completed" ]; then
    cat <<EOF >&2
ERROR: /execute did not complete successfully

Current status: ${EXECUTE_STATUS}

/verify requires /execute to have status "completed".
Either complete the execution or use /execute --resume.
EOF
    exit 2
fi

# Get execution session info for linking
EXECUTE_SESSION=$(jq -r '.session_id // "unknown"' "$EXECUTE_STATE" 2>/dev/null || echo "unknown")
EXECUTE_BRANCH=$(jq -r '.branch // ""' "$EXECUTE_STATE" 2>/dev/null || echo "")

# Generate new verify session ID
VERIFY_SESSION="verify-$(date +%Y%m%d-%H%M%S)"
TIMESTAMP=$(date -Iseconds)

# Create initial verify state
mkdir -p "$CLAUDE_DIR"
cat > "$VERIFY_STATE" <<EOF
{
  "session_id": "${VERIFY_SESSION}",
  "execute_session_id": "${EXECUTE_SESSION}",
  "branch": "${EXECUTE_BRANCH}",
  "started_at": "${TIMESTAMP}",
  "status": "initialising",
  "phases": {
    "test_suite": { "status": "pending" },
    "lint": { "status": "pending" },
    "type_check": { "status": "pending" },
    "output_verification": { "status": "pending" },
    "code_simplification": { "status": "pending" }
  },
  "all_checks_passed": false,
  "human_checkpoint": {
    "prompted_at": null,
    "decision": null,
    "caveats": []
  },
  "unlock_ship": false
}
EOF

# Create evidence directory
mkdir -p "$CLAUDE_DIR/evidence"
mkdir -p "$CLAUDE_DIR/agent-outputs/verification"
mkdir -p "$CLAUDE_DIR/agent-outputs/simplification"

# Output success context
cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "Verify session initialised: ${VERIFY_SESSION}\\nLinked to execute session: ${EXECUTE_SESSION}\\nBranch: ${EXECUTE_BRANCH}"
  }
}
EOF

exit 0
