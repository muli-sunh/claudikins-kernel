# Batch Size Verification

Validating batch sizes before execution starts.

## Boris Guidance

> "I'd use 5-7 agents per SESSION, not 30 per batch."

The instinct to parallelise everything is wrong. More agents means:

- More context pollution across branches
- More merge conflicts
- More review burden
- Less human oversight per task

**Features are the unit of work.** A single feature might have 3-4 tasks internally, but it's one logical unit. Don't spawn 30 agents for 10 micro-tasks.

### The Right Mental Model

| Wrong Thinking | Right Thinking |
|----------------|----------------|
| "10 tasks = 10 agents" | "10 tasks = 2-3 feature batches" |
| "More parallel = faster" | "More parallel = more chaos" |
| "Batch size = number of tasks" | "Batch size = logical feature units" |

## Validation Rules

### Hard Limits

| Limit | Value | Consequence |
|-------|-------|-------------|
| Max tasks per batch | 5 | Error: must split batch |
| Max agents per session | 7 | Warning: session may exhaust context |
| Max batches per session | 10 | Warning: consider splitting into multiple sessions |

### Warning Thresholds

| Threshold | Value | Action |
|-----------|-------|--------|
| Tasks per batch > 3 | Warning | "Consider splitting this batch" |
| Total agents > 5 | Warning | "Session may hit context limits" |
| Total agents > 7 | Strong warning | "Recommend splitting into sessions" |
| Total tasks > 15 | Block | "Too many tasks. Split the plan." |

### Calculation

Total agents = tasks + (tasks * review_agents_per_task)

With two-stage review:
- 5 tasks = 5 babyclaude + 5 spec-reviewer + 5 code-reviewer = 15 agent invocations
- BUT spec/code reviewers are lightweight (haiku/quick opus)
- Real context cost ≈ babyclaude count

**Focus on babyclaude count.** Review agents are ephemeral.

## Pre-Execution Check

When `claudikins-kernel:execute` starts, before any task runs:

### Step 1: Parse Plan

```json
{
  "total_tasks": 12,
  "batches": [
    { "batch_id": 1, "tasks": ["task-1", "task-2", "task-3"] },
    { "batch_id": 2, "tasks": ["task-4", "task-5"] },
    { "batch_id": 3, "tasks": ["task-6", "task-7", "task-8", "task-9"] },
    { "batch_id": 4, "tasks": ["task-10", "task-11", "task-12"] }
  ]
}
```

### Step 2: Check Limits

```
Batch size verification:
✓ Batch 1: 3 tasks (OK)
✓ Batch 2: 2 tasks (OK)
✗ Batch 3: 4 tasks (WARNING: consider splitting)
✓ Batch 4: 3 tasks (OK)

Session total: 12 tasks
⚠ WARNING: 12 agents exceeds recommended 7 per session
```

### Step 3: Present Options

If any warnings:

```
Batch size concerns detected:

1. Batch 3 has 4 tasks (recommended max: 3)
2. Total tasks (12) exceeds session recommendation (7)

Options:
[Continue anyway]     - Accept risk of context issues
[Split batch 3]       - Divide into two smaller batches
[Split session]       - Run batches 1-2 now, 3-4 in new session
[Reduce scope]        - Remove or defer some tasks
[Restructure]         - Replan the entire task breakdown
```

If hard limit exceeded:

```
BLOCKED: Cannot execute

Batch 3 has 6 tasks (hard limit: 5)

You must restructure before proceeding:
[Split batch 3] - Required before execution can continue
```

## Restructuring Options

### Option 1: Split Large Batch

```
Batch 3: [task-6, task-7, task-8, task-9]

Split into:
- Batch 3a: [task-6, task-7]
- Batch 3b: [task-8, task-9]

This adds one batch but keeps each under limit.
```

### Option 2: Split Across Sessions

```
Current plan: 12 tasks in 4 batches

Split into:
- Session 1: Batches 1-2 (5 tasks)
- Session 2: Batches 3-4 (7 tasks)

Each session stays under context limits.
```

### Option 3: Reduce Scope

```
12 tasks total, 7 recommended.

Candidate tasks to defer:
- task-8: "Add logging" (nice-to-have)
- task-11: "Add metrics" (nice-to-have)
- task-12: "Update docs" (can do later)

Deferring these: 9 tasks remain (closer to limit)
```

### Option 4: Merge Micro-Tasks

```
Current:
- task-4: Add email validation
- task-5: Add phone validation
- task-6: Add address validation

Merge into:
- task-4: Add all form field validations

Reduces 3 tasks to 1, keeps same functionality.
```

## Why This Matters

### Context Death Risk

Each babyclaude agent consumes context. The orchestrating command also consumes context. At 10+ agents, the command itself may hit limits trying to track everything.

### Review Quality

Human reviewing 10 task results is cursory at best. 3-5 results allows actual engagement with each.

### Merge Conflict Probability

Probability of at least one conflict increases with parallel branches:

| Branches | Conflict Risk |
|----------|---------------|
| 2 | Low |
| 3-4 | Moderate |
| 5-7 | High |
| 8+ | Near-certain |

### Recovery Complexity

When something goes wrong with 3 agents, debugging is manageable. With 10 agents, you're triaging a disaster.

## Anti-Patterns

### "But They're Small Tasks"

**Wrong:** "Each task is tiny, so 20 agents is fine."

**Right:** Merge tiny tasks into larger logical units.

### "We Need Speed"

**Wrong:** "Run everything parallel to finish faster."

**Right:** Sequential batches with human checkpoints catch errors early.

### "The Plan Says 15 Tasks"

**Wrong:** "The plan has 15 tasks, so we need 15 agents."

**Right:** The plan guides work, but execution structure is different. Batch at feature level.
