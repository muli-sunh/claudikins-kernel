# /execute Command Architecture

**Date:** 2026-01-16
**Source:** Guru Panel Final Consensus (18 points unanimous)
**Status:** Ready for implementation

---

## Philosophy

> "Fresh subagent per task + two-stage review = high quality"

- Subagent per task (fresh context, no pollution)
- Each task gets own git branch
- Self-verification before external review
- Human checkpoints between batches, not tasks
- ACM monitors context, handoff at 60%
- Klaus available when stuck (after max retries)

### Batch Size Guidance (GOSPEL)

> "I'd use 5-7 agents per SESSION, not 30 per batch." - boris-guru

**Batch at FEATURE level, not task level.**

| Scenario | Wrong | Right |
|----------|-------|-------|
| 10 tasks, 5 features | 30 agents (3 per task) | 5-7 agents (feature batches) |
| Simple refactor | 10 micro-task agents | 1-2 feature agents |

Default `--batch 1` is correct. Features are the unit of work.

---

## Dependencies

### Build Dependencies (must exist first)
| Component | Type | Priority |
|-----------|------|----------|
| git-workflow/ | skill | P0 |
| babyclaude.md | agent | P0 |
| spec-reviewer.md | agent | P0 |
| code-reviewer.md | agent | P0 |
| hooks.json | hooks | P0 |
| All /plan components | command | P0 |

### Plugin Dependencies
| Plugin | Required | Purpose |
|--------|----------|---------|
| claudikins-tool-executor | YES | MCP access for implementation |
| claudikins-automatic-context-manager | YES | Context monitoring at 60% |
| claudikins-klaus | NO | Stuck escalation after retries |

---

## File Structure

```
claudikins-kernel/
├── commands/
│   ├── plan.md                          # From /plan
│   └── execute.md                       # This command (~200 lines)
│
├── agents/
│   ├── taxonomy-extremist.md            # From /plan
│   ├── babyclaude.md                    # Task implementer (sonnet)
│   ├── spec-reviewer.md                 # Spec compliance (haiku)
│   └── code-reviewer.md                 # Code quality (opus)
│
├── skills/
│   ├── brain-jam-plan/                  # From /plan
│   └── git-workflow/
│       ├── SKILL.md                     # ~200 lines declarative
│       └── references/
│           ├── task-decomposition.md
│           ├── review-criteria.md
│           └── batch-patterns.md
│
└── hooks/
    ├── hooks.json                       # Extended for execution
    ├── execute-status.sh                # UserPromptSubmit
    ├── create-task-branch.sh            # SubagentStart
    ├── git-branch-guard.sh              # PreToolUse
    ├── execute-tracker.sh               # PostToolUse
    ├── task-completion-capture.sh       # SubagentStop
    └── batch-checkpoint-gate.sh         # Stop
```

---

## The Flow

```
/execute [plan.md]
    │
    │   Flags:
    │   --batch N          Tasks per batch (default: 1)
    │   --no-branch        Skip git branches (small changes)
    │   --review [mode]    spec|code|both|none (default: both)
    │   --fast-mode        60-second iteration cycles
    │   --session-id ID    Resume previous session
    │   --klaus-rescue     Auto-invoke Klaus when stuck
    │   --dry-run          Show what would execute
    │
    ├── Phase 0: Load & Validate (C-13, E-22 to E-24)
    │     └── validate-plan-format.sh checks EXECUTION_TASKS markers exist
    │     └── If markers missing: STOP "Plan missing task markers. Re-run /plan"
    │     └── Parse plan.md, extract EXECUTION_TASKS table
    │     └── Build dependency graph from Deps column (E-22)
    │     └── Topological sort to determine execution order (CMD-14)
    │     └── Calculate batches respecting dependencies
    │     └── Dependency violation handling (E-23, E-24):
    │           └── If human skips task X and task Y depends on X:
    │           └── WARN: "Task Y depends on skipped task X"
    │           └── Offer [Skip both] [Continue anyway (Y may fail)]
    │     └── STOP: "N tasks in M batches. Proceed?"
    │
    ├── Per-Batch Loop:
    │     │
    │     ├── STOP 1: Batch Start
    │     │     └── "Batch K/M: [task1, task2]. Ready?"
    │     │     └── Options: [Execute] [Skip X] [Reorder] [Pause]
    │     │
    │     ├── Execute Tasks (parallel within batch):
    │     │     └── For each task:
    │     │           └── Create branch: execute/task-N-slug-{uuid} (E-20: UUID suffix)
    │     │           └── Spawn babyclaude (context: fork)
    │     │           └── Monitor for stuck signals
    │     │           └── Self-verify before handoff
    │     │     └── Context monitoring (E-1, E-9, E-10):
    │     │           └── If ACM reports 75%+: MANDATORY STOP (not optional)
    │     │           └── Offer [Continue on new tab] [Pause batch] [Handoff to new agent]
    │     │           └── Emergency checkpoint saves partial state
    │     │
    │     ├── Review Tasks (sequential) (E-15: Verdict Matrix):
    │     │     └── Stage 1: Spec compliance (spec-reviewer, haiku)
    │     │     └── Stage 2: Code quality (code-reviewer, opus)
    │     │     └── Verdict matrix:
    │     │           └── spec PASS + code PASS → [Accept] [Revise]
    │     │           └── spec PASS + code CONCERNS → [Accept caveats] [Fix] [Klaus review]
    │     │           └── spec FAIL → always [Revise] or [Retry]
    │     │     └── If both fail after retries: Klaus escalation
    │     │
    │     ├── STOP 2: Batch Review
    │     │     └── Results table: task, status, files, review
    │     │     └── Options: [Accept] [Revise X] [Retry] [Klaus]
    │     │
    │     ├── Phase 4B: Merge Conflict Detection (E-11, E-12)
    │     │     └── Run git merge-base check against target branch
    │     │     └── If conflicts detected:
    │     │           └── Show conflicting files
    │     │           └── Offer [conflict-resolver agent] [Manual resolution] [Skip merge]
    │     │
    │     └── STOP 3: Merge Decision
    │           └── Options: [Merge all] [Merge X,Y] [Keep separate]
    │
    └── Phase Final: Completion
          └── Summary of all tasks
          └── STOP: "Run /verify?"
          └── Options: [Verify] [Done] [More tasks]
```

---

## Component Specifications

### 1. execute.md (Command)

```yaml
---
name: execute
description: Execute validated plan with parallel task batches
argument-hint: <plan.md> [--batch N] [--review mode] [--klaus-rescue]
model: opus
color: green
status: stable
version: "1.0.0"
merge_strategy: jq
# === Flags (I-1 to I-4) ===
flags:
  --batch: Tasks per batch (default: 1)
  --no-branch: Skip git branches (small changes)
  --review: spec|code|both|none (default: both)
  --fast-mode: 60-second iteration cycles (I-1)
  --session-id: Resume previous session by ID (I-2)
  --timing: Show phase durations for velocity tracking (I-3)
  --list-sessions: Show available sessions for resume (I-4)
  --klaus-rescue: Auto-invoke Klaus when stuck
  --dry-run: Show what would execute
agent_outputs:
  - agent: babyclaude
    capture_to: .claude/agent-outputs/tasks/
    merge_strategy: jq -s 'group_by(.task_id) | map(add)'
  - agent: spec-reviewer
    capture_to: .claude/agent-outputs/reviews/spec/
    merge_strategy: concat
  - agent: code-reviewer
    capture_to: .claude/agent-outputs/reviews/code/
    merge_strategy: concat
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
  - Task
  - AskUserQuestion
  - TodoWrite
---
```

**Key behaviours:**
- Parses plan.md task table (EXECUTION_TASKS markers)
- Orchestrates git branches (not delegated to subagents)
- Spawns babyclaude per task with full task context
- Chains spec-reviewer then code-reviewer
- Human checkpoints between batches

---

### 2. babyclaude.md (Agent)

```yaml
---
name: babyclaude
description: |
  Implements a single task from validated plan. One task, one branch, complete isolation.
  Use when executing a specific task from /execute.
model: sonnet
color: green
context: fork
status: stable
background: false
tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
  - TodoWrite
  - mcp__tool-executor__search_tools
  - mcp__tool-executor__get_tool_schema
  - mcp__tool-executor__execute_code
disallowedTools:
  - Task
---

You implement EXACTLY this task:
{{TASK_DESCRIPTION}}

## Acceptance Criteria
{{ACCEPTANCE_CRITERIA}}

## Scope Discipline (A-1: Scope Enforcement)

- Implement only what is specified
- Stop when acceptance criteria met
- Do NOT refactor unrelated code
- Do NOT add features "while you're there"
- If you discover issues OUT OF SCOPE: log to SCOPE_NOTES.md, continue

### Pre-Task Scope Checkpoint (A-1)

Before starting work, validate:
1. Task description is clear and bounded
2. Acceptance criteria are measurable
3. File list is explicit (no "and related files")
4. Output format is defined

If any are missing, request clarification before proceeding.

## Self-Verification

Before completing:
1. Run tests (if applicable)
2. Run linter
3. Verify acceptance criteria met
4. Commit with message: "task: {{task-slug}}"

## Bash Restrictions

MAY: Run tests, builds, lints, git add/commit on YOUR branch
MUST NOT: git checkout, git merge, git push, destructive ops

## Output Format

```json
{
  "task_id": "{{task-id}}",
  "status": "complete|blocked|needs_review",
  "files_changed": ["..."],
  "tests_added": ["..."],
  "self_verification": {
    "tests_pass": true,
    "lint_clean": true,
    "criteria_met": ["..."]
  },
  "scope_notes": ["any out-of-scope discoveries"],
  "commit_status": "success|failed|skipped"
}
```

## Commit Failure Handling (E-13, E-14)

If git commit fails:
1. Log failure reason to SCOPE_NOTES.md
2. Report status as "blocked" in JSON output
3. DO NOT fake completion or pretend commit succeeded
4. Include failure details in scope_notes

```json
{
  "task_id": "task-3",
  "status": "blocked",
  "commit_status": "failed",
  "scope_notes": ["git commit failed: pre-commit hook rejected - lint errors"]
}
```

<example>
Context: /execute is running a task to add authentication middleware
user: "Execute task 3: Add auth middleware to protected routes"
assistant: "I'll spawn babyclaude to implement the auth middleware task in isolation"
<commentary>
Single task from a plan. babyclaude gets its own branch, implements exactly what's specified, self-verifies, then hands off for review.
</commentary>
</example>

<example>
Context: Task requires adding a new API endpoint
user: "Task 5: Create /api/users endpoint with CRUD operations"
assistant: "Spawning babyclaude for the users endpoint task"
<commentary>
Implementation task with clear scope. babyclaude will create the endpoint, add tests, verify lint passes, then complete.
</commentary>
</example>
```

---

### 3. spec-reviewer.md (Agent)

```yaml
---
name: spec-reviewer
description: |
  Verify implementation matches plan spec. Does it do what was asked?
  Use after babyclaude completes a task, before code-reviewer.
model: haiku
color: yellow
context: fork
status: stable
background: false
tools:
  - Read
  - Grep
  - Glob
disallowedTools:
  - Edit
  - Write
  - Bash
  - Task
---

You verify SPEC COMPLIANCE only.

## Input

Given:
- Task description from plan
- Acceptance criteria
- Implementation diff (git diff)

## Check

1. Does implementation address ALL acceptance criteria?
2. Any scope creep (features not in spec)?
3. Any missing requirements?

## Output Format

```json
{
  "task_id": "{{task-id}}",
  "verdict": "PASS|FAIL",
  "criteria_checked": [
    { "criterion": "...", "met": true, "evidence": "file:line" }
  ],
  "scope_creep": ["any additions not in spec"],
  "missing": ["any requirements not implemented"]
}
```

## Rules

- Output: PASS | FAIL with specific line references
- Do NOT comment on code quality - that is not your job
- Be mechanical and thorough
- If uncertain, FAIL and explain why

<example>
Context: Reviewing babyclaude's implementation of auth middleware
user: "Review task 3 implementation against spec"
assistant: "I'll use spec-reviewer to verify the auth middleware meets all acceptance criteria"
<commentary>
First stage of two-stage review. spec-reviewer checks compliance with requirements, not code quality.
</commentary>
</example>
```

---

### 4. code-reviewer.md (Agent)

```yaml
---
name: code-reviewer
description: |
  Review code quality, patterns, maintainability. Is it well-written?
  Use after spec-reviewer passes, before human checkpoint.
model: opus
color: cyan
context: fork
status: stable
background: false
tools:
  - Read
  - Grep
  - Glob
disallowedTools:
  - Edit
  - Write
  - Bash
  - Task
---

You review CODE QUALITY only. Assume spec compliance verified.

## Check

1. Code style consistency with codebase
2. Error handling
3. Edge cases
4. Naming clarity
5. Unnecessary complexity

## Confidence Scoring

Rate each issue 0-100:
- **0-50**: Low confidence - do not report
- **51-79**: Medium - note internally only
- **80-89**: High - report as Important
- **90-100**: Very high - report as Critical

**Only report issues with confidence >= 80.**

## Output Format

```json
{
  "task_id": "{{task-id}}",
  "verdict": "PASS|CONCERNS",
  "critical_issues": [
    { "file": "...", "line": 42, "issue": "...", "confidence": 95, "fix": "..." }
  ],
  "important_issues": [
    { "file": "...", "line": 15, "issue": "...", "confidence": 82, "fix": "..." }
  ],
  "strengths": ["what's done well"]
}
```

## Rules

- Do NOT re-check requirements - spec-reviewer handles that
- Focus on maintainability and correctness
- Opus model - use judgement, not just rules

<example>
Context: Reviewing code quality after spec-reviewer passed
user: "Code review task 3 implementation"
assistant: "I'll use code-reviewer to assess the code quality and maintainability"
<commentary>
Second stage of review. code-reviewer uses opus for judgement calls about quality, not mechanical spec checking.
</commentary>
</example>
```

---

### 5. git-workflow/SKILL.md

```yaml
---
name: git-workflow
description: |
  Execution methodology for implementing validated plans. Use when running /execute,
  decomposing tasks, setting up reviews, or deciding checkpoints.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "execute"
    - "implement"
    - "task"
    - "batch"
    - "review"
---

# Git Workflow Methodology

## Core Principles

1. **One task = one branch** - Isolation prevents pollution
2. **Fresh context per task** - context: fork for clean slate
3. **Two-stage review** - Spec compliance, then code quality
4. **Human checkpoints between batches** - Not between tasks
5. **Commands own git** - Agents don't checkout/merge/push
6. **5-7 agents per session** - Features, not micro-tasks

## Task Decomposition

From a plan, extract tasks that are:
- **Atomic**: Can be completed in one agent session
- **Testable**: Has clear acceptance criteria
- **Independent**: Minimal dependencies on other tasks
- **Sized right**: Not too small (noise) or too large (context death)

## Review Stages

### Stage 1: Spec Compliance (spec-reviewer, haiku)
- Does it do what was asked?
- Any scope creep?
- Any missing requirements?

### Stage 2: Code Quality (code-reviewer, opus)
- Is it well-written?
- Error handling?
- Edge cases?

## Batch Checkpoint Decision Tree

```
All tasks in batch complete?
├── No → Wait for remaining
└── Yes →
    All reviews pass?
    ├── No →
    │   Retry count < 3?
    │   ├── Yes → Retry failed tasks
    │   └── No → Escalate to Klaus or human
    └── Yes →
        Present results to human
        └── Human decides: [Accept] [Revise] [Retry]
```

## References

See references/ for:
- task-decomposition.md - How to break down plans
- review-criteria.md - What reviewers check
- batch-patterns.md - Checkpoint decision patterns
- dependency-failure-chains.md (S-7) - When dependent tasks fail
- branch-collision-detection.md (S-8) - Preventing duplicate branches
- branch-guard-recovery.md (S-9) - Recovering from branch guard failures
- batch-size-verification.md (S-10) - Validating batch sizes before execution
- review-conflict-matrix.md (S-11) - Handling reviewer disagreements
- task-branch-recovery.md (S-12) - Recovering orphaned task branches
```

---

### 6. hooks/hooks.json (Execute Section)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "sequence": 1,
        "matcher": "/execute",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/validate-plan-format.sh"
          }
        ]
      },
      {
        "sequence": 2,
        "matcher": "/execute.*(--status|status)",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/execute-status.sh"
          }
        ]
      }
    ],
    "SubagentStart": [
      {
        "sequence": 1,
        "matcher": "babyclaude",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/create-task-branch.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "sequence": 1,
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/git-branch-guard.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "sequence": 1,
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/execute-tracker.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "sequence": 1,
        "matcher": "babyclaude|spec-reviewer|code-reviewer",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/task-completion-capture.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "sequence": 1,
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/batch-checkpoint-gate.sh"
          }
        ]
      }
    ]
  }
}
```

---

## State Merge Pattern (GOSPEL)

When executing a batch with multiple babyclaude agents:

```
/execute spawns babyclaude per task (context: fork)
    │
    ├── SubagentStart hook creates branch: execute/task-N-slug
    │
    ├── SubagentStop hook captures to:
    │     .claude/agent-outputs/tasks/babyclaude-{task-id}.json
    │
    ├── Command waits for all tasks in batch
    │
    ├── Command merges results (jq in command, NOT hook):
    │     jq -s 'group_by(.task_id) | map(add)' .claude/agent-outputs/tasks/*.json
    │
    ├── Run spec-reviewer on each, then code-reviewer
    │
    └── Merged summary feeds to AskUserQuestion checkpoint
```

**Key principle:** Commands own merge logic. Hooks are passive collectors.

---

## State Tracking

### execute-state.json

```json
{
  "plan_source": "docs/plans/feature-x.md",
  "session_id": "execute-2026-01-16-1030",
  "started_at": "2026-01-16T10:30:00Z",
  "current_batch": 1,
  "batches": [
    {
      "batch_id": 1,
      "tasks": ["task-1", "task-2"],
      "status": "in_progress",
      "human_approved": false
    }
  ],
  "tasks": {
    "task-1": {
      "title": "Create auth middleware",
      "branch": "execute/task-1-auth-middleware",
      "status": "completed",
      "subagent_id": "agent-abc123",
      "files_changed": ["src/middleware/auth.ts"],
      "files_hash": "sha256:abc123...",
      "review": {
        "spec": "PASS",
        "code": "PASS",
        "confidence": 92
      }
    }
  },
  "stuck_detection": {
    "task-2": {
      "retry_count": 0,
      "last_progress_at": "2026-01-16T10:50:00Z",
      "tool_calls_since_progress": 5
    }
  }
}
```

### execute-log.jsonl (Append-Only Log) (C-10, C-11)

Prevents session collision and enables audit trail:

```jsonl
{"timestamp":"2026-01-16T10:30:00Z","session_id":"execute-2026-01-16-1030","event":"session_start","command":"/execute"}
{"timestamp":"2026-01-16T10:31:00Z","session_id":"execute-2026-01-16-1030","event":"task_start","task_id":"task-1","branch":"execute/task-1-auth"}
{"timestamp":"2026-01-16T10:35:00Z","session_id":"execute-2026-01-16-1030","event":"tool_use","tool":"Edit","file":"src/auth.ts"}
{"timestamp":"2026-01-16T10:40:00Z","session_id":"execute-2026-01-16-1030","event":"task_complete","task_id":"task-1","status":"complete"}
{"timestamp":"2026-01-16T10:41:00Z","session_id":"execute-2026-01-16-1030","event":"review_start","task_id":"task-1","reviewer":"spec-reviewer"}
```

**Append pattern in execute-tracker.sh:**

```bash
#!/bin/bash
# Append-only logging for session collision prevention (C-10)
LOG_FILE="$PROJECT_DIR/.claude/execute-log.jsonl"
SESSION_ID="${EXECUTE_SESSION_ID:-unknown}"
TOOL_NAME="${TOOL_NAME:-unknown}"

jq -nc --arg ts "$(date -Iseconds)" \
  --arg sid "$SESSION_ID" \
  --arg tool "$TOOL_NAME" \
  '{timestamp: $ts, session_id: $sid, event: "tool_use", tool: $tool}' \
  | tee -a "$LOG_FILE"
```

---

## Stuck Detection

| Signal | Threshold | Response |
|--------|-----------|----------|
| Tool call flooding | 20 calls without file changes | Warning, then Klaus |
| Time without progress | 10 minutes | Warning, then Klaus |
| Repeated failures | Same error 3x | Pause, offer Klaus |
| Context burn rate | ACM at 60% | Checkpoint offer |
| Review timeout (A-4) | 5 minutes per reviewer | Show progress, offer [Wait] [Skip] |

---

## Agent Robustness Patterns (A-6 through A-11)

### SubagentStop Hook Failure (A-6)

```bash
# In task-completion-capture.sh
BACKUP_DIR="$PROJECT_DIR/.claude/agent-outputs/backup"
mkdir -p "$BACKUP_DIR"

# Primary capture location
PRIMARY="$PROJECT_DIR/.claude/agent-outputs/tasks/${AGENT_NAME}-${TASK_ID}.json"

# Always write to backup first
if ! echo "$AGENT_OUTPUT" > "$BACKUP_DIR/${AGENT_NAME}-$(date +%s).json"; then
  echo "ERROR: Failed to write backup" >&2
  exit 2
fi

# Then move to primary
mv "$BACKUP_DIR/${AGENT_NAME}-$(date +%s).json" "$PRIMARY" || exit 2
```

### Malformed JSON Output (A-7)

```bash
# Validate required fields before accepting agent output
REQUIRED_FIELDS='["task_id", "status"]'

if ! jq -e --argjson required "$REQUIRED_FIELDS" \
  'all($required[]; . as $f | has($f))' "$OUTPUT_FILE"; then
  echo "ERROR: Agent output missing required fields" >&2
  echo "Required: $REQUIRED_FIELDS" >&2
  echo "Got: $(jq keys "$OUTPUT_FILE")" >&2
  exit 2
fi
```

### Task Branch Directory Export (A-8)

```bash
# In create-task-branch.sh
export TASK_BRANCH_DIR="$PROJECT_DIR"
export TASK_BRANCH_NAME="execute/task-${TASK_ID}-${SLUG}"

# Verify directory exists before agent starts
if [ ! -d "$TASK_BRANCH_DIR" ]; then
  echo "ERROR: Task branch directory does not exist" >&2
  exit 2
fi
```

### Model Rate Limiting (A-10)

If Opus is rate limited:
1. Notify human: "Opus rate limited. Options:"
2. Offer [Wait 60s] [Use Sonnet fallback] [Abort]
3. If Sonnet fallback chosen, add caveat to review output

### Context Exhaustion Mid-Task (A-11)

If context approaches limit during task:
1. Output partial state to checkpoint file
2. Include `"next_steps": ["remaining work description"]`
3. Mark task as `"status": "partial"`
4. Command can resume from checkpoint

---

## Plugin Integrations

| Plugin | Role | Integration Point |
|--------|------|-------------------|
| **tool-executor** | Implementation efficiency | babyclaude uses search_tools |
| **ACM** | Context monitoring | Handoff at 60% |
| **Klaus** | Stuck escalation | After max retries |

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Agents | 3 (babyclaude, spec-reviewer, code-reviewer) |
| Human checkpoints | 3 per batch (start, review, merge) |
| Branch isolation | One branch per task |
| Review stages | 2 (spec then quality) |
| Stuck detection | Time + tool calls + retries |
| Context survival | ACM + PreCompact |

---

## What We're NOT Building

| Killed | Why |
|--------|-----|
| Fully parallel execution | Merge conflicts, coordination overhead |
| Single mega-reviewer | Two-stage catches different issues |
| Auto-merge on pass | Human should approve merges |
| Complex retry logic | Max 2-3 retries, then escalate |
| In-agent git management | Orchestrator owns branches |

---

## Next Step Suggestion

At the end of `/execute`, Claude says:

```
Done! All tasks complete.

When you're ready:
  /verify
```

---

## Build Checklist

- [ ] Create git-workflow/SKILL.md
- [ ] Create git-workflow/references/*.md (3 files)
- [ ] Create babyclaude.md agent
- [ ] Create spec-reviewer.md agent
- [ ] Create code-reviewer.md agent
- [ ] Update hooks.json with execute hooks
- [ ] Create execute-status.sh hook
- [ ] Create create-task-branch.sh hook
- [ ] Create git-branch-guard.sh hook
- [ ] Create execute-tracker.sh hook
- [ ] Create task-completion-capture.sh hook
- [ ] Create batch-checkpoint-gate.sh hook
- [ ] Create execute.md command
- [ ] Test with real execution task
