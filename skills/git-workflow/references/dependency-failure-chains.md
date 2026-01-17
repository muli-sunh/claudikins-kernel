# Dependency Failure Chains

What happens when Task X fails and Task Y depends on it.

## Dependency Types and Failure Impact

### Hard Dependencies (`→`)

Task Y **cannot proceed** without Task X's output.

**Examples:**
- Task 2 (add service) depends on Task 1 (create schema)
- Task 4 (add endpoint) depends on Task 3 (add controller)

**If Task X fails:**
- Task Y is automatically blocked
- Human must resolve X before Y can proceed

### Soft Dependencies (`~>`)

Task Y **benefits from** Task X but can work around it.

**Examples:**
- Task 2 (add tests) soft-depends on Task 1 (add logging) - tests work without logging
- Task 4 (add docs) soft-depends on Task 3 (add types) - docs can use `any` temporarily

**If Task X fails:**
- Task Y receives warning
- Human decides: proceed with workaround or wait

## Failure Propagation Rules

### Rule 1: Immediate Blocking

When a hard dependency fails, all dependents are immediately marked `blocked`:

```json
{
  "task-1": { "status": "failed", "error": "..." },
  "task-2": { "status": "blocked", "blocked_by": "task-1" },
  "task-3": { "status": "blocked", "blocked_by": "task-1" }
}
```

### Rule 2: Cascade Calculation

Calculate the full cascade before presenting options:

```
task-1 fails
├── task-2 depends on task-1 → blocked
│   └── task-4 depends on task-2 → blocked
├── task-3 depends on task-1 → blocked
└── task-5 no dependency → unaffected
```

Present: "Task 1 failed. This blocks tasks 2, 3, and 4. Task 5 can proceed."

### Rule 3: Partial Batch Completion

If some tasks in a batch fail but others succeed:

```
Batch 2: [task-3 ✓] [task-4 ✗] [task-5 ✓]

Options:
[Accept 3,5] - Merge successful tasks only
[Retry 4]    - Attempt task-4 again
[Fix 4]      - Manual intervention for task-4
[Abort]      - Discard entire batch
```

## Decision Tree

```
Task X fails
├── Retry available? (count < max)
│   ├── Yes →
│   │   Retry task X
│   │   ├── Retry succeeds → Continue normally
│   │   └── Retry fails → Back to top (decrement retry count)
│   └── No (retries exhausted) →
│       Calculate dependency cascade
│       │
│       Any tasks depend on X?
│       ├── No → Mark X failed, continue with others
│       └── Yes →
│           Present cascade to human:
│           "Task X failed. This blocks: [Y, Z]"
│           │
│           Human chooses:
│           ├── [Skip all] → Mark X, Y, Z as skipped
│           ├── [Manual fix X] → Human fixes, then continue
│           ├── [Restructure] → Remove dependencies, Y/Z become independent
│           ├── [Klaus] → Escalate entire chain to Klaus
│           └── [Abort batch] → Save state, exit execution
```

## Human Override Options

### Option 1: Skip All Dependents

```
Task 1 failed after 2 retries.
Blocked tasks: 2, 3, 4

[Skip all blocked tasks]

This will:
- Mark tasks 1, 2, 3, 4 as "skipped"
- Continue with task 5 (no dependency)
- Log skip reason for later review
```

**Use when:** The failed feature is non-critical and can be done later.

### Option 2: Manual Intervention

```
Task 1 failed: "Cannot create schema - database connection refused"

[Manual fix]

Instructions:
1. Execution paused
2. Fix the issue manually (e.g., start database)
3. Run: /execute --resume --retry task-1
```

**Use when:** The failure is environmental, not code-related.

### Option 3: Restructure Dependencies

```
Task 2 depends on Task 1 (schema).
Task 1 failed.

[Restructure]

Options:
a) Remove dependency - Task 2 uses mock schema
b) Merge tasks - Combine 1 and 2 into single task
c) Reorder - Move Task 1 to later batch with more context
```

**Use when:** The dependency relationship can be worked around.

### Option 4: Klaus Escalation

```
Task 1 failed. Cascade affects 3 tasks.
2 retries exhausted. Cause unclear.

[Klaus]

Klaus will:
- Analyse failure with full context
- Suggest alternative approaches
- Attempt fix with debugging methodology
```

**Use when:** You're stuck and don't know why.

### Option 5: Abort Batch

```
Task 1 failed. This batch cannot complete successfully.

[Abort batch]

This will:
- Save current state to checkpoint
- Keep successful branches intact
- Exit execution cleanly
- Can resume later with /execute --resume
```

**Use when:** The batch is fundamentally broken and needs replanning.

## State Tracking

### Recording Failures

In execute-state.json:

```json
{
  "tasks": {
    "task-1": {
      "status": "failed",
      "retries": 2,
      "error": "Schema validation failed: missing required field 'id'",
      "failed_at": "2026-01-16T14:30:00Z"
    },
    "task-2": {
      "status": "blocked",
      "blocked_by": "task-1",
      "blocked_at": "2026-01-16T14:30:01Z"
    }
  },
  "cascades": {
    "task-1": ["task-2", "task-3", "task-4"]
  }
}
```

### Recording Human Decisions

```json
{
  "human_decisions": [
    {
      "timestamp": "2026-01-16T14:35:00Z",
      "context": "task-1 failed, blocking 3 tasks",
      "decision": "skip_all",
      "affected_tasks": ["task-1", "task-2", "task-3", "task-4"],
      "reason": "Non-critical feature, will address in next sprint"
    }
  ]
}
```

### Resume Behaviour

When resuming after cascade failure:

```bash
/execute --resume

Detected previous failure cascade:
- task-1: failed (schema validation)
- task-2, 3, 4: skipped (dependency)

Options:
[Continue from task-5] - Skip failed chain
[Retry task-1]         - Fresh attempt
[Show full state]      - Review before deciding
```

## Anti-Patterns

### Silent Dependency Skipping

**Wrong:** Automatically skip blocked tasks without telling human.

**Right:** Always present cascade impact and get explicit decision.

### Retry Loop Without Limit

**Wrong:** Keep retrying indefinitely hoping it works.

**Right:** Max 2 retries, then escalate to human/Klaus.

### Ignoring Soft Dependencies

**Wrong:** Treat soft dependencies as hard blocks.

**Right:** Warn but allow human to proceed with workaround.
