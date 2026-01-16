# CLAUDIKINS KERNEL - FINAL CONSENSUS SYNTHESIS

**Date:** 2026-01-15
**Panel:** 8 Claudikins Gurus (Opus 4.5) - 5 Rounds Complete
**Status:** FINAL CONSENSUS - Ready for Implementation
**Confidence:** Unanimous (all 18 points agreed)

---

## EXECUTIVE SUMMARY

The panel has synthesized Boris's workflow into a complete system:

**The 4-Command Lifecycle:**
```
/plan [brief]          → Iterative planning with 5 phases + human checkpoints
    ↓
/execute [plan]        → Fresh subagent per task, 2-stage review
    ↓
/verify                → Automated checks + catastrophiser sees code working
    ↓
/ship                  → Pre-ship gate, GRFP docs, commit, PR, merge
```

**Foundation:** v2.1.7 (all 11 hooks available)
**Philosophy:** Opus 4.5 everywhere. Tool-executor mandatory. Evidence before assertions.
**Scaling:** 5-7 agents per session (not 30). Features are the unit of work.

---

## CONSENSUS POINTS (18 TOTAL - UNANIMOUS)

### Architecture (6 points)

**1. Exit code 2 is P1, not P0 (gates, not priority ordering)**
- Exit 2 = gates behaviour: blocks tool use, feeds stderr back to Claude
- Not about priority levels - it's enforcement mechanism
- Used by /verify gate, /ship gate, conflict checks
- Two-layer enforcement (SessionStart + PreToolUse)

**2. PreCompact ALWAYS fires (mandatory safety net)**
- ACM handles context monitoring throughout
- ACM prompts handoff at 60% threshold
- PreCompact is fallback only if ACM disabled
- All 4 commands have PreCompact hook for state save

**3. Hook sequencing: sequence field + 7-rule definition**
- `"sequence": 1, 2, 3...` field in hooks.json
- Fires in order: SessionStart → UserPromptSubmit → SubagentStart → SubagentStop → PreToolUse → PostToolUse → Stop → PermissionRequest → PreCompact
- SubagentStart exists (v2.0.43, poorly documented)
- PermissionRequest exists (v2.0.45)
- Hooks are passive; commands own orchestration logic

**4. Skills → Agents → Hooks → Commands build order**
- Build in this sequence: Skills provide knowledge, agents are executors, hooks enforce patterns, commands orchestrate
- No circular dependencies
- Skills referenced in agent frontmatter
- Hooks defined in hooks.json (central, not per-agent)

**5. jq group_by for merges in command, not hooks**
- Hooks are passive collectors only (SubagentStop writes to `.claude/agent-outputs/{agent-id}.json`)
- Commands own merge logic: `jq -s 'reduce .[] as $item ({}; . * $item)' .claude/agent-outputs/*.json`
- Pattern: Spawn - Collect - Merge - Checkpoint (GOSPEL)

**6. tool-executor is load-bearing (declare as dependency)**
- Without it, 96 MCP tools are invisible to Claude
- Protocol: search_tools → get_tool_schema → execute_code
- Must be pre-allowed in .claude/settings.json
- Injected via SessionStart hook for all agents

### Patterns (5 points)

**7. Declarative skill triggers in SKILL.md metadata**
- Skills have `triggers` field for autonomous activation
- Skills have `modes` field ONLY for multi-concern skills
- Skills have `version` field
- Skills are ~200 lines max, progressive disclosure

**8. Agent output contracts in command frontmatter with JSON schema**
- Commands define what agent must deliver
- JSON schema enforces structure
- Example blocks required for all agents
- background: true ONLY for evidence-producing agents (catastrophiser, cynic, git-perfectionist)

**9. `<example>` blocks required for all agents**
- Triggers showing when agent activates
- Context + user message + assistant response + commentary
- Critical for understanding when agent is useful

**10. Spawn-Collect-Merge-Checkpoint is GOSPEL**
```
Commands spawn forked agents
    ↓
SubagentStop hooks capture to .claude/agent-outputs/{agent-id}.json
    ↓
Command waits for all agents, then merges with jq
    ↓
Command calls AskUserQuestion with merged state
    ↓
Human sees merged summary, decides once
```
This is the only pattern for parallel agents.

**11. skill-discovery-first is CONDITIONAL P0**
- If multiple tools exist in MCP, search first (tool-executor)
- If single tool or well-known (npm test, cargo test), direct use OK
- Use when: planning research, exploring architecture, finding patterns
- Skip when: task is clear and tools are obvious

### Documentation (7 points)

**12. v2.1.7 baseline (all 11 hooks available)**
- SessionStart, UserPromptSubmit, SubagentStart, SubagentStop
- PreToolUse, PostToolUse, Stop, PermissionRequest
- PreCompact, Notification (+ bonus: SessionEnd, internal architecture)
- No reliance on features beyond v2.1.7

**13. Docs: frontmatter + examples, not full prompts**
- Frontmatter (YAML) specifies structure
- Examples show triggering conditions
- References/ subdirectory for deep knowledge
- Do NOT include full agent/command prompts in docs (they're read from files)

**14. Status field for commands AND agents (stable/preview/planned/deprecated)**
- All components have status field
- Guides users on maturity
- Enables deprecation warnings

**15. modes field for MULTI-CONCERN skills ONLY**
- taxonomy-extremist has modes: codebase | docs | external
- git-workflow does NOT have modes (single concern)
- Reduces complexity

**16. sequence field in hooks.json with format "sequence": 1**
```json
{
  "hooks": {
    "SessionStart": [
      { "sequence": 1, "command": "..." }
    ]
  }
}
```
Enforces ordering within same event type.

**17. merge_strategy in command frontmatter**
- `merge_strategy: jq | concat | none`
- Commands declare how they handle parallel outputs
- Defaults to jq for structured data

**18. 8 documentation deliverables identified**
1. README.md (architecture overview)
2. UPGRADING.md (migration guide from v0 → v1)
3. plugin.json completeness (version, dependencies, keywords)
4. Hook lifecycle reference table
5. manifest.json (.claude/ directory metadata)
6. settings.json example (permissions whitelist)
7. .claude/rules/ templates (planning, execution, verification, git, tools)
8. State schema reference (plan-state, execute-state, verify-state, ship-state)

---

## BUILD ORDER & PRIORITIES

### P0 - CRITICAL (Gates Foundation)

| # | Component | Status | Dependencies |
|---|-----------|--------|--------------|
| 1 | brain-jam/SKILL.md | Design | None |
| 2 | git-workflow/SKILL.md | Design | None |
| 3 | strict-enforcement/SKILL.md | Design | None |
| 4 | taxonomy-extremist.md | Code | tool-executor plugin |
| 5 | babyclaude.md | Code | None |
| 6 | spec-reviewer.md | Code | None |
| 7 | code-reviewer.md | Code | None |
| 8 | catastrophiser.md | Code | None |
| 9 | hooks.json + session-init.sh | Code | None |
| 10 | plan.md | Code | 1-9 |
| 11 | execute.md | Code | 1-9 |
| 12 | verify.md | Code | 1-9 |
| 13 | ship.md | Code | 1-9 |

**Rationale:** These are the 4-command workflow. Foundation everything depends on.

### P1 - IMPORTANT (Velocity Multipliers)

| # | Component | Status | Dependencies |
|---|-----------|--------|--------------|
| 14 | cynic.md | Code | catastrophiser |
| 15 | /commit-push-pr command | Code | None |
| 16 | /learn command | Code | None |
| 17 | escalation-patterns/SKILL.md | Design | None |
| 18 | auto-format.sh hook | Code | PostToolUse |
| 19 | notify-ready.sh hook | Code | Stop |
| 20 | auto-approve-safe.sh hook | Code | PermissionRequest |

**Rationale:** 2x-3x velocity multipliers. Used dozens of times daily (e.g., /commit-push-pr).

### P2 - NICE-TO-HAVE (Resilience)

| # | Component | Status | Dependencies |
|---|-----------|--------|--------------|
| 21 | conflict-resolver.md | Code | bash, git |
| 22 | /worktree command | Code | None |
| 23 | /finish command | Code | None |
| 24 | conflict-resolution/SKILL.md | Design | None |
| 25 | Klaus integration (optional) | Integration | None |

**Rationale:** Handles edge cases and resilience. Good-to-have, not critical.

---

## FILES TO CREATE (41 TOTAL)

### Commands (7)
- `commands/plan.md`
- `commands/execute.md`
- `commands/verify.md`
- `commands/ship.md`
- `commands/commit-push-pr.md`
- `commands/learn.md`
- `commands/worktree.md`

### Agents (8)
- `agents/taxonomy-extremist.md`
- `agents/babyclaude.md`
- `agents/spec-reviewer.md`
- `agents/code-reviewer.md`
- `agents/catastrophiser.md`
- `agents/cynic.md`
- `agents/conflict-resolver.md`
- `agents/git-perfectionist.md`

### Skills (5 folders, 20 files)
```
skills/
├── brain-jam/
│   ├── SKILL.md
│   └── references/
│       ├── plan-checklist.md
│       ├── approach-template.md
│       └── plan-format.md
├── git-workflow/
│   ├── SKILL.md
│   └── references/
│       ├── task-decomposition.md
│       ├── review-criteria.md
│       └── batch-patterns.md
├── strict-enforcement/
│   ├── SKILL.md
│   └── references/
│       ├── verification-checklist.md
│       ├── red-flags.md
│       ├── agent-integration.md
│       └── advanced-verification.md
├── escalation-patterns/
│   ├── SKILL.md
│   └── references/
│       ├── stuck-signals.md
│       ├── klaus-briefing.md
│       └── escalation-format.md
└── conflict-resolution/
    ├── SKILL.md
    └── references/
        ├── conflict-markers.md
        └── resolution-strategies.md
```

### Hooks (1 file + 12 scripts)
- `hooks/hooks.json`
- `hooks/session-init.sh`
- `hooks/plan-phase-detector.sh`
- `hooks/plan-verify.sh`
- `hooks/execute-status.sh`
- `hooks/create-task-branch.sh`
- `hooks/git-branch-guard.sh`
- `hooks/auto-format.sh`
- `hooks/execute-tracker.sh`
- `hooks/task-completion-capture.sh`
- `hooks/batch-checkpoint-gate.sh`
- `hooks/notify-ready.sh`
- `hooks/auto-approve-safe.sh`

### Documentation (4)
- `README.md`
- `UPGRADING.md`
- `plugin.json`
- `.claude/MANIFEST.md`

### Templates & Rules (2 folders)
```
templates/
├── settings.json
└── .claude/rules/
    ├── planning.md
    ├── execution.md
    ├── verification.md
    ├── git-workflow.md
    └── tool-usage.md
```

---

## P0/P1/P2 DISTRIBUTION

| Priority | Count | Purpose | Timeline |
|----------|-------|---------|----------|
| P0 | 13 files | 4-command workflow (plan, execute, verify, ship) | Week 1-2 |
| P1 | 7 files | Velocity multipliers (commit-push-pr, learn, auto-format) | Week 2-3 |
| P2 | 21 files | Edge cases & resilience (conflict-resolver, worktree) | Week 3-4 |

---

## WHAT WE'RE NOT BUILDING

| Killed | Why | Impact |
|--------|-----|--------|
| 6-agent gauntlet | One thorough reviewer beats five shallow ones | Simplicity |
| Tool lists per phase | Tool-executor + Claude figures it out | Flexibility |
| Linear-only flow | Humans can jump to any phase | Non-linear planning |
| Verification at end only | Available anytime via flags | Iterative confidence |
| Custom state machine | Minimal JSON state, derive everything else | Maintainability |
| Auto-merge on pass | Human should approve merges | Safety |
| Ship without verify | Gate must be enforced | Production safety |
| In-agent git management | Orchestrator (command) owns branches | Single responsibility |
| 30 agents per batch | 5-7 agents per session (features are the unit) | Coordination simplicity |

---

## KEY TECHNICAL RULES

### Rule 1: Hook Sequencing
Hooks fire in this order within a session:
1. SessionStart (initialization)
2. UserPromptSubmit (phase detection)
3. SubagentStart (branch creation for tasks)
4. SubagentStop (capture outputs)
5. PreToolUse (validation before tools)
6. PostToolUse (formatting, tracking)
7. Stop (checkpoints, gates)
8. PermissionRequest (auto-approval)
9. PreCompact (state save)

### Rule 2: Spawn-Collect-Merge Pattern
```bash
# Spawn multiple agents
for agent in taxonomy-extremist-1 taxonomy-extremist-2; do
  spawn_agent $agent
done

# Hooks collect to files
# .claude/agent-outputs/taxonomy-extremist-1.json
# .claude/agent-outputs/taxonomy-extremist-2.json

# Command merges
jq -s 'reduce .[] as $item ({}; . * $item)' .claude/agent-outputs/taxonomy-extremist-*.json

# Human decides on merged output
ask_user_question "Review findings. Continue?"
```

### Rule 3: Exit Code 2 Enforcement
```bash
# Gate check script
if [ condition_not_met ]; then
  echo "Error message" >&2
  exit 2  # Blocks tool use, feeds stderr to Claude
fi
exit 0   # Continue
```

### Rule 4: Tool-Executor Protocol
```
For any MCP tool discovery:
1. search_tools("domain query")  # Find relevant tools
2. get_tool_schema(tool_name)    # Understand tool signature
3. execute_code(tool_call)       # Use the tool
```

### Rule 5: State Merge in Commands Only
- Hooks: `SubagentStop` writes to unique file
- Commands: own the `jq` merge logic
- Never have hooks merge (they're passive)

### Rule 6: Opus 4.5 Everywhere
- No haiku for judgement calls
- No sonnet for final decisions
- catastrophiser, cynic, git-perfectionist: all opus
- Spec-reviewer is the only haiku (purely mechanical)

### Rule 7: One Task = One Fresh Context
- `context: fork` creates isolated context
- Task context doesn't pollute global state
- After SubagentStop, context discarded
- Next task gets clean slate

---

## INTEGRATION CHECKLIST

### Plugins (Required)
- [ ] **tool-executor** - 96 MCP tools, search_tools protocol
- [ ] **ACM** (Automatic Context Manager) - monitors at 60%
- [ ] **Klaus** (optional) - devil's advocate escalation

### Version Requirements
- [ ] Claude Code v2.1.7+ (all 11 hooks)
- [ ] Opus 4.5 model available
- [ ] git 2.13+ (worktree support)
- [ ] gh CLI (GitHub PR creation)

### Environment
- [ ] CLAUDE_PROJECT_DIR set
- [ ] CLAUDE_ENV_FILE for session vars
- [ ] .claude/ directory writable
- [ ] .gitignore includes .claude/, .worktrees/

---

## KEY QUOTES TO REMEMBER

> "Modular agents in parallel beats any single perfect system. Ship it, iterate." - boris-guru

> "Hooks create feedback loops - living workflow automation." - hooks-guru

> "Frontmatter + tools + agents. That's why it works." - commands-guru

> "Give Claude a tool to see the output of the code." - Boris (on catastrophiser)

> "I'd use 5-7 agents per SESSION, not 30 per batch." - boris-guru

> "Exit code 2 is the key." - hooks-guru

> "Planning is a conversation, not a production line." - Panel consensus

> "Evidence before assertions. Always." - Verification philosophy

---

## NEXT STEPS (IMMEDIATE)

**Week 1 Action Items:**
1. Create brain-jam, git-workflow, strict-enforcement skills
2. Create taxonomy-extremist, babyclaude, spec-reviewer, code-reviewer agents
3. Create hooks.json + session-init.sh
4. Create /plan command (full 5-phase flow)
5. Test /plan on real planning task

**Success Metrics for P0:**
- [ ] /plan completes iterative 5-phase flow
- [ ] taxonomy-extremist agents spawn in parallel (context: fork)
- [ ] SubagentStop hook captures outputs to .claude/agent-outputs/
- [ ] Command merges with jq, presents to human
- [ ] Human can iterate on plan

---

## IMPLEMENTATION NOTE

This consensus represents **unanimous agreement from 8 specialized gurus** after 5 rounds of debate. Every point has been challenged, refined, and re-examined. The architecture is:

- **Simple:** 4 commands, 8 agents, 5 skills, 13 hooks
- **Modular:** Each component has single responsibility
- **Verified:** Evidence before assertions throughout
- **Scalable:** 5-7 agents per session, not 30
- **Opinionated:** Boris's workflow, not a framework to build on

Build in P0 order. Don't skip steps. Test with real tasks.

---

**Document Created:** 2026-01-15
**Panel:** boris-guru, hooks-guru, commands-guru, skills-guru, agents-guru
**Advisors:** changelog-guru, docs-guru, claude-code-guru
**Status:** READY FOR IMPLEMENTATION
