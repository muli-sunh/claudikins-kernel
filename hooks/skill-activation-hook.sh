#!/usr/bin/env bash
# skill-activation-hook.sh - Auto-suggest skills based on intent and file patterns
# This is a UserPromptSubmit hook that checks skill-rules.json for matches

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(dirname "$0")/..}"
RULES_FILE="${PLUGIN_ROOT}/.claude/skill-rules.json"

# Read hook input
HOOK_INPUT="${CLAUDE_HOOK_INPUT:-}"
if [[ -z "$HOOK_INPUT" ]]; then
    exit 0
fi

# Check if rules file exists
if [[ ! -f "$RULES_FILE" ]]; then
    exit 0
fi

# Extract user prompt
USER_PROMPT=$(echo "$HOOK_INPUT" | jq -r '.userPrompt // empty')
if [[ -z "$USER_PROMPT" ]]; then
    exit 0
fi

# Check each rule for matches
MATCHES=""
while read -r rule; do
    SKILL=$(echo "$rule" | jq -r '.skill')
    ENFORCEMENT=$(echo "$rule" | jq -r '.enforcement // "suggest"')
    
    # Check intent patterns
    while read -r pattern; do
        if [[ -n "$pattern" ]] && echo "$USER_PROMPT" | grep -qiE "$pattern" 2>/dev/null; then
            if [[ -z "$MATCHES" ]]; then
                MATCHES="$SKILL"
            else
                MATCHES="$MATCHES, $SKILL"
            fi
            break
        fi
    done < <(echo "$rule" | jq -r '.intentPatterns[]' 2>/dev/null)
done < <(jq -c '.rules[]' "$RULES_FILE" 2>/dev/null)

# If we found matching skills, add suggestion to context
if [[ -n "$MATCHES" ]]; then
    echo "{\"additionalContext\": \"Auto-detected relevant skills: $MATCHES. Consider loading them with Skill tool if not already active.\"}"
fi
