---
name: brain-jam-plan
description: Planning methodology for iterative requirements gathering and approach selection. Use when running /plan, brainstorming implementation approaches, or structuring complex technical plans.
---

# Brain-Jam Planning Methodology

## When to use this skill

Use this skill when you need to:

- Run the `/plan` command
- Brainstorm implementation approaches
- Gather requirements iteratively
- Structure a complex technical plan
- Present multiple options with trade-offs

## Core Philosophy

> "Go back and forth with Claude until I like its plan. A good plan is really important." - Boris

Planning is an iterative conversation, not a production line. The human stays in the loop at every phase.

## The Brain-Jam Process

### Phase 1: Requirements Gathering

**One question at a time. Wait for the answer.**

Key questions to answer:
1. What problem are we solving?
2. What does success look like?
3. What constraints exist?
4. What's explicitly OUT of scope?

Use `AskUserQuestion` with specific options - never open-ended unless necessary.

### Phase 2: Context Building

Before proposing solutions, understand the landscape:

- What exists already in the codebase?
- What patterns should we follow?
- What dependencies apply?
- What has been tried before?

This is where taxonomy-extremist agents help.

### Phase 3: Approach Generation

Generate 2-3 distinct approaches. Each must include:

| Element | Purpose |
|---------|---------|
| Summary | 1-2 sentence overview |
| Pros | Clear benefits |
| Cons | Honest trade-offs |
| Effort | low / medium / high |
| Risk | low / medium / high |

**Always recommend one with reasoning.** See [approach-template.md](references/approach-template.md).

### Phase 4: Section-by-Section Drafting

Draft one section at a time. Get approval before moving on.

**Never batch approvals** - each section checkpoint is a chance to course-correct.

## Plan Quality Criteria

A good plan has all of these:

- [ ] Clear problem statement
- [ ] Explicit scope boundaries (IN and OUT)
- [ ] Measurable success criteria
- [ ] Task breakdown with dependencies
- [ ] Risk identification and mitigations
- [ ] Verification checklist

See [plan-checklist.md](references/plan-checklist.md) for the full verification checklist.

## Output Format

Plans must include machine-readable task markers for `/execute` compatibility:

```markdown
<!-- EXECUTION_TASKS_START -->
| # | Task | Files | Deps | Batch |
|---|------|-------|------|-------|
| 1 | Create schema | prisma/schema.prisma | - | 1 |
| 2 | Add service | src/services/user.ts | 1 | 1 |
<!-- EXECUTION_TASKS_END -->
```

See [plan-format.md](references/plan-format.md) for complete output structure.

## Edge Case Handling

The references/ folder contains guidance for common edge cases:

| Situation | Reference |
|-----------|-----------|
| Context collapse mid-plan | [session-collapse-recovery.md](references/session-collapse-recovery.md) |
| Endless iteration loop | [iteration-limits.md](references/iteration-limits.md) |
| Research taking too long | [research-timeouts.md](references/research-timeouts.md) |
| Approaches contradict each other | [approach-conflict-resolution.md](references/approach-conflict-resolution.md) |
| User abandons plan | [plan-abandonment-cleanup.md](references/plan-abandonment-cleanup.md) |
| Requirements keep changing | [requirement-stability.md](references/requirement-stability.md) |

## Anti-Patterns

**Don't do these:**

- Batching multiple questions together
- Proposing solutions before understanding requirements
- Presenting only one approach (always give options)
- Skipping the verification checklist
- Continuing without explicit approval at checkpoints
- Fabricating research findings when data is sparse

## References

Full documentation in this skill's references/ folder:

- [plan-checklist.md](references/plan-checklist.md) - Complete verification checklist
- [approach-template.md](references/approach-template.md) - How to present options
- [plan-format.md](references/plan-format.md) - Output structure for /execute
- [session-collapse-recovery.md](references/session-collapse-recovery.md) - Context collapse handling
- [iteration-limits.md](references/iteration-limits.md) - When to stop iterating
- [research-timeouts.md](references/research-timeouts.md) - Timeout handling
- [approach-conflict-resolution.md](references/approach-conflict-resolution.md) - Conflicting approaches
- [plan-abandonment-cleanup.md](references/plan-abandonment-cleanup.md) - Cleanup procedures
- [requirement-stability.md](references/requirement-stability.md) - Scope creep detection
