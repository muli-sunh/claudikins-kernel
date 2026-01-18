# Batch Patterns

Decision trees for batch checkpoints, retry logic, and escalation paths.

## Batch Lifecycle

A batch moves through five phases:

```
[Start] → [Execute] → [Review] → [Checkpoint] → [Merge]
   │          │           │           │            │
   └── Human  └── Parallel └── Sequential  └── Human  └── Human
       gate       tasks        reviews         gate       gate
```

### Phase 1: Batch Start

Before executing any tasks:

1. Load tasks from batch queue
2. Validate dependencies satisfied
3. Check branch state (no uncommitted changes)
4. Present tasks to human for approval

**Human decision point:** [Execute] [Skip X] [Reorder] [Pause]

### Phase 2: Batch Execution

For tasks within the batch:

1. Create git branch per task: `execute/task-{id}-{slug}-{uuid}`
2. Spawn babyclaude agent (context: fork)
3. Agent implements task in isolation
4. Agent self-verifies and commits
5. Agent outputs JSON result

**Tasks with no inter-dependencies run in parallel.**

### Phase 3: Batch Review

After all tasks complete:

1. Collect JSON outputs from all agents
2. For each completed task:
   - Run spec-reviewer (sequential)
   - If spec passes, run code-reviewer (sequential)
3. Aggregate results into batch summary

**Reviews are sequential** - reviewers need clean context per task.

### Phase 4: Batch Checkpoint

Present aggregated results to human:

| Task | Status | Spec | Code | Files |
|------|--------|------|------|-------|
| task-1 | complete | PASS | PASS | auth.ts |
| task-2 | complete | PASS | CONCERNS | user.ts |
| task-3 | blocked | - | - | - |

**Human decision point:** [Accept all] [Accept some] [Revise X] [Retry Y] [Klaus]

### Phase 5: Batch Merge

For approved tasks:

1. Check for merge conflicts with target branch
2. If conflicts detected, present options
3. Execute merges for clean branches
4. Update execute-state.json
5. Clean up merged branches

**Human decision point:** [Merge all] [Merge some] [Keep separate]

## Checkpoint Decision Trees

### Tree 1: Batch Completion Check

```
All tasks in batch have returned?
├── No →
│   Any tasks stuck? (20 tool calls, 10 min, 3x same error)
│   ├── Yes →
│   │   Offer: [Wait longer] [Skip stuck] [Klaus intervention]
│   └── No →
│       Wait for remaining tasks
└── Yes →
    Proceed to Review phase
```

### Tree 2: Review Result Handling

```
Spec review result?
├── FAIL →
│   Retry count < 2?
│   ├── Yes → Retry task (fresh babyclaude)
│   └── No → Escalate: [Klaus] [Human override] [Skip task]
└── PASS →
    Code review result?
    ├── CONCERNS (critical) →
    │   Offer: [Fix issues] [Accept with caveats] [Klaus review]
    ├── CONCERNS (important only) →
    │   Offer: [Fix issues] [Accept with caveats]
    └── PASS →
        Mark task as approved
```

### Tree 3: Merge Conflict Handling

```
Run git merge-base check
├── Clean merge possible →
│   Proceed with merge
└── Conflicts detected →
    Show conflicting files
    Offer: [conflict-resolver agent] [Manual resolution] [Skip merge]
    │
    └── If conflict-resolver chosen:
        Spawn resolver agent
        Human reviews resolution
        Offer: [Accept resolution] [Manual fix] [Abort merge]
```

## Checkpointing Patterns

Checkpointing saves computation state to enable recovery without full restart.

### Coordinated vs Uncoordinated

| Pattern | Mechanism | Pros | Cons |
|---------|-----------|------|------|
| **Coordinated** | All agents align on a global checkpoint time | Consistency guaranteed; recovery is simple | Latency: system may pause to align |
| **Uncoordinated** | Each agent checkpoints independently | Throughput: no sync overhead | Domino Effect: cascading rollback on recovery |
| **Asynchronous** | State snapshotted in background | Efficiency: minimal processing impact | Complexity: requires sophisticated state management |

**For claudikins-kernel:execute:** We use **Coordinated Checkpointing** at batch boundaries.

```
Batch 1 complete → Checkpoint (all agent states saved)
Batch 2 complete → Checkpoint
...
```

Benefits:
- Recovery resumes from last batch, not from start
- Human checkpoints naturally align with state saves
- No "domino effect" - each batch is self-contained

### Checkpoint State Contents

```json
{
  "checkpoint_id": "batch-2-1705500000",
  "batch_completed": 2,
  "tasks_state": {
    "task-1": { "status": "merged", "branch": null },
    "task-2": { "status": "merged", "branch": null },
    "task-3": { "status": "approved", "branch": "execute/task-3-..." }
  },
  "pending_batches": [3, 4],
  "recovery_point": "batch_merge"
}
```

## Retry Logic

### Exponential Backoff

For transient failures (rate limits, network issues), use exponential backoff:

```
Attempt 1: Immediate
Attempt 2: Wait 2^1 = 2 seconds
Attempt 3: Wait 2^2 = 4 seconds
Attempt 4: Wait 2^3 = 8 seconds (max)
```

**Formula:** `wait_time = min(2^attempt, max_wait)`

**With jitter** (prevents thundering herd):
```
wait_time = min(2^attempt, max_wait) + random(0, 1000ms)
```

### Retry Limits by Failure Type

| Failure Type | Max Retries | Wait Strategy | Escalation |
|--------------|-------------|---------------|------------|
| Implementation failure | 2 | None | Klaus → Human |
| Spec review FAIL | 2 | None | Human override or skip |
| Code review CONCERNS | 1 | None | Accept caveats or fix |
| Git commit failure | 1 | 5 seconds | Human intervention |
| Git conflict | 0 | N/A | Immediate human decision |
| Context exhaustion | 0 | N/A | Checkpoint and resume |
| Model rate limit | 3 | Exponential (60s base) | Fallback model or abort |
| Network timeout | 3 | Exponential (2s base) | Human decision |
| API 5xx error | 3 | Exponential (5s base) | Abort batch |

### Retry Escalation Path

```
Retry 1 failed →
├── Same error? → Different approach
└── New error? → Retry 2

Retry 2 failed →
├── Klaus available? → Klaus intervention
└── Klaus unavailable → Human decision:
    [Manual fix] [Skip task] [Abort batch]
```

### What Gets Reset on Retry

| Component | Reset? | Notes |
|-----------|--------|-------|
| Git branch | Yes | Delete and recreate |
| Agent context | Yes | Fresh babyclaude |
| Task description | No | Same spec |
| Retry count | No | Persists across attempts |
| Error history | No | Available for diagnosis |

## Human Checkpoint Options

### At Batch Start

```
Batch 2/4: [task-3: Add validation] [task-4: Add tests]
Ready to execute?

[Execute]     - Run all tasks in this batch
[Skip X]      - Remove task(s) from this batch
[Reorder]     - Change task order or move between batches
[Pause]       - Save state and stop execution
```

### At Batch Review

```
Batch 2/4 complete. Results:

| Task | Spec | Code | Notes |
|------|------|------|-------|
| task-3 | PASS | PASS | Clean |
| task-4 | PASS | CONCERNS | Missing edge case |

[Accept all]  - Approve all tasks
[Accept 3]    - Approve only task-3
[Revise 4]    - Send task-4 back to babyclaude with feedback
[Retry 4]     - Fresh attempt at task-4
[Klaus]       - Escalate to Klaus for task-4
```

### At Merge Decision

```
Ready to merge approved tasks.

Merge conflicts: None detected

[Merge all]      - Merge task-3 and task-4 branches
[Merge task-3]   - Merge only task-3, keep task-4 separate
[Keep separate]  - Don't merge yet, continue to next batch
```

## Parallel vs Sequential

### When Tasks Can Run in Parallel

Tasks can run in parallel when:

1. **No dependency relationship** - Neither task listed as dep of other
2. **No file overlap** - Tasks touch different files
3. **No shared state** - No database migrations or config changes that affect both

```markdown
| # | Task | Deps | Parallel? |
|---|------|------|-----------|
| 1 | Add schema | - | Yes (with 2) |
| 2 | Add util | - | Yes (with 1) |
| 3 | Add service | 1,2 | No (waits for 1,2) |
```

### When Tasks Must Be Sequential

Force sequential when:

1. **Explicit dependency** - Task B lists Task A in deps
2. **Migration ordering** - Database changes must apply in order
3. **Shared config** - Both modify same config file

### Mixed Batch Handling

If batch has both parallel and sequential tasks:

```
Batch contains: [task-1] [task-2] [task-3 (depends on 1)]

Execution order:
├── Phase A (parallel): task-1, task-2
└── Phase B (after A): task-3

Reviews:
├── task-1 review
├── task-2 review
└── task-3 review (sequential after execution)
```

## Emergency Stops

### Context Exhaustion (ACM at 75%+)

```
MANDATORY STOP

Context usage: 78%
Remaining capacity insufficient for safe completion.

[Continue on new tab]  - Handoff state, open fresh session
[Pause batch]          - Save checkpoint, resume later
[Emergency complete]   - Attempt to finish current task only
```

**This is not optional.** ACM at 75%+ triggers mandatory stop.

### Stuck Detection Triggers

| Trigger | Threshold | Action |
|---------|-----------|--------|
| Tool flooding | 20 calls without file change | Warning at 15, stop at 20 |
| Time stall | 10 minutes without progress | Warning at 7, stop at 10 |
| Error loop | Same error 3 times | Immediate stop |
| Review timeout | 5 minutes per reviewer | Offer [Wait] [Skip] |

### Human Abort

At any time, human can:

```
claudikins-kernel:execute --abort

This will:
1. Complete current tool operation
2. Save state checkpoint
3. Leave branches intact
4. Exit execution

[Confirm abort] [Cancel]
```

## Load Shedding

When the system is overloaded, proactively reject low-priority work rather than attempting to process everything poorly.

### Overload Detection

| Signal | Threshold | Action |
|--------|-----------|--------|
| Pending tasks queue | >15 tasks | Warn user, suggest smaller batch |
| Concurrent agents | >7 | Reject new spawns until current complete |
| API rate limit approaching | >80% quota used | Pause non-critical operations |
| Context usage | >60% | Defer low-priority tasks |

### Shedding Priority

When shedding is triggered, drop work in this order:

1. **Lowest priority first** - Tasks marked as "nice-to-have"
2. **Largest tasks** - Higher resource consumption
3. **No dependencies** - Won't cascade failures
4. **Oldest queued** - Likely stale anyway

### Graceful Degradation

```
SYSTEM OVERLOADED

Current load: 12 pending tasks, 6 active agents
Recommended capacity: 7 tasks, 5 agents

Options:
[Pause queue]      - Stop accepting new tasks, finish current
[Shed low-priority] - Drop 3 lowest priority tasks
[Emergency mode]   - Complete current batch only, skip rest
[Continue anyway]  - Risk degraded performance
```

## Deadline Propagation

Instead of fixed timeouts, propagate remaining time budgets through the call chain.

### The Problem with Fixed Timeouts

```
Task timeout: 5 minutes (fixed)
├── Branch creation: 10 seconds
├── Agent spawn: 30 seconds
├── Implementation: ???
├── Review: 2 minutes
└── Merge: 30 seconds

If implementation takes 4 minutes, review gets squeezed.
```

### Time Budget Pattern

```
Task starts with budget: 300 seconds

After branch creation (10s):
  Remaining: 290s
  Pass to agent: "You have 290s budget"

Agent after 200s of work:
  Remaining: 90s
  Signals: "90s remaining, wrapping up"

Review receives:
  Remaining: 50s
  If insufficient: Skip review, flag for human
```

### Implementation

Track remaining budget in execute-state.json:

```json
{
  "task_id": "task-3",
  "budget_started": 300,
  "budget_remaining": 90,
  "phases": {
    "branch": { "budget": 10, "actual": 8 },
    "implement": { "budget": 200, "actual": 202 },
    "review": { "budget": 60, "remaining": 50 }
  }
}
```

### Budget Exhaustion

When budget runs out:

```
DEADLINE EXCEEDED

Task: task-3 (Add auth middleware)
Budget: 300s
Elapsed: 320s

The task is taking longer than allocated.

Options:
[Extend +5min]     - Grant more time
[Force complete]   - Accept current state
[Skip remaining]   - Move to next task
[Abort task]       - Abandon and continue batch
```

## State Preservation

At every checkpoint, save to execute-state.json:

```json
{
  "checkpoint_type": "batch_review",
  "batch_id": 2,
  "tasks_completed": ["task-3", "task-4"],
  "tasks_pending": ["task-5"],
  "reviews": {
    "task-3": { "spec": "PASS", "code": "PASS" },
    "task-4": { "spec": "PASS", "code": "CONCERNS" }
  },
  "human_decision_pending": true,
  "timestamp": "2026-01-16T14:30:00Z"
}
```

This enables resume from any checkpoint if session dies.
