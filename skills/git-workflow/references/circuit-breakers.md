# Circuit Breakers

Patterns for preventing cascading failures when tasks or agents hang, fail repeatedly, or exhaust resources.

## The Problem: Cascading Failure

In distributed systems, a local failure propagates to dependents, eventually causing system-wide outage.

**The Cascade Pattern:**

```
Task A calls Agent B
  ↓
Agent B slows down (rate limit, complex task)
  ↓
Task A's thread hangs waiting for B
  ↓
Task A runs out of time/context
  ↓
Task A fails, blocking dependent Task C
  ↓
Batch fails
```

**The Resource Exhaustion Pattern:**

```
Slow agent → Queue fills up → Context usage spikes →
Claude spends more effort managing state →
Processing slows further → More queuing →
System stalls
```

## Circuit Breaker Pattern

A circuit breaker detects failure statistics and "opens" to stop traffic, giving the system time to recover.

### States

```
     ┌─────────────────────────────────────┐
     │                                     │
     ▼                                     │
  [CLOSED] ──failure threshold──▶ [OPEN] ──timeout──▶ [HALF-OPEN]
     ▲                              │                      │
     │                              │                      │
     └──────success──────────────────────────success───────┘
                                    │                      │
                                    └──────failure─────────┘
```

| State | Behaviour |
|-------|-----------|
| **CLOSED** | Normal operation. Track failure rate. |
| **OPEN** | Fail fast. Don't attempt operation. Wait for cooldown. |
| **HALF-OPEN** | Allow one test request. Success → CLOSED. Failure → OPEN. |

### Configuration

```json
{
  "circuit_breaker": {
    "failure_threshold": 3,
    "failure_window_seconds": 60,
    "open_duration_seconds": 30,
    "half_open_max_calls": 1
  }
}
```

### Implementation for Tasks

Track failures per operation type:

```json
{
  "circuits": {
    "agent_spawn": {
      "state": "CLOSED",
      "failures": 0,
      "last_failure": null,
      "opened_at": null
    },
    "git_operations": {
      "state": "OPEN",
      "failures": 3,
      "last_failure": "2026-01-17T10:00:00Z",
      "opened_at": "2026-01-17T10:00:05Z"
    }
  }
}
```

### When Circuit Opens

```
CIRCUIT BREAKER TRIPPED

Operation: agent_spawn
Failures: 3 in last 60 seconds
State: OPEN (will retry in 30s)

Recent failures:
- 10:00:00 - Rate limit exceeded
- 10:00:15 - Rate limit exceeded
- 10:00:30 - Rate limit exceeded

Options:
[Wait for reset]     - Auto-retry in 30s
[Force close]        - Override circuit, try now
[Skip operation]     - Continue without this operation
[Abort batch]        - Stop execution
```

## Task Timeout Patterns

### Fixed Timeout (Simple)

Each task gets a maximum duration. Exceeded = failure.

```
Task timeout: 5 minutes

After 5 minutes:
├── Task incomplete → Mark TIMEOUT, escalate
└── Task complete → Normal flow
```

**Problem:** Doesn't account for task complexity.

### Dynamic Timeout (Adaptive)

Adjust timeout based on task characteristics:

| Factor | Multiplier |
|--------|------------|
| Files touched | +30s per file |
| Estimated LOC | +1s per 10 LOC |
| Dependencies | +60s per dependency |
| Complexity flag | 2x multiplier |

**Formula:**
```
timeout = base_timeout + (files × 30) + (loc ÷ 10) + (deps × 60)
if complex: timeout × 2
```

**Example:**
```
Task: Add auth middleware
Files: 3
Estimated LOC: 150
Dependencies: 1
Complexity: normal

timeout = 120 + (3 × 30) + (150 ÷ 10) + (1 × 60)
timeout = 120 + 90 + 15 + 60 = 285 seconds
```

### Timeout with Warning

Warn before hard cutoff to allow graceful completion:

```
Timeline:
├── 0% ────── Start
├── 70% ───── Warning: "3 minutes remaining, wrap up"
├── 90% ───── Urgent: "1 minute remaining, commit now"
└── 100% ──── Hard stop
```

**Warning injection via hook:**

```bash
# In PostToolUse hook
ELAPSED=$(( $(date +%s) - $START_TIME ))
BUDGET=$TASK_TIMEOUT

if [ $ELAPSED -gt $(( BUDGET * 70 / 100 )) ]; then
    echo "TIME WARNING: 30% budget remaining. Start wrapping up."
fi
```

## Failure Detection Heuristics

### Stuck Agent Detection

| Signal | Threshold | Confidence |
|--------|-----------|------------|
| No tool calls | 2 minutes | Medium |
| Repeated same tool | 5 times in a row | High |
| Tool call flood | 20 calls without file change | High |
| Same error repeated | 3 times | Very High |
| Context burn rate | >5% per minute | Medium |

### Scoring

```
stuck_score = 0

if no_tool_calls > 2min: stuck_score += 30
if repeated_tool > 5: stuck_score += 40
if tool_flood > 20: stuck_score += 50
if same_error > 3: stuck_score += 60
if context_burn > 5%/min: stuck_score += 20

if stuck_score >= 60: INTERVENE
```

### Intervention Options

```
AGENT APPEARS STUCK

Agent: babyclaude (task-3)
Stuck score: 75/100

Indicators:
- Same tool called 7 times
- No file changes in 3 minutes
- Error repeated twice

Options:
[Nudge agent]        - Inject hint: "Try a different approach"
[Extend timeout]     - Grant 5 more minutes
[Klaus intervention] - Escalate to debugger
[Abort task]         - Mark failed, continue batch
```

## Recovery Protocols

### From OPEN Circuit

```
Circuit: agent_spawn (OPEN)
Opened: 30 seconds ago
Reset in: 0 seconds

Attempting half-open test...

Test result: SUCCESS

Circuit CLOSED. Resuming normal operations.
```

### From Stuck Agent

1. **Soft nudge** - Inject context hint
2. **Hard reset** - Kill agent, respawn fresh
3. **Klaus escalation** - Debug agent hands off
4. **Skip task** - Mark as blocked, continue

### From Timeout

1. **Capture partial state** - What was completed?
2. **Checkpoint** - Save progress
3. **Decision point**:
   - Resume with more time
   - Accept partial completion
   - Retry from scratch
   - Skip task

## Integration with Execute Flow

### Pre-Task Check

```bash
# Before spawning agent
check_circuit "agent_spawn"
if [ $? -eq 1 ]; then
    echo "Circuit OPEN - agent spawn disabled"
    exit 2  # Block task
fi
```

### During Task Monitoring

```bash
# In PostToolUse hook
update_stuck_score "$AGENT_ID" "$TOOL_NAME" "$RESULT"

if is_stuck "$AGENT_ID"; then
    offer_intervention "$AGENT_ID"
fi
```

### Post-Task Recording

```bash
# In SubagentStop hook
if [ "$STATUS" = "success" ]; then
    record_success "agent_spawn"
else
    record_failure "agent_spawn" "$ERROR"
fi
```

## Anti-Patterns

### Infinite Retry

**Wrong:** Keep retrying failed operation indefinitely.

**Right:** Use circuit breaker to fail fast after threshold.

### No Timeout

**Wrong:** Let tasks run forever hoping they'll finish.

**Right:** Always have a maximum duration, even if generous.

### Ignoring Partial Success

**Wrong:** Task timed out = total failure, discard all work.

**Right:** Capture partial state, offer to resume or accept partial.

### Manual Circuit Management

**Wrong:** Human decides when to resume after failures.

**Right:** Automatic half-open testing with human override option.
