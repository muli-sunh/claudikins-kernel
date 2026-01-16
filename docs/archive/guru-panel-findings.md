# Guru Panel Findings

**Date:** 2026-01-15
**Rounds:** 5
**Consensus:** Unanimous (all gurus approved)

---

## Panel Structure

### Panel Members (debate, have opinions)
| Guru | Role |
|------|------|
| boris-guru | Workflow validation |
| hooks-guru | Hook implementation patterns |
| commands-guru | Command orchestration |
| skills-guru | Skill structure |
| agents-guru | Agent design |

### Advisors (query on-demand, factual reference)
| Advisor | Role |
|---------|------|
| changelog-guru | Version history, feature existence |
| docs-guru | Claude API documentation |
| claude-code-guru | Claude Code documentation |

---

## Key Findings

### 1. State Merge Pattern

**Gap Identified:** Architecture specified `context: fork` for agent isolation but didn't define how forked context outputs merge back.

**Solution:** "Spawn - Collect - Merge - Checkpoint" pattern.

```
Commands spawn forked agents
    |
SubagentStop hooks capture to agent-outputs/{agent-id}.json
    |
Command calls merge before checkpoint
    |
Human sees merged summary, decides once
```

**Implementation:**
- Each SubagentStop writes to unique file: `.claude/agent-outputs/{agent-id}.json`
- Commands aggregate with: `jq -s 'reduce .[] as $item ({}; . * $item)' .claude/agent-outputs/*.json`
- Merged state feeds to AskUserQuestion
- Commands own merge logic, hooks are passive collectors

---

### 2. Batch Size Clarification

**boris-guru validation:** "I'd use 5-7 agents per SESSION, not 30 per batch."

**Implication for /execute:**
- Batch at FEATURE level, not task level
- 10 tasks across 5 features = ~5-7 agents total
- NOT: 10 tasks = 30 agents (babyclaude + spec-reviewer + code-reviewer each)

**Recommendation:** Default `--batch 1` is correct. Features are the unit, not micro-tasks.

---

### 3. ACM Handles Context (Not PreCompact)

**Clarification:** PreCompact hooks are a fallback safety net that rarely fires.

**Actual flow:**
1. ACM monitors context usage
2. ACM prompts handoff at 60% threshold
3. State saved to `.claude/` directory
4. New session loads state via SessionStart
5. PreCompact only fires if ACM is disabled/missing

**Implication:** Focus on SessionStart state loading, not PreCompact state saving.

---

### 4. Hook Script Templates

**Minimal skeleton for each hook type:**

#### SessionStart
```bash
#!/bin/bash
set -euo pipefail

# Initialize state directory
mkdir -p "$CLAUDE_PROJECT_DIR/.claude"

# Detect project type
if [ -f "$CLAUDE_PROJECT_DIR/package.json" ]; then
  PROJECT_TYPE="nodejs"
elif [ -f "$CLAUDE_PROJECT_DIR/Cargo.toml" ]; then
  PROJECT_TYPE="rust"
elif [ -f "$CLAUDE_PROJECT_DIR/pyproject.toml" ]; then
  PROJECT_TYPE="python"
else
  PROJECT_TYPE="unknown"
fi

# Export to env
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PROJECT_TYPE=$PROJECT_TYPE" >> "$CLAUDE_ENV_FILE"
fi

exit 0
```

#### SubagentStop
```bash
#!/bin/bash
set -euo pipefail

# Read agent output from stdin
INPUT=$(cat)
AGENT_NAME=$(echo "$INPUT" | jq -r '.agent_name // "unknown"')

# Capture to unique file
OUTPUT_DIR="$CLAUDE_PROJECT_DIR/.claude/agent-outputs"
mkdir -p "$OUTPUT_DIR"
echo "$INPUT" > "$OUTPUT_DIR/${AGENT_NAME}-$(date +%s).json"

# Always exit 0 (SubagentStop cannot block)
exit 0
```

#### Stop (Gate)
```bash
#!/bin/bash
set -euo pipefail

# Read context from stdin
INPUT=$(cat)

# Check gate condition (example: uncommitted changes)
GIT_STATUS=$(git status --porcelain 2>/dev/null || echo "")

if [ -n "$GIT_STATUS" ]; then
  # Block with feedback
  echo "Uncommitted changes detected. Commit or stash first." >&2
  exit 2
fi

# Pass
exit 0
```

**Exit codes:**
- `0` = continue normally
- `2` = block tool use, feed stderr back to Claude

---

### 5. Guru Role Clarification

**Pattern insight:** Some gurus are opinionated (debate), others are factual (lookup).

**changelog-guru, docs-guru, claude-code-guru** should NOT be panel members. They're advisors that other gurus query when they need to verify facts.

**Example:** If hooks-guru says "I don't think SubagentStop exists", a panel member queries changelog-guru separately, gets the factual answer, brings it back.

---

## Architecture Validation

| Component | Status | Notes |
|-----------|--------|-------|
| /plan | Approved | No changes needed |
| /execute | Approved | Clarify batch = features, not tasks |
| /verify | Approved | No changes needed |
| /ship | Approved | No changes needed |
| Hook design | Approved | Add state merge pattern |
| Agent count | Approved | 5-7 per session confirmed |

---

## Closing Statements

**boris-guru:** "Modular agents in parallel beats any single perfect system. Ship it, iterate."

**hooks-guru:** "Hooks create feedback loops - living workflow automation."

**commands-guru:** "Frontmatter + tools + agents. That's why it works."

**Panel verdict:** APPROVED FOR IMMEDIATE IMPLEMENTATION.
