# /plan Command Audit Findings

**Date:** 2026-01-15
**Audited by:** 8 Claudikins Gurus (Opus 4.5)
**Project:** claudikins-kernel

---

## Original Design (Problems Identified)

```
brain-jam → research → gauntlet (5 agents) → output
```

| Component | Count |
|-----------|-------|
| Specialist agents | 6 (security, edge-case, scope, architecture, ops, researcher) |
| Skills | 8 (methodology + one per agent) |
| Files | 15+ |
| Human checkpoints | 0 |

### Fatal Flaws

1. **No verification built in**
2. **One-shot, not iterative** (Boris iterates until good, THEN executes)
3. **Over-engineered** (Boris uses 2 subagents, we had 6 just for planning)
4. **Human not in the loop** during planning
5. **Not reusable** as inner loop

---

## Guru Verdicts

### Boris Guru
> "You've built a machine, not a conversation."

- Planning is **interactive and iterative**, not a pipeline
- Boris uses 2 subagents total (code-simplifier, verify-app) - for execution, not planning
- "Go back and forth with Claude until I like its plan"
- Verification is "probably the most important thing"

**Key quote:**
> "I think people sometimes over-complicate it."

### CC Guru (Official Plugins)
> "Missing human checkpoints. feature-dev has 5 WAIT points."

- feature-dev uses 3 agents (explorer, architect, reviewer), not 6
- Agents do **parallel exploration** of same question, not sequential phases
- Every phase ends with explicit human checkpoint
- Pattern: "CRITICAL: DO NOT SKIP... Wait for answers before proceeding"

### Docs Guru
> "Use built-in Plan Mode + AskUserQuestion. Don't reinvent."

- Official pattern: Plan Mode → AskUserQuestion → ExitPlanMode → Execute
- **Critical constraint:** Subagents cannot spawn other subagents
- Main conversation for iterative refinement; subagents for isolated research
- Use Stop hooks with prompt-based verification

### Skills Guru
> "Skills are encyclopedias, not workflows."

- Working skills are self-contained domain knowledge
- Checklists for verification, not agent gauntlets
- SKILL.md under 500 lines, progressive disclosure
- Skills provide **what** to check; commands provide **how** to flow

### Agents Guru
> "One reviewer, not a gauntlet."

- Zero official examples use multi-agent gauntlets
- plan-reviewer (Opus) covers all concerns in one thorough pass
- Agents are single-responsibility executors
- Pattern: Main Claude creates → reviewer validates → human decides → iterate

### Commands Guru
> "Missing 'Wait for user response' - 5 words repeated throughout working commands."

- Working commands have explicit STOP points
- AskUserQuestion at every phase gate
- "DO NOT START WITHOUT APPROVAL"
- Planning is a conversation, not a pipeline

### Hooks Guru
> "Exit code 2 is the key."

- Stop hooks block and feed feedback to Claude
- Session state tracks verified phases
- PostToolUse tracks artifacts created
- Hooks enforce verification gates, not agents

### Changelog Guru
> "v2.1+ already provides everything you need."

| Feature | Version | Purpose |
|---------|---------|---------|
| `context: fork` | v2.1.0 | Run phases in isolation |
| AskUserQuestion | v2.0.21+ | Native human checkpoints |
| Plan rejection feedback | v2.0.57 | Built-in iteration |
| Skills merged with commands | v2.1.3 | Unified frontmatter |
| SubagentStop hooks | v1.0.41 | Capture agent outputs |

---

## Consensus Architecture

### Principles

1. **Planning is a conversation**, not a production line
2. **Human checkpoints are mandatory**, not optional
3. **One thorough reviewer** beats five shallow specialists
4. **Skills provide knowledge**, commands provide workflow
5. **Hooks enforce verification**, not agents
6. **`context: fork`** for isolation without context pollution

### Recommended Structure

```
/plan [brief]
  │
  ├── Phase 1: Brain-jam (main Claude)
  │     └── AskUserQuestion for requirements
  │     └── STOP: "Confirm understanding?"
  │
  ├── Phase 2: Research (context: fork, optional)
  │     └── 1-2 explorer agents (parallel, different angles)
  │     └── STOP: "Review findings?"
  │
  ├── Phase 3: Draft (main Claude)
  │     └── Guided by planning-methodology skill
  │     └── Section-by-section human approval
  │     └── STOP: "Approve draft?"
  │
  ├── Phase 4: Review (optional, on request)
  │     └── ONE plan-reviewer agent (Opus)
  │     └── OR Klaus for opinionated review
  │     └── STOP: "Iterate or finalise?"
  │
  └── Output: Validated plan with verification checklist
```

### File Count

| Before | After |
|--------|-------|
| 15+ files | ~7 files |
| 6 agents | 1-2 agents |
| 0 human checkpoints | 4 checkpoints |

---

## Marketplace Plugin Integration

### claudikins-automatic-context-manager (ACM)

**Role:** Context longevity across planning phases

- Monitors context throughout /plan
- Prompts handoff at 60% threshold
- Preserves planning state across sessions
- Enables long iterative planning without context death

**Integration:**
```yaml
hooks:
  Stop:
    - command: "$CLAUDE_PLUGIN_ROOT/acm/check-threshold.sh"
```

### claudikins-tool-executor

**Role:** Efficient research with minimal context burn

- 97% reduction in token usage for MCP tools
- Semantic search finds relevant tools for planning domain
- Works in forked contexts (inherits auth)

**Integration:**
```yaml
# Research phase
context: fork
skills:
  - tool-executor
```

### claudikins-klaus

**Role:** Opinionated plan review with personality

- Devil's advocate with attitude
- Surfaces blind spots human might miss
- Optional: `/plan --klaus-review`
- Entertainment value keeps planning engaging

**Integration:**
```yaml
# Optional review phase
context: fork
agent: klaus
```

### claudikins-grfp (Pattern Borrowed)

**Role:** Section-by-section approval workflow

GRFP workflow adapted for /plan:
1. Parallel exploration (2-3 agents, different angles)
2. Research constraints (tool-executor)
3. Findings synthesis (main Claude)
4. Structure approval (human checkpoint)
5. Section-by-section drafting
6. Quality review (Klaus or plan-reviewer)

---

## Implementation Checklist

### Phase 1: Core Infrastructure
- [ ] Create `/plan` command with phase structure
- [ ] Add AskUserQuestion at each checkpoint
- [ ] Integrate ACM for context monitoring
- [ ] Add Stop hook for phase verification

### Phase 2: Research Integration
- [ ] Create plan-research skill (context: fork)
- [ ] Integrate tool-executor for efficient queries
- [ ] Define parallel exploration pattern

### Phase 3: Review Options
- [ ] Create plan-reviewer agent (Opus, thorough)
- [ ] Integrate Klaus as optional reviewer
- [ ] Add confidence scoring for issues

### Phase 4: Output & Iteration
- [ ] Define plan output format
- [ ] Add verification checklist generation
- [ ] Enable plan rejection feedback loop

---

## Key Quotes to Remember

> "Go back and forth with Claude until I like its plan. A good plan is really important." — Boris

> "CRITICAL: This is one of the most important phases. DO NOT SKIP." — feature-dev

> "Subagents cannot spawn other subagents." — Official Docs

> "Exit code 2 blocks tool, feeds stderr to Claude." — Hooks Guide

> "Planning should not need 6 specialist agents because planning is not 6 independent tasks." — Agents Guru

---

## Next Steps

1. Draft `/plan` command with phase gates
2. Create planning-methodology skill
3. Integrate ACM hooks
4. Add optional Klaus review
5. Test iteration loop with real planning task
