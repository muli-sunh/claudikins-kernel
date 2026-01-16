# CLAUDIKINS-KERNEL RECONCILIATION

**Date:** 2026-01-16
**Purpose:** Resolve contradictions between guru panel consensus and plan documents
**Authoritative Source:** guru-panel-final-consensus.md (with corrections noted below)

---

## EXECUTIVE SUMMARY

After comparing all guru panel docs against the plan architectures, this document:
1. Identifies contradictions and gaps
2. Provides FINAL authoritative lists for implementation
3. Maps cross-plugin dependencies
4. Establishes the TRUE build order

---

## ARCHITECTURE CONTEXT

claudikins-kernel is the **core hub** that orchestrates the claudikins plugin ecosystem:

```
claudikins-kernel (workflow orchestration)
    ├── REQUIRES → claudikins-tool-executor (MCP access, 96 tools)
    ├── REQUIRES → claudikins-automatic-context-manager (60% threshold)
    ├── OPTIONAL → claudikins-klaus (devil's advocate)
    ├── LEVERAGES → claudikins-github-readme (GRFP pattern for docs)
    └── INTEGRATES → claudikins-marketplace (plugin registry)
```

**Key principle:** Kernel owns workflows, plugins provide expertise. The kernel applies patterns (like GRFP) across different stages, delegating to specialist plugins where appropriate.

---

## CONTRADICTIONS RESOLVED

### 1. AGENTS - RESOLVED

**Problem:** Multiple agent lists disagreed.

| Source | Listed |
|--------|--------|
| Final Consensus | 8 agents |
| Complete-additions | 6 agents (includes "realist") |
| Ship architecture | 3 extra agents (pipeline-purist, no-commitment-issues) |
| Verify architecture | includes "realist" |

**Resolution:**

| Agent | Status | Rationale |
|-------|--------|-----------|
| taxonomy-extremist | ✅ KEEP | Research agent for /plan |
| babyclaude | ✅ KEEP | Task implementer for /execute |
| spec-reviewer | ✅ KEEP | Spec compliance (haiku) |
| code-reviewer | ✅ KEEP | Code quality (opus, NOT sonnet) |
| catastrophiser | ✅ KEEP | Output verification for /verify |
| cynic | ✅ KEEP (P1) | Polish pass for /verify |
| conflict-resolver | ✅ KEEP (P2) | Merge conflict handling |
| git-perfectionist | ✅ KEEP | GRFP docs for /ship |
| realist | ❌ KILL | Not in consensus, unclear purpose, redundant with catastrophiser |
| pipeline-purist | ❌ KILL | Merge into git-perfectionist or /ship command logic |
| no-commitment-issues | ❌ KILL | Merge into /ship command logic |

**FINAL AGENT COUNT: 8**

---

### 2. SKILLS - RESOLVED

**Problem:** Final consensus lists 5 skills but ship architecture references shipping-methodology.

**Resolution:** Final consensus is INCOMPLETE. shipping-methodology IS needed.

| Skill | Status | Purpose |
|-------|--------|---------|
| brain-jam | ✅ KEEP | Planning methodology |
| git-workflow | ✅ KEEP | Execution methodology |
| strict-enforcement | ✅ KEEP | Verification methodology |
| escalation-patterns | ✅ KEEP | When/how to escalate |
| conflict-resolution | ✅ KEEP | Merge conflict handling |
| shipping-methodology | ✅ ADD | GRFP-style pattern for shipping stages |

**GRFP Pattern Application:**
- shipping-methodology defines HOW to apply GRFP-style iterative workflow to each shipping stage
- For actual docs generation, it delegates to claudikins-github-readme plugin
- Pattern: iterative, section-by-section, human-checkpoints at each stage

**FINAL SKILL COUNT: 6**

---

### 3. COMMANDS - RESOLVED

**Problem:** "finish" appears in complete-additions but not consensus.

**Resolution:**

| Command | Status | Rationale |
|---------|--------|-----------|
| /plan | ✅ KEEP | Core workflow |
| /execute | ✅ KEEP | Core workflow |
| /verify | ✅ KEEP | Core workflow |
| /ship | ✅ KEEP | Core workflow |
| /commit-push-pr | ✅ KEEP | Boris's most-used, velocity multiplier |
| /learn | ✅ KEEP | Capture learnings to CLAUDE.md |
| /worktree | ✅ KEEP (P2) | Parallel execution setup |
| /finish | ❌ KILL | Redundant with /ship, unclear differentiation |

**FINAL COMMAND COUNT: 7**

---

### 4. MODEL ASSIGNMENTS - RESOLVED

**Problem:** Final consensus says "Opus everywhere" but code-reviewer uses sonnet.

**Consensus Rule 6:**
> "No haiku for judgement calls. No sonnet for final decisions. Spec-reviewer is the only haiku (purely mechanical)."

**Resolution:**

| Agent | Model | Rationale |
|-------|-------|-----------|
| taxonomy-extremist | sonnet | Research, not judgement |
| babyclaude | sonnet | Implementation, not judgement |
| spec-reviewer | haiku | Purely mechanical compliance check |
| code-reviewer | **opus** | Quality judgement - UPGRADE from sonnet |
| catastrophiser | opus | Critical verification |
| cynic | opus | Simplification judgement |
| conflict-resolver | opus | Merge decisions |
| git-perfectionist | opus | Documentation quality |

**Action:** Update execute-command-architecture.md to change code-reviewer from sonnet to opus.

---

### 5. FILE COUNT - RESOLVED

**Problem:** Different totals across documents.

**Correct count based on reconciled lists:**

| Category | Count |
|----------|-------|
| Commands | 7 |
| Agents | 8 |
| Skills (folders) | 6 |
| Skill reference files | ~18 |
| Hooks (scripts) | 13 |
| hooks.json | 1 |
| Documentation | 4 (README, UPGRADING, plugin.json, MANIFEST) |
| Templates | 2 (settings.json, rules/) |
| Rules files | 5 |
| **TOTAL** | ~60 files |

Note: Higher than consensus's 41 because it didn't fully count skill references and rules.

---

## CROSS-PLUGIN DEPENDENCIES

### Required Plugins (kernel won't function without)

| Plugin | Why Required |
|--------|--------------|
| claudikins-tool-executor | 96 MCP tools invisible without it |
| claudikins-automatic-context-manager | Context monitoring at 60% |

### Optional Plugins (enhance functionality)

| Plugin | Integration Point |
|--------|-------------------|
| claudikins-klaus | Optional review in /plan, escalation when stuck |
| claudikins-github-readme | GRFP for docs stage in /ship |
| claudikins-marketplace | Plugin discovery and management |

### Plugin Skill References

| Kernel Component | Uses From |
|------------------|-----------|
| /plan Phase 5 (review) | Klaus from claudikins-klaus |
| /ship docs stage | GRFP from claudikins-github-readme |
| All research agents | tool-executor from claudikins-tool-executor |
| All commands | ACM monitoring from claudikins-automatic-context-manager |

---

## FINAL AUTHORITATIVE LISTS

### Commands (7)
```
commands/
├── plan.md              # P0 - Iterative planning
├── execute.md           # P0 - Task execution
├── verify.md            # P0 - Verification gate
├── ship.md              # P0 - Ship to production
├── commit-push-pr.md    # P1 - Fast shipping (Boris's favorite)
├── learn.md             # P1 - Capture learnings
└── worktree.md          # P2 - Parallel execution
```

### Agents (8)
```
agents/
├── taxonomy-extremist.md   # P0 - Research (sonnet, read-only)
├── babyclaude.md           # P0 - Implementation (sonnet, write access)
├── spec-reviewer.md        # P0 - Spec compliance (haiku)
├── code-reviewer.md        # P0 - Code quality (opus)
├── catastrophiser.md       # P0 - Output verification (opus)
├── cynic.md                # P1 - Polish pass (opus)
├── git-perfectionist.md    # P0 - GRFP docs (opus)
└── conflict-resolver.md    # P2 - Merge conflicts (opus)
```

### Skills (6 folders)
```
skills/
├── brain-jam/              # P0 - Planning methodology
│   ├── SKILL.md
│   └── references/
│       ├── plan-checklist.md
│       ├── approach-template.md
│       └── plan-format.md
├── git-workflow/           # P0 - Execution methodology
│   ├── SKILL.md
│   └── references/
│       ├── task-decomposition.md
│       ├── review-criteria.md
│       └── batch-patterns.md
├── strict-enforcement/     # P0 - Verification methodology
│   ├── SKILL.md
│   └── references/
│       ├── verification-checklist.md
│       ├── red-flags.md
│       ├── agent-integration.md
│       └── advanced-verification.md
├── shipping-methodology/   # P0 - Shipping methodology (GRFP-style)
│   ├── SKILL.md
│   └── references/
│       ├── commit-message-patterns.md
│       ├── grfp-checklist.md
│       ├── pr-creation-strategy.md
│       └── deployment-checklist.md
├── escalation-patterns/    # P1 - Escalation methodology
│   ├── SKILL.md
│   └── references/
│       ├── stuck-signals.md
│       ├── klaus-briefing.md
│       └── escalation-format.md
└── conflict-resolution/    # P2 - Conflict resolution
    ├── SKILL.md
    └── references/
        ├── conflict-markers.md
        └── resolution-strategies.md
```

### Hooks (14 files)
```
hooks/
├── hooks.json                    # Central hook configuration
├── session-init.sh               # SessionStart - project detection, env vars
├── plan-phase-detector.sh        # UserPromptSubmit - phase context
├── plan-verify.sh                # UserPromptSubmit - on-demand verification
├── execute-status.sh             # UserPromptSubmit - status reporting
├── create-task-branch.sh         # SubagentStart - branch per task
├── inject-tool-context.sh        # SubagentStart - tool-executor access
├── task-completion-capture.sh    # SubagentStop - capture outputs
├── git-branch-guard.sh           # PreToolUse - branch isolation
├── auto-format.sh                # PostToolUse - format on save
├── execute-tracker.sh            # PostToolUse - track file changes
├── batch-checkpoint-gate.sh      # Stop - human approval gate
├── notify-ready.sh               # Stop - desktop notification
├── auto-approve-safe.sh          # PermissionRequest - safe ops whitelist
└── preserve-state.sh             # PreCompact - state save
```

### Documentation (4)
```
├── README.md
├── UPGRADING.md
├── plugin.json
└── .claude/MANIFEST.md
```

### Templates (7 files)
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

## UPDATED BUILD ORDER

### P0 - CRITICAL (Foundation)

| # | Component | Type | Dependencies |
|---|-----------|------|--------------|
| 1 | brain-jam/ | skill | None |
| 2 | git-workflow/ | skill | None |
| 3 | strict-enforcement/ | skill | None |
| 4 | shipping-methodology/ | skill | None |
| 5 | taxonomy-extremist.md | agent | tool-executor plugin |
| 6 | babyclaude.md | agent | None |
| 7 | spec-reviewer.md | agent | None |
| 8 | code-reviewer.md | agent | None |
| 9 | catastrophiser.md | agent | None |
| 10 | git-perfectionist.md | agent | github-readme plugin |
| 11 | hooks.json + session-init.sh | hooks | None |
| 12 | plan.md | command | 1, 5, 11 |
| 13 | execute.md | command | 2, 6, 7, 8, 11 |
| 14 | verify.md | command | 3, 9, 11 |
| 15 | ship.md | command | 4, 10, 11 |

### P1 - IMPORTANT (Velocity)

| # | Component | Type | Dependencies |
|---|-----------|------|--------------|
| 16 | cynic.md | agent | None |
| 17 | escalation-patterns/ | skill | None |
| 18 | commit-push-pr.md | command | None |
| 19 | learn.md | command | None |
| 20 | auto-format.sh | hook | None |
| 21 | notify-ready.sh | hook | None |
| 22 | auto-approve-safe.sh | hook | None |

### P2 - NICE-TO-HAVE (Resilience)

| # | Component | Type | Dependencies |
|---|-----------|------|--------------|
| 23 | conflict-resolver.md | agent | None |
| 24 | conflict-resolution/ | skill | None |
| 25 | worktree.md | command | None |
| 26 | Documentation | docs | All above |
| 27 | Templates | templates | All above |

---

## DOCUMENTS TO UPDATE

Based on this reconciliation:

| Document | Changes Needed |
|----------|----------------|
| guru-panel-final-consensus.md | Add shipping-methodology to skills list |
| execute-command-architecture.md | Change code-reviewer model: sonnet → opus |
| verify-command-architecture.md | Remove realist agent |
| ship-command-architecture.md | Remove pipeline-purist, no-commitment-issues agents |
| complete-additions.md | Update agent list, remove finish command, add shipping-methodology |

---

## KEY DECISIONS RECORDED

1. **GRFP is a pattern, not just a plugin** - shipping-methodology applies GRFP-style workflow to all shipping stages, delegating to github-readme plugin for actual docs generation

2. **Opus for judgement, haiku only for mechanical** - code-reviewer upgraded to opus because quality assessment requires judgement

3. **8 agents, not 6 or 11** - Killed realist (unclear purpose), pipeline-purist and no-commitment-issues (merge into command logic)

4. **7 commands, not 8** - Killed finish (redundant with ship)

5. **6 skills, not 5** - Added shipping-methodology

6. **~60 files total** - More than consensus's 41 because skill references weren't fully counted

---

## CONSENSUS POINTS VERIFICATION

Verified all 18 consensus points are addressed:

| # | Point | Status | Location |
|---|-------|--------|----------|
| 1 | Exit code 2 gates | ✅ | All plan docs |
| 2 | PreCompact always fires | ✅ | hooks/preserve-state.sh |
| 3 | Hook sequence field | ✅ | hooks.json patterns |
| 4 | Build order | ✅ | This doc |
| 5 | jq merge in commands | ✅ | Spawn-Collect-Merge |
| 6 | tool-executor required | ✅ | Dependencies section |
| 7 | Skill triggers | ✅ | Add to SKILL.md template |
| 8 | Agent output contracts | ✅ | Add to command frontmatter |
| 9 | Example blocks | ✅ | Add to agent template |
| 10 | SCMC is GOSPEL | ✅ | Throughout |
| 11 | skill-discovery conditional | ✅ | tool-executor integration |
| 12 | v2.1.7 baseline | ✅ | Consensus reference |
| 13 | Frontmatter + examples | ✅ | Doc format standard |
| 14 | Status field | ✅ | Add to all components |
| 15 | modes for multi-concern | ✅ | taxonomy-extremist only |
| 16 | sequence in hooks.json | ✅ | Hook patterns |
| 17 | merge_strategy | ✅ | Add to command frontmatter |
| 18 | 8 doc deliverables | ✅ | Documentation section |

---

## FRONTMATTER REQUIREMENTS

### Command Frontmatter (must include)
```yaml
---
name: command-name
description: What this command does
argument-hint: [args]
model: opus
color: green
status: stable|preview|planned|deprecated
merge_strategy: jq|concat|none
agent_outputs:
  - agent: agent-name
    capture_to: .claude/agent-outputs/path
    merge_strategy: jq -s 'add'
allowed-tools:
  - Read
  - ...
---
```

### Agent Frontmatter (must include)
```yaml
---
name: agent-name
description: |
  Clear description with triggering examples.
model: opus|sonnet|haiku
color: green
context: fork
status: stable|preview|planned|deprecated
background: true|false
tools:
  - Read
  - ...
disallowedTools:
  - Task
---

<example>
Context: When this agent should be triggered
user: "User message that triggers this"
assistant: "I'll use the agent-name agent to..."
<commentary>
Why this agent is appropriate for this situation.
</commentary>
</example>
```

### Skill Frontmatter (must include)
```yaml
---
name: skill-name
description: When to use this skill
version: "1.0.0"
status: stable|preview|planned|deprecated
triggers:
  keywords:
    - "keyword1"
    - "keyword2"
modes: # ONLY for multi-concern skills like taxonomy-extremist
  - codebase
  - docs
  - external
---
```

---

## NEXT STEPS

1. [ ] Update the 5 documents listed above with corrections
2. [ ] Add status field to all existing component specs
3. [ ] Add merge_strategy to command frontmatter
4. [ ] Ensure all agents have `<example>` blocks
5. [ ] Begin P0 implementation in build order
6. [ ] Validate exit code 2 behaviour before implementing gates
7. [ ] Test Spawn-Collect-Merge-Checkpoint pattern

---

## BORIS'S 15 WORKFLOW GAPS (from Session 2)

These were identified by boris-guru and should be tracked:

### P0 (Critical)
| # | Gap | Status | Where Addressed |
|---|-----|--------|-----------------|
| 1 | Round-robin agent management + notifications | ✅ | notify-ready.sh hook |
| 2 | Rapid iteration (--fast-mode) | ⚠️ | Add to command flags |
| 3 | Session resume/fork (--session-id) | ⚠️ | Add to command flags |
| 4 | Worktree parallelism | ✅ | /worktree command (P2) |
| 5 | Tool-discovery-first | ✅ | tool-executor integration |

### P1 (Important)
| # | Gap | Status | Where Addressed |
|---|-----|--------|-----------------|
| 6 | Klaus escalation triggers | ✅ | escalation-patterns skill |
| 7 | Commit-push-pr enhancements | ✅ | /commit-push-pr command |
| 8 | Verification output visibility | ✅ | catastrophiser state capture |
| 9 | Batch multi-select checkpoints | ⚠️ | Add to /execute |
| 10 | Conflict-resolver auto-trigger | ✅ | conflict-resolver agent |

### P2 (Nice-to-have)
| # | Gap | Status | Where Addressed |
|---|-----|--------|-----------------|
| 11 | State auditing trail | ⚠️ | Add .claude/audit/ |
| 12 | GRFP templates | ✅ | github-readme plugin |
| 13 | Cross-session learning | ⚠️ | Consider project-learnings skill |
| 14 | Performance timing (--timing) | ⚠️ | Add to command flags |
| 15 | Safe auto-approval whitelist | ✅ | auto-approve-safe.sh hook |

**Action Items:**
- [ ] Add --fast-mode, --session-id flags to all 4 core commands
- [ ] Add batch multi-select to /execute checkpoints
- [ ] Create .claude/audit/ directory structure
- [ ] Consider project-learnings skill for P2
- [ ] Add --timing flag for performance tracking

---

## PRE-IMPLEMENTATION VALIDATION (from Marketplace Consensus)

**Must validate these 5 behaviours before P0 implementation:**

| # | Test | Time | Purpose |
|---|------|------|---------|
| 1 | Sequence field ordering | 30 min | Hooks fire in correct order |
| 2 | Exit code 2 blocks tool use | 20 min | Gates actually work |
| 3 | SubagentStop writes to file | 20 min | Output capture works |
| 4 | jq merge works | 15 min | Spawn-Collect-Merge pattern |
| 5 | context: fork isolation | 30 min | Forked agents don't pollute |

**Total validation time: ~2 hours**

These are BLOCKERS. If any fail, the entire verification model breaks.

---

## DOCUMENTATION WORK ESTIMATE (from Marketplace Consensus)

| Document | Time | Priority |
|----------|------|----------|
| STATE-MERGE-ARCHITECTURE.md | 1h | P0 |
| HOOK-LIFECYCLE-REFERENCE.md | 1.5h | P0 |
| PLUGIN-LOADING-SPEC.md | 2h | P1 |
| TESTING-GUIDE.md | 2.5h | P1 |
| FAST-MODE-SPEC.md | 45m | P1 |
| Klaus plugin spec | 1h | P2 |
| **Total** | ~8.5h | - |

---

**Document Status:** AUTHORITATIVE
**Supersedes:** All previous counts and lists in other documents
