#!/bin/bash
# capture-research.sh - SubagentStop hook for claudikins-kernel
# Captures taxonomy-extremist agent output to .claude/agent-outputs/research/
#
# This hook runs when ANY subagent stops. It filters for taxonomy-extremist
# and captures the JSON output for later merging.

set -euo pipefail

trap 'echo "capture-research.sh failed at line $LINENO" >&2; exit 1' ERR

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"
RESEARCH_DIR="$CLAUDE_DIR/agent-outputs/research"

# Read input from stdin
INPUT=$(cat)

# Extract agent information from the hook input
# SubagentStop provides: session_id, transcript_path, agent details
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // .subagent_type // "unknown"' 2>/dev/null || echo "unknown")

# Only capture taxonomy-extremist output
if [[ "$AGENT_NAME" != *"taxonomy-extremist"* ]]; then
    # Not our agent, exit silently
    exit 0
fi

# Ensure research directory exists
mkdir -p "$RESEARCH_DIR"

# Generate unique filename with timestamp
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RANDOM_SUFFIX=$(head -c 4 /dev/urandom | xxd -p)
OUTPUT_FILE="$RESEARCH_DIR/taxonomy-extremist-${TIMESTAMP}-${RANDOM_SUFFIX}.json"

# Extract agent output/result from the hook input
# The actual format depends on what SubagentStop provides
AGENT_OUTPUT=$(echo "$INPUT" | jq -r '.agent_output // .result // .output // empty' 2>/dev/null || echo "")

if [ -n "$AGENT_OUTPUT" ] && [ "$AGENT_OUTPUT" != "null" ]; then
    # Save the agent output
    echo "$AGENT_OUTPUT" > "$OUTPUT_FILE"

    # Log success (shown in verbose mode)
    echo "Captured taxonomy-extremist output to: $OUTPUT_FILE"
else
    # No output to capture - save the full input for debugging
    echo "$INPUT" > "${OUTPUT_FILE%.json}-raw.json"
    echo "No structured output found. Saved raw input for debugging."
fi

# Update plan state if it exists
PLAN_STATE="$CLAUDE_DIR/plan-state.json"
if [ -f "$PLAN_STATE" ]; then
    # Check if search was exhausted
    EXHAUSTED=$(echo "$AGENT_OUTPUT" | jq -r '.search_exhausted // false' 2>/dev/null || echo "false")

    # Update research_complete flag
    if [ "$EXHAUSTED" = "true" ]; then
        jq '.research_complete = true' "$PLAN_STATE" > "${PLAN_STATE}.tmp" && \
            mv "${PLAN_STATE}.tmp" "$PLAN_STATE"
    fi
fi

exit 0
