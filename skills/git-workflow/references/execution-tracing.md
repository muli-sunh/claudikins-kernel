# Execution Tracing

Visibility into the execution graph for debugging, performance analysis, and understanding what happened during a /execute session.

## Why Tracing Matters

Without tracing, debugging failures requires:
- Reading agent transcripts manually
- Guessing which task caused which effect
- Reconstructing the timeline from fragmented logs

With tracing:
- Visual call graph shows relationships
- Latency analysis identifies bottlenecks
- Dependency mapping reveals hidden coupling

## Concepts

### Spans

A **span** represents a single operation with a start time, end time, and metadata.

```json
{
  "span_id": "span-abc123",
  "parent_id": "span-parent",
  "operation": "task_execute",
  "name": "task-3: Add auth middleware",
  "start_time": "2026-01-17T10:00:00Z",
  "end_time": "2026-01-17T10:05:30Z",
  "duration_ms": 330000,
  "status": "success",
  "attributes": {
    "task_id": "task-3",
    "agent": "babyclaude",
    "branch": "execute/task-3-auth-abc123",
    "files_changed": ["src/middleware/auth.ts"]
  }
}
```

### Traces

A **trace** is a collection of spans that represent a complete request/operation lifecycle.

```
Trace: execute-session-xyz
├── span: batch_1
│   ├── span: task-1 (parallel)
│   ├── span: task-2 (parallel)
│   └── span: batch_1_review
├── span: batch_2
│   ├── span: task-3
│   ├── span: task-3_spec_review
│   ├── span: task-3_code_review
│   └── span: batch_2_merge
└── span: session_complete
```

### Context Propagation

Parent context flows to children, enabling correlation:

```
Session starts → trace_id = "exec-123"
  ↓
Batch 1 starts → span_id = "batch-1", parent = "exec-123"
  ↓
Task 1 starts → span_id = "task-1", parent = "batch-1"
  ↓
Agent spawns → span_id = "agent-1", parent = "task-1"
```

## Trace Structure for /execute

### Session Level

```json
{
  "trace_id": "exec-session-20260117-100000",
  "name": "execute_session",
  "plan_source": ".claude/plans/feature-auth.md",
  "total_tasks": 5,
  "total_batches": 2,
  "start_time": "2026-01-17T10:00:00Z",
  "end_time": "2026-01-17T10:45:00Z",
  "status": "completed",
  "spans": [...]
}
```

### Batch Level

```json
{
  "span_id": "batch-1",
  "parent_id": "exec-session-...",
  "operation": "batch_execute",
  "batch_number": 1,
  "tasks": ["task-1", "task-2"],
  "parallel": true,
  "checkpoint_result": "approved",
  "human_decision": {
    "action": "accept_all",
    "timestamp": "2026-01-17T10:20:00Z"
  }
}
```

### Task Level

```json
{
  "span_id": "task-3",
  "parent_id": "batch-2",
  "operation": "task_execute",
  "task_id": "task-3",
  "task_name": "Add auth middleware",
  "agent": "babyclaude",
  "branch": "execute/task-3-auth-abc123",
  "phases": {
    "branch_creation": { "duration_ms": 500 },
    "implementation": { "duration_ms": 180000 },
    "self_verify": { "duration_ms": 30000 },
    "commit": { "duration_ms": 2000 }
  },
  "output": {
    "status": "complete",
    "files_changed": ["src/middleware/auth.ts"],
    "loc_added": 85
  }
}
```

### Review Level

```json
{
  "span_id": "review-task-3-spec",
  "parent_id": "task-3",
  "operation": "spec_review",
  "reviewer": "spec-reviewer",
  "model": "haiku",
  "verdict": "PASS",
  "criteria_checked": 3,
  "criteria_passed": 3,
  "duration_ms": 15000
}
```

## Recording Traces

### Hook Integration

Each hook records its span:

**SubagentStart:**
```bash
# Record task start span
jq --arg spanId "task-$TASK_ID" \
   --arg parentId "$BATCH_SPAN_ID" \
   --arg startTime "$(date -Iseconds)" \
   '.spans += [{"span_id": $spanId, "parent_id": $parentId, "start_time": $startTime, "operation": "task_execute"}]' \
   "$TRACE_FILE" > tmp && mv tmp "$TRACE_FILE"
```

**SubagentStop:**
```bash
# Complete task span
jq --arg spanId "task-$TASK_ID" \
   --arg endTime "$(date -Iseconds)" \
   --arg status "$STATUS" \
   '(.spans[] | select(.span_id == $spanId)) += {"end_time": $endTime, "status": $status}' \
   "$TRACE_FILE" > tmp && mv tmp "$TRACE_FILE"
```

### Trace File Location

```
.claude/
├── execute-state.json    # Current state
├── execute-trace.json    # Execution trace
└── traces/
    └── exec-20260117-100000.json  # Archived traces
```

## Visualisation

### Waterfall View

Shows timeline of all operations:

```
Time:  0s        30s       60s       90s       120s
       |---------|---------|---------|---------|
task-1 ████████████████████                      (45s)
task-2 ██████████████████████████                (55s)
review ·····················████████             (20s)
merge  ·····························████         (10s)
```

### Dependency Graph

Shows relationships between tasks:

```
        ┌─────────┐
        │ task-1  │
        └────┬────┘
             │
     ┌───────┴───────┐
     ▼               ▼
┌─────────┐    ┌─────────┐
│ task-3  │    │ task-4  │
└────┬────┘    └────┬────┘
     │               │
     └───────┬───────┘
             ▼
        ┌─────────┐
        │ task-5  │
        └─────────┘
```

### Critical Path Analysis

Identify the longest chain that determines total duration:

```
Critical path: task-1 → task-3 → task-5
Duration: 45s + 60s + 30s = 135s

Parallel tasks (task-2, task-4) completed within critical path time.
Optimisation target: task-3 (longest individual task).
```

## Debugging with Traces

### Finding Failures

```bash
# Find all failed spans
jq '.spans[] | select(.status == "failed")' execute-trace.json
```

### Latency Analysis

```bash
# Find slowest tasks
jq '.spans[] | select(.operation == "task_execute") | {task: .task_id, duration: .duration_ms}' execute-trace.json | sort -k2 -nr
```

### Dependency Chain Length

As chains lengthen, reliability drops exponentially:

```
P(success) = R^n
```

Where R = component reliability, n = chain length.

| Chain Length | 99.9% Components | 99% Components |
|--------------|------------------|----------------|
| 1 | 99.9% | 99% |
| 5 | 99.5% | 95% |
| 10 | 99% | 90% |
| 20 | 98% | 82% |

**Implication:** Keep dependency chains shallow. Prefer parallel over serial.

## Architecture Erosion Detection

Traces reveal when actual dependencies deviate from planned:

**Planned:**
```
task-1 → task-3
task-2 → task-4
```

**Actual (from trace):**
```
task-1 → task-3 → task-2  # task-2 unexpectedly depends on task-3!
task-4 (orphaned)
```

**Detection:**
```bash
# Compare planned vs actual dependencies
diff <(jq '.planned_deps' plan.json) <(jq '.actual_deps' trace.json)
```

## Trace Retention

| Type | Retention | Storage |
|------|-----------|---------|
| Current session | Until complete | execute-trace.json |
| Recent sessions | 7 days | .claude/traces/*.json |
| Archived | Indefinite (optional) | External storage |

### Archival on Session End

```bash
# In Stop hook
if [ "$SESSION_COMPLETE" = "true" ]; then
    ARCHIVE_NAME="exec-$(date +%Y%m%d-%H%M%S).json"
    mv "$TRACE_FILE" ".claude/traces/$ARCHIVE_NAME"
fi
```

## Output: /execute --trace

View trace summary:

```
Execution Trace: exec-session-20260117-100000

Timeline:
├── 10:00:00 Session start
├── 10:00:05 Batch 1 start (2 tasks parallel)
│   ├── task-1: Add schema [45s] ✓
│   └── task-2: Add util [55s] ✓
├── 10:01:00 Batch 1 review [20s] ✓
├── 10:01:20 Batch 1 merge [10s] ✓
├── 10:01:30 Batch 2 start (1 task)
│   └── task-3: Add service [60s] ✓
├── 10:02:30 Batch 2 review [15s] ✓
└── 10:02:45 Session complete

Total duration: 2m 45s
Tasks completed: 3/3
Critical path: batch-1 → batch-2 (serialised by dependency)

[View full trace] [Export JSON] [Archive]
```

## Integration with Stuck Detection

Traces inform stuck detection:

```json
{
  "span_id": "task-3",
  "operation": "task_execute",
  "start_time": "2026-01-17T10:05:00Z",
  "last_activity": "2026-01-17T10:08:00Z",
  "current_duration_ms": 300000,
  "expected_duration_ms": 120000,
  "stuck_indicators": {
    "no_tool_calls_ms": 180000,
    "repeated_errors": 2
  },
  "stuck_score": 65
}
```

When stuck_score exceeds threshold, trace context helps diagnose:
- What was the last successful operation?
- What pattern led to the stall?
- Is this task inherently slow or actually stuck?
