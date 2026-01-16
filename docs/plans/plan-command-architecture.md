# /plan Command Architecture

**Date:** 2026-01-16
**Source:** Guru Panel Final Consensus (18 points unanimous)
**Status:** Ready for implementation

---

## Philosophy

> "Planning is a conversation, not a production line." - Panel consensus

- Human in the loop at every phase
- Verification available anytime (not just at end)
- Pool of tools (unrestricted, not gatekept by phase)
- Defaults ON, skip flags for less
- Non-linear phase access (can jump back/forward)
- 5-7 agents per SESSION, not 30 per batch

---

## Dependencies

### Build Dependencies (must exist first)
| Component | Type | Priority |
|-----------|------|----------|
| brain-jam-plan/ | skill | P0 |
| taxonomy-extremist.md | agent | P0 |
| hooks.json | hooks | P0 |
| session-init.sh | hook | P0 |

### Plugin Dependencies
| Plugin | Required | Purpose |
|--------|----------|---------|
| claudikins-tool-executor | YES | MCP access for research (96 tools) |
| claudikins-automatic-context-manager | YES | Context monitoring at 60% |
| claudikins-klaus | NO | Optional devil's advocate review |

---

## File Structure

```
claudikins-kernel/
├── commands/
│   └── plan.md                          # This command (~150 lines)
│
├── agents/
│   └── taxonomy-extremist.md            # Research agent (sonnet, read-only)
│
├── skills/
│   └── brain-jam-plan/
│       ├── SKILL.md                     # ~200 lines, declarative
│       └── references/
│           ├── plan-checklist.md
│           ├── approach-template.md
│           └── plan-format.md
│
└── hooks/
    ├── hooks.json                       # Central config with sequence field
    ├── session-init.sh                  # SessionStart
    ├── plan-phase-detector.sh           # UserPromptSubmit
    └── plan-verify.sh                   # UserPromptSubmit (on-demand)
```

---

## The Flow

```
/plan [brief]
    │
    │   Flags:
    │   --skip-research    Skip Phase 2
    │   --skip-review      Skip Phase 5
    │   --fast-mode        60-second iteration cycles
    │   --session-id ID    Resume previous session
    │   --output [path]    Plan destination
    │   --verify           Run verification anytime
    │
    ├── Phase 0: Session Initialisation (E-3 to E-5, E-19 to E-21)
    │     └── session-init.sh writes session_id + timestamp
    │     └── Check for existing sessions:
    │           └── If previous session found:
    │           └── plan-phase-detector.sh checks session timestamp (E-19)
    │           └── If 4+ hours old: WARN "Session is stale. Old research may be outdated." (E-20)
    │           └── Offer [Resume] [New Plan] [Review Last] (E-5, E-21)
    │     └── On PreCompact: mark "session_status": "abandoned" if incomplete (E-4)
    │
    ├── Phase 1: Brain-jam
    │     └── Main Claude + human iterate (GRFP-style)
    │     └── AskUserQuestion for requirements
    │     └── TodoWrite for progress tracking
    │     └── STOP: [Continue] [Revise] [Abandon]
    │
    ├── Phase 2: Research (default ON)
    │     └── 2-3 taxonomy-extremist agents in parallel (context: fork)
    │     └── Modes: codebase | docs | external
    │     └── Uses search_tools → get_tool_schema → execute_code
    │     └── STOP: [Continue] [Back to Brain-jam] [Skip] [Abandon]
    │
    ├── Phase 3: Approaches
    │     └── Present 2-3 options with trade-offs
    │     └── Use approach-template.md format
    │     └── Main Claude recommends one
    │     └── STOP: [A] [B] [C] [Revise] [Back to Research] [Abandon]
    │
    ├── Phase 4: Draft
    │     └── Section-by-section (GRFP pattern)
    │     └── AskUserQuestion after each section
    │     └── STOP: [Continue] [Revise section] [Back to Approaches] [Abandon]
    │
    ├── Phase 5: Review (default ON)
    │     └── Klaus (opinionated) OR plan-reviewer (thorough)
    │     └── AskUserQuestion: "Who should review?"
    │     └── STOP: [Iterate] [Finalise] [Back to Draft] [Abandon]
    │
    └── Output: plan.md with verification checklist
          └── Includes EXECUTION_TASKS markers for /execute
```

---

## Component Specifications

### 1. plan.md (Command)

```yaml
---
name: plan
description: Iterative planning with human checkpoints at every phase
argument-hint: [brief description of what to plan]
model: opus
color: blue
status: stable
version: "1.0.0"
merge_strategy: none
# === Flags (I-1 to I-4) ===
flags:
  --skip-research: Skip Phase 2 research
  --skip-review: Skip Phase 5 review
  --fast-mode: 60-second iteration cycles (I-1)
  --session-id: Resume previous session by ID (I-2)
  --timing: Show phase durations for velocity tracking (I-3)
  --list-sessions: Show available sessions for resume (I-4)
  --output: Plan destination path
  --verify: Run verification anytime
agent_outputs:
  - agent: taxonomy-extremist
    capture_to: .claude/agent-outputs/research/
    merge_strategy: jq -s 'add'
allowed-tools:
  - Read
  - Grep
  - Glob
  - Task
  - AskUserQuestion
  - TodoWrite
---
```

**Key behaviours:**
- 5 phases with explicit STOP points
- AskUserQuestion at every checkpoint with options
- TodoWrite for progress tracking
- References brain-jam-plan skill
- Invokes taxonomy-extremist agents with context: fork
- Optionally calls Klaus for review phase

---

### 2. taxonomy-extremist.md (Agent)

```yaml
---
name: taxonomy-extremist
description: |
  Research agent for /plan. Explores codebase, docs, or external sources.
  Use when gathering context before planning decisions.
model: sonnet
color: blue
context: fork
status: stable
background: false
tools:
  - Glob
  - Grep
  - Read
  - TodoWrite
  - WebSearch
  - mcp__tool-executor__search_tools
  - mcp__tool-executor__get_tool_schema
  - mcp__tool-executor__execute_code
disallowedTools:
  - Edit
  - Write
  - Bash
  - Task
---

You are a research agent. You explore and report. You do NOT modify anything.

## Modes

Activate based on research need:
- **codebase**: Use Serena, Glob, Grep for code exploration
- **docs**: Use Context7, WebFetch for documentation
- **external**: Use Gemini, WebSearch for external knowledge

## Tool Discovery Protocol

ALWAYS use tool-executor for MCP access:
1. search_tools("your query") - find relevant tools
2. get_tool_schema("tool_name") - understand parameters
3. execute_code(tool_call) - use the tool

## Output Format

Return structured findings:
```json
{
  "mode": "codebase|docs|external",
  "query": "what you searched for",
  "findings": [
    { "source": "file/url", "relevance": "high|medium|low", "summary": "..." }
  ],
  "recommendations": ["..."],
  "files_to_read": ["prioritised list for main Claude"],
  "search_exhausted": false
}
```

## Empty Findings Handling (A-2)

If no relevant findings:
1. Return `"findings": []` with `"search_exhausted": true`
2. Include `"recommendations": ["Try alternative search terms", "Expand search scope"]`
3. Main Claude will WARN user and offer [Rerun with different query] [Skip research] [Manual input]

Do NOT return fabricated findings. Empty results are valid results.

<example>
Context: User wants to plan a new authentication feature
user: "I need to plan adding OAuth to the app"
assistant: "I'll use the taxonomy-extremist agent to research OAuth patterns in similar codebases and current best practices"
<commentary>
Planning task requires research before decisions. taxonomy-extremist explores without modifying, returns findings for human review.
</commentary>
</example>

<example>
Context: User wants to understand existing architecture before planning changes
user: "Before we plan the refactor, what's the current state of the auth module?"
assistant: "I'll spawn taxonomy-extremist in codebase mode to explore the auth module structure"
<commentary>
Research task focused on existing code. Agent uses Serena/Grep to map architecture.
</commentary>
</example>
```

---

### 3. brain-jam-plan/SKILL.md

```yaml
---
name: brain-jam-plan
description: |
  Planning methodology for /plan command. Use when brainstorming approaches,
  gathering requirements, or structuring a plan.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "plan"
    - "planning"
    - "brainstorm"
    - "approach"
    - "strategy"
---

# Brain-Jam Planning Methodology

## Core Principle

> "Go back and forth with Claude until I like its plan. A good plan is really important." - Boris

Planning is iterative conversation, not a production line.

## The Brain-Jam Process

### Phase 1: Requirements Gathering
- Ask ONE question at a time
- Wait for answer before next question
- Use AskUserQuestion with specific options
- Never assume - always clarify

### Phase 2: Context Building
- What exists already?
- What constraints apply?
- What's the success criteria?
- What's explicitly OUT of scope?

### Phase 3: Approach Generation
- Generate 2-3 distinct approaches
- Each approach: summary, pros, cons, effort
- Recommend one with reasoning
- Present as options, not decisions

### Phase 4: Section-by-Section Drafting
- Draft one section at a time
- Get approval before moving on
- Revise based on feedback
- Never batch approvals

## Quality Criteria

A good plan has:
- [ ] Clear problem statement
- [ ] Explicit scope boundaries
- [ ] Measurable success criteria
- [ ] Task breakdown with dependencies
- [ ] Risk identification
- [ ] Verification checklist

## References

See references/ for:
- plan-checklist.md - Full verification checklist
- approach-template.md - How to present options
- plan-format.md - Output structure for /execute
- session-collapse-recovery.md (S-1) - How to recover from context collapse
- iteration-limits.md (S-2) - When to stop iterating and finalise
- research-timeouts.md (S-3) - Timeout handling for taxonomy-extremist
- approach-conflict-resolution.md (S-4) - When approaches conflict
- plan-abandonment-cleanup.md (S-5) - Cleaning up abandoned sessions
- requirement-stability.md (S-6) - Detecting scope creep during planning
```

---

### 4. hooks/hooks.json (Plan Section)

**ensure-claude-dirs.sh - Required for ALL commands (C-15):**

```bash
#!/bin/bash
# SessionStart hook, sequence 0 - runs before all other hooks
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
CLAUDE_DIR="$PROJECT_DIR/.claude"

# Create required directory structure
mkdir -p "$CLAUDE_DIR/agent-outputs/research"
mkdir -p "$CLAUDE_DIR/agent-outputs/tasks"
mkdir -p "$CLAUDE_DIR/agent-outputs/reviews/spec"
mkdir -p "$CLAUDE_DIR/agent-outputs/reviews/code"
mkdir -p "$CLAUDE_DIR/agent-outputs/verification"
mkdir -p "$CLAUDE_DIR/agent-outputs/simplification"
mkdir -p "$CLAUDE_DIR/agent-outputs/docs"
mkdir -p "$CLAUDE_DIR/evidence"

# Touch state files if they don't exist (allows read checks to work)
touch "$CLAUDE_DIR/.gitkeep"

echo "Claude directories initialised"
```

```json
{
  "hooks": {
    "SessionStart": [
      {
        "sequence": 0,
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/ensure-claude-dirs.sh"
          }
        ]
      },
      {
        "sequence": 1,
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-init.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "sequence": 1,
        "matcher": "/plan.*(--verify|verify|check)",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/plan-verify.sh"
          }
        ]
      },
      {
        "sequence": 2,
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/plan-phase-detector.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "sequence": 1,
        "matcher": "taxonomy-extremist",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/capture-research.sh"
          }
        ]
      }
    ],
    "PreCompact": [
      {
        "sequence": 1,
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/preserve-state.sh"
          }
        ]
      }
    ]
  }
}
```

**Note:** `sequence` field ensures hooks fire in correct order within same event type.

---

## Context Fork Isolation (A-9)

When using `context: fork` for agents:

### Expected Behaviour
- Agent gets a COPY of conversation context at spawn time
- Changes made by agent do NOT affect parent context
- Multiple forked agents can run in parallel safely
- Each agent has isolated tool state

### Testing Requirements
Before deployment, verify:
1. Parallel taxonomy-extremist agents don't see each other's findings
2. babyclaude agents don't share file edits across tasks
3. Forked context size matches expected snapshot

### Documentation
Add to CLAUDE.md learnings if context: fork behaves unexpectedly.

---

## State Merge Pattern (GOSPEL)

When Phase 2 spawns multiple taxonomy-extremist agents:

```
/plan spawns 2-3 research agents (context: fork)
    │
    ├── SubagentStop hook captures each to:
    │     .claude/agent-outputs/research/taxonomy-extremist-{id}.json
    │
    ├── Command waits for all agents to complete
    │
    ├── Command merges findings (jq in command, NOT hook):
    │     jq -s 'add' .claude/agent-outputs/research/*.json
    │
    └── Merged summary feeds to AskUserQuestion checkpoint
```

**Key principle:** Commands own merge logic. Hooks are passive collectors.

---

## Plugin Integrations

| Plugin | Role | Integration Point |
|--------|------|-------------------|
| **tool-executor** | Research efficiency | taxonomy-extremist uses search_tools protocol |
| **ACM** | Context longevity | Monitors throughout, handoff at 60% |
| **Klaus** | Devil's advocate review | Optional Phase 5 reviewer |
| **github-readme** | GRFP pattern | Section-by-section methodology borrowed |

---

## Plan Output Format

Plans must include machine-readable task markers for /execute:

```markdown
## Tasks

<!-- EXECUTION_TASKS_START -->
| # | Task | Files | Deps | Batch |
|---|------|-------|------|-------|
| 1 | Create user schema | prisma/schema.prisma | - | 1 |
| 2 | Add user service | src/services/user.ts | 1 | 1 |
| 3 | Create user routes | src/routes/user.ts | 2 | 2 |
<!-- EXECUTION_TASKS_END -->

## Verification Checklist

- [ ] All acceptance criteria defined
- [ ] Dependencies identified
- [ ] Risk mitigation planned
- [ ] Test strategy included
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Files | ~8 |
| Agents | 1 (taxonomy-extremist with modes) |
| Human checkpoints | 5 (every phase) |
| Phases skippable | Yes (--skip-research, --skip-review) |
| Verification | Anytime (/plan --verify) |
| Non-linear | Yes (can jump phases) |
| Context survival | ACM + PreCompact hook |

---

## What We're NOT Building

| Killed | Why |
|--------|-----|
| 6-agent gauntlet | One thorough reviewer beats five shallow ones |
| Tool lists per phase | Let Claude + tool-executor figure it out |
| Linear-only flow | Human can jump to any phase |
| Verification at end only | Available anytime via --verify |

---

## Next Step Suggestion

At the end of `/plan`, Claude says:

```
Done! Plan saved to [path]

When you're ready:
  /execute [plan-path]
```

---

## Required New Skills (I-5 to I-7)

These 3 skills are P0 dependencies for all commands:

### session-management/SKILL.md (I-5)

```yaml
---
name: session-management
description: |
  Handle session collapse, resumption, and state recovery.
  Use when ACM reports 60%+, session dies, or resuming previous work.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "session"
    - "resume"
    - "context"
    - "handoff"
    - "ACM"
  flags:
    - "--session-id"
  events:
    - "SessionStart"
    - "PreCompact"
---

# Session Management

## Core Responsibilities

1. Session ID generation and tracking
2. State preservation on context collapse
3. Graceful resume from checkpoint
4. ACM integration at 60% threshold

## References

See references/ for:
- session-state-schema.md - State file format
- checkpoint-integrity.md - Ensuring valid checkpoints
- session-recovery-testing.md - Testing recovery flows
```

### fallback-verification/SKILL.md (I-6)

```yaml
---
name: fallback-verification
description: |
  Graceful degradation when primary verification fails.
  Use when catastrophiser can't run, tools unavailable, or timeouts occur.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "fallback"
    - "timeout"
    - "unavailable"
    - "degraded"
---

# Fallback Verification

## Verification Hierarchy

When primary method fails, try in order:

1. **Primary**: catastrophiser runs full verification
2. **Secondary**: Run tests + lint only (no visual)
3. **Tertiary**: Code review by opus + human approval
4. **Emergency**: Human-only verification with caveats

## References

See references/ for:
- verification-hierarchy.md - Fallback chain
- partial-evidence-acceptance.md - What evidence suffices
- timeout-escalation.md - When to escalate
```

### error-recovery/SKILL.md (I-7)

```yaml
---
name: error-recovery
description: |
  Systematic error recovery without losing progress.
  Use when tools fail, hooks crash, or agents timeout.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "error"
    - "failed"
    - "crashed"
    - "retry"
    - "rollback"
---

# Error Recovery

## Error Classification

| Category | Response | Max Retries |
|----------|----------|-------------|
| Transient (network, timeout) | Retry with backoff | 3 |
| Tool failure | Try alternative tool | 2 |
| Agent crash | Restart from checkpoint | 2 |
| State corruption | Rollback to last good | 1 |
| Unrecoverable | Human intervention | 0 |

## References

See references/ for:
- error-classification.md - Error taxonomy
- rollback-strategy.md - Safe rollback patterns
- error-logging-format.md - Structured error logging
```

### escalation-patterns/SKILL.md (Cross-Cutting)

```yaml
---
name: escalation-patterns
description: |
  Patterns for escalating to Klaus or human when stuck.
  Use when max retries reached, unresolvable conflicts, or agent deadlocks.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "stuck"
    - "escalate"
    - "klaus"
    - "help"
---
```

**References (S-25 to S-29):**
- klaus-unavailability-fallback.md (S-25) - What to do when Klaus not available
- escalation-queue.md (S-26) - Managing multiple escalation requests
- escalation-timeout-protocol.md (S-27) - Timeout handling for escalations
- decision-consistency.md (S-28) - Ensuring consistent escalation decisions
- escalation-state-preservation.md (S-29) - Preserving state during escalation

### conflict-resolution/SKILL.md (Cross-Cutting)

```yaml
---
name: conflict-resolution
description: |
  Patterns for resolving merge conflicts, reviewer disagreements, and task conflicts.
  Use when automated resolution fails.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "conflict"
    - "merge"
    - "disagreement"
    - "resolution"
---
```

**References (S-30 to S-35):**
- marker-validation.md (S-30) - Validating conflict markers resolved
- unresolvable-conflict-protocol.md (S-31) - When conflicts can't be auto-resolved
- binary-conflict-handling.md (S-32) - Handling binary file conflicts
- conflict-test-validation.md (S-33) - Testing after conflict resolution
- rebase-vs-merge.md (S-34) - Choosing between rebase and merge
- conflict-resolution-locking.md (S-35) - Preventing concurrent resolution

---

## Documentation Deliverables (I-8 to I-15)

These documents must be created alongside implementation:

| ID | Document | Purpose |
|----|----------|---------|
| I-8 | README.md | Architecture overview |
| I-9 | UPGRADING.md | Migration guide v0 → v1 |
| I-10 | plugin.json | Version, dependencies, keywords |
| I-11 | Hook lifecycle reference | Hook event timing diagram |
| I-12 | manifest.json | .claude/ directory metadata |
| I-13 | settings.json example | Permissions whitelist |
| I-14 | .claude/rules/ templates | Planning, execution, verification, git, tools |
| I-15 | State schema reference | plan-state, execute-state, verify-state, ship-state |

---

## Command-Level Edge Cases (CMD-1 through CMD-30)

### Cross-Command Sequence (CMD-1 to CMD-4) - See C-13, C-14, C-15

### State File Edge Cases (CMD-5 to CMD-8)

**CMD-5: plan-state.json wrong project**
```bash
# In plan-project-guard.sh
PROJECT_HASH=$(echo "$CLAUDE_PROJECT_DIR" | sha256sum | cut -c1-16)
STATE_HASH=$(jq -r '.project_hash // ""' "$PLAN_STATE")
if [ -n "$STATE_HASH" ] && [ "$PROJECT_HASH" != "$STATE_HASH" ]; then
  echo "ERROR: Plan state is for different project" >&2
  exit 2
fi
```

**CMD-6: execute deleted branches**
```bash
# Pre-merge check for deleted branches
for branch in $(jq -r '.tasks[].branch' "$EXECUTE_STATE"); do
  if ! git rev-parse --verify "$branch" &>/dev/null; then
    jq --arg b "$branch" '.tasks[$b].branch_status = "deleted"' "$EXECUTE_STATE"
    echo "WARNING: Branch $branch no longer exists" >&2
  fi
done
```

**CMD-7: verify timestamp mismatch**
```json
{
  "execute_session_id": "must match execute-state.json",
  "execute_commit_sha": "must match HEAD at execute completion"
}
```

**CMD-8: ensure-claude-dirs.sh** - See C-15

### State Tracking (CMD-9 to CMD-12)

**CMD-9: Partial batch + context death**
- execute-tracker.sh persists state after EVERY tool call (not just task completion)

**CMD-10: Parallel sessions**
```bash
# In execute-session-lock.sh
LOCK_FILE="$PROJECT_DIR/.claude/session-lock-${SESSION_ID}"
if ! mkdir "$LOCK_FILE" 2>/dev/null; then
  echo "ERROR: Another session is running" >&2
  echo "Lock held by: $(cat "$LOCK_FILE/pid" 2>/dev/null)" >&2
  exit 2
fi
echo $$ > "$LOCK_FILE/pid"
trap "rm -rf $LOCK_FILE" EXIT
```

**CMD-11: Research fork incomplete**
```bash
# In capture-research.sh
COMPLETE=$(jq -r '.search_exhausted // false' "$OUTPUT")
jq --argjson complete "$COMPLETE" '.research_complete = $complete' "$PLAN_STATE"
```

**CMD-12: Hook sequence conflicts**
- Enforce unique sequence per event type
- If duplicate found, WARN and use lexicographic order

### Flag Edge Cases (CMD-13 to CMD-16)

**CMD-13: Invalid --session-id**
```bash
if [ -n "$SESSION_ID" ] && [ ! -f "$STATE_DIR/session-${SESSION_ID}.json" ]; then
  echo "ERROR: Session $SESSION_ID not found" >&2
  echo "Available sessions:" >&2
  ls -1 "$STATE_DIR/session-*.json" | sed 's/.*session-//;s/.json//' >&2
  exit 2
fi
```

**CMD-14: --batch violates dependencies** - See E-22 to E-24 (topological sort)

**CMD-15: --skip-research risk**
```
WARNING: Skipping research reduces planning confidence to ~60%
Proceed without research context? [Yes] [No, run research]
```

**CMD-16: --fast-mode too fast**
- Don't enforce deadline if agent requests extension
- Offer [Grant extension] [Force stop] [Skip to checkpoint]

### Human Checkpoint Edge Cases (CMD-17 to CMD-19)

**CMD-17: Abandoned flow**
```json
{
  "abandoned": true,
  "abandoned_at": "timestamp",
  "abandoned_phase": "Phase 2",
  "recovery_options": ["Resume from Phase 2", "Start fresh"]
}
```

**CMD-18: Conflicting decisions**
- Track pending_revisions in state
- Offer explicit [Revise specific section] option

**CMD-19: AskUserQuestion timeout**
- 30 minute timeout
- 5 minute warning before timeout
- Auto-save state on timeout
- Offer [Resume] [Start fresh] on reconnect

### Git Operation Edge Cases (CMD-20 to CMD-23)

**CMD-20: Branch name conflicts** - See E-11 (UUID suffix)

**CMD-21: Merge conflicts on batch** - See E-11, E-12

**CMD-22: Dirty working directory**
```bash
if [ -n "$(git status --porcelain)" ]; then
  echo "ERROR: Working directory has uncommitted changes" >&2
  echo "Commit or stash changes before running /execute" >&2
  exit 2
fi
```

**CMD-23: Detached HEAD on /ship**
```bash
if ! git symbolic-ref -q HEAD &>/dev/null; then
  echo "ERROR: HEAD is detached" >&2
  echo "Checkout a branch before shipping" >&2
  exit 2
fi
```

### Verification Gate Edge Cases (CMD-24 to CMD-26)

**CMD-24: exit code 2 ignored**
- Integration test must verify exit code handling
- All hooks must use `set -e`

**CMD-25: unlock_ship manually edited**
```bash
# HMAC signature validation (future enhancement)
# For now: check timestamp matches verified_at
UNLOCK_TIME=$(jq -r '.unlock_ship_at // ""' "$VERIFY_STATE")
VERIFY_TIME=$(jq -r '.verified_at // ""' "$VERIFY_STATE")
if [ "$UNLOCK_TIME" != "$VERIFY_TIME" ]; then
  echo "WARNING: unlock_ship timestamp mismatch - possible tampering" >&2
fi
```

**CMD-26: /verify rerun after ship**
- Clear unlock_ship on any code change
- Require re-verification before next ship

### Agent Spawning Edge Cases (CMD-27 to CMD-30)

**CMD-27: Research mode mismatch**
- Use AskUserQuestion in /plan Phase 0 for mode selection
- Options: [Codebase] [Docs] [External] [All]

**CMD-28: Task context too large**
```bash
# Estimate context size before spawning
CONTEXT_ESTIMATE=$(wc -c "$TASK_CONTEXT" | awk '{print $1}')
if [ "$CONTEXT_ESTIMATE" -gt 100000 ]; then
  echo "WARNING: Task context is large ($CONTEXT_ESTIMATE bytes)" >&2
  # Offer [Split task] [Proceed anyway] [Summarise context]
fi
```

**CMD-29: Review order wrong**
- Skip code-reviewer if spec-reviewer fails
- Only run code review on spec-compliant implementations

**CMD-30: catastrophiser hang** - See verify flow (30s timeout per method)

---

## PreCompact State Schema (I-19)

All 4 commands must output this schema on PreCompact:

```json
{
  "session_id": "string",
  "command": "/plan|/execute|/verify|/ship",
  "phase": "current phase name",
  "critical_state": {
    "tasks_completed": [],
    "tasks_pending": [],
    "current_batch": 0,
    "human_decisions": []
  },
  "resume_instructions": "string describing how to continue"
}
```

---

## New Hooks Required (NH-1 through NH-9)

These 9 new hooks are required across all commands:

### NH-1: detect-phase-loop.sh (SessionStart)
```bash
# Detect infinite iteration between phases
PHASE_HISTORY="$PROJECT_DIR/.claude/phase-history.log"
CURRENT_PHASE="${PHASE:-unknown}"
THRESHOLD=5

# Count consecutive visits to same phase
CONSECUTIVE=$(tail -n "$THRESHOLD" "$PHASE_HISTORY" 2>/dev/null | grep -c "^$CURRENT_PHASE$")
if [ "$CONSECUTIVE" -ge "$THRESHOLD" ]; then
  echo "WARNING: Phase loop detected - visited $CURRENT_PHASE $CONSECUTIVE times" >&2
  echo "Consider: [Move forward] [Get human input] [Abort]" >&2
fi
echo "$CURRENT_PHASE" >> "$PHASE_HISTORY"
```

### NH-2: validate-dependencies.sh (PreToolUse)
```bash
# Check task dependencies before allowing tool execution
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
  TASK_ID="${CURRENT_TASK_ID:-}"
  if [ -n "$TASK_ID" ]; then
    DEPS=$(jq -r ".tasks[\"$TASK_ID\"].deps[]?" "$EXECUTE_STATE")
    for dep in $DEPS; do
      DEP_STATUS=$(jq -r ".tasks[\"$dep\"].status" "$EXECUTE_STATE")
      if [ "$DEP_STATUS" != "completed" ]; then
        echo "BLOCKED: Task $TASK_ID depends on incomplete task $dep" >&2
        exit 2
      fi
    done
  fi
fi
```

### NH-3: detect-branch-collision.sh (SubagentStart)
```bash
# Prevent duplicate branch creation
BRANCH_NAME="${TASK_BRANCH_NAME:-}"
if [ -n "$BRANCH_NAME" ]; then
  if git rev-parse --verify "$BRANCH_NAME" &>/dev/null; then
    echo "ERROR: Branch $BRANCH_NAME already exists" >&2
    echo "Use --force to overwrite or choose different task slug" >&2
    exit 2
  fi
fi
```

### NH-4: validate-review-conflict.sh (Stop)
```bash
# Enforce both reviews pass before accepting batch
SPEC_RESULT=$(jq -r '.current_batch.spec_review // "pending"' "$EXECUTE_STATE")
CODE_RESULT=$(jq -r '.current_batch.code_review // "pending"' "$EXECUTE_STATE")

if [ "$SPEC_RESULT" = "FAIL" ]; then
  echo "BLOCKED: Spec review failed - must revise before continuing" >&2
  exit 2
fi

if [ "$SPEC_RESULT" = "PASS" ] && [ "$CODE_RESULT" = "CONCERNS" ]; then
  echo "WARNING: Code review has concerns"
  echo "Options: [Accept with caveats] [Fix issues] [Klaus review]"
fi
```

### NH-5: escalation-timeout.sh (Background)
```bash
# Auto-escalate stalled escalation requests
ESCALATION_FILE="$PROJECT_DIR/.claude/escalation-pending.json"
if [ -f "$ESCALATION_FILE" ]; then
  CREATED=$(jq -r '.created_at' "$ESCALATION_FILE")
  NOW=$(date +%s)
  AGE=$((NOW - $(date -d "$CREATED" +%s)))

  if [ "$AGE" -gt 300 ]; then  # 5 minute timeout
    echo "WARNING: Escalation request stalled for ${AGE}s" >&2
    echo "Auto-escalating to human..." >&2
    jq '.auto_escalated = true' "$ESCALATION_FILE" > tmp.$$ && mv tmp.$$ "$ESCALATION_FILE"
  fi
fi
```

### NH-6: conflict-resolution-locker.sh (SubagentStart)
```bash
# Prevent concurrent conflict resolution
if [ "$AGENT_NAME" = "conflict-resolver" ]; then
  LOCK="$PROJECT_DIR/.claude/conflict-resolution.lock"
  if [ -f "$LOCK" ]; then
    echo "ERROR: Conflict resolution already in progress" >&2
    echo "Wait for current resolution to complete" >&2
    exit 2
  fi
  touch "$LOCK"
  trap "rm -f $LOCK" EXIT
fi
```

### NH-7: cynic-test-validator.sh (PostToolUse)
```bash
# Validate tests still pass after cynic simplifications
if [ "$AGENT_NAME" = "cynic" ] && [ "$TOOL_NAME" = "Edit" ]; then
  echo "Running tests after simplification..."
  if ! npm test 2>/dev/null && ! pytest 2>/dev/null && ! cargo test 2>/dev/null; then
    echo "WARNING: Tests may have broken after simplification" >&2
    echo "Consider: [Revert] [Fix] [Accept anyway]" >&2
  fi
fi
```

### NH-8: ci-status-poller.sh (PostToolUse)
```bash
# Detect CI failures after PR creation
if [ "$TOOL_NAME" = "Bash" ] && echo "$TOOL_INPUT" | grep -q "gh pr create"; then
  PR_NUMBER=$(echo "$TOOL_OUTPUT" | grep -oE 'pull/[0-9]+' | cut -d/ -f2)
  if [ -n "$PR_NUMBER" ]; then
    # Poll CI status
    sleep 30
    CI_STATUS=$(gh pr checks "$PR_NUMBER" --json state -q '.[].state' 2>/dev/null | head -1)
    if [ "$CI_STATUS" = "FAILURE" ]; then
      echo "WARNING: CI checks failing for PR #$PR_NUMBER" >&2
    fi
  fi
fi
```

### NH-9: gate-failure-messagemaker.sh (embedded in ship-init.sh)
Already implemented in ship-init.sh with enhanced error messages including:
- Specific failure reason
- Suggested remediation
- Link to relevant documentation

---

## Build Checklist

- [ ] Create brain-jam-plan/SKILL.md
- [ ] Create brain-jam-plan/references/*.md (3 files)
- [ ] Create session-management/SKILL.md (I-5)
- [ ] Create session-management/references/*.md (3 files)
- [ ] Create fallback-verification/SKILL.md (I-6)
- [ ] Create fallback-verification/references/*.md (3 files)
- [ ] Create error-recovery/SKILL.md (I-7)
- [ ] Create error-recovery/references/*.md (3 files)
- [ ] Create taxonomy-extremist.md agent
- [ ] Create/update hooks.json with sequence field (INTEGER, not string) (I-18)
- [ ] Create ensure-claude-dirs.sh hook (C-15)
- [ ] Create session-init.sh hook
- [ ] Create plan-phase-detector.sh hook
- [ ] Create plan-verify.sh hook
- [ ] Create capture-research.sh hook
- [ ] Create preserve-state.sh hook
- [ ] Create plan.md command
- [ ] Create README.md (I-8)
- [ ] Create UPGRADING.md (I-9)
- [ ] Create plugin.json (I-10)
- [ ] Create detect-phase-loop.sh (NH-1)
- [ ] Create validate-dependencies.sh (NH-2)
- [ ] Create detect-branch-collision.sh (NH-3)
- [ ] Create validate-review-conflict.sh (NH-4)
- [ ] Create escalation-timeout.sh (NH-5)
- [ ] Create conflict-resolution-locker.sh (NH-6)
- [ ] Create cynic-test-validator.sh (NH-7)
- [ ] Create ci-status-poller.sh (NH-8)
- [ ] Test with real planning task

---

## Boris Scenario Gaps (BG-1 to BG-5) - Future Considerations

These scenarios are NOT currently addressed and may need future work:

| ID | Scenario | Impact | Suggested Approach |
|----|----------|--------|-------------------|
| BG-1 | Monorepo support | Multiple packages in one repo | Add --workspace flag, package-aware batching |
| BG-2 | Hotfix bypass | Emergency skip of /verify | Add --emergency flag with human confirmation |
| BG-3 | Multi-PR coordination | Feature spans multiple PRs | Add umbrella PR tracking, cross-PR dependencies |
| BG-4 | Rollback after /ship | Code reverted on main | Add rollback detection, offer [Investigate] [Re-ship] |
| BG-5 | Partial batch resume | Context died mid-batch, 2/5 tasks done | Add batch checkpointing, resume from last complete task |

---

## Verification

After implementation, verify:
- [ ] All 4 plan documents updated
- [ ] All 166 items addressed
- [ ] No circular dependencies in hooks
- [ ] Build order preserved (plan → execute → verify → ship)
- [ ] All 18 original consensus points still covered
