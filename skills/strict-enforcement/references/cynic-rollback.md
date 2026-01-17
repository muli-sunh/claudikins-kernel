# Cynic Rollback (S-17)

How to roll back failed simplifications from the cynic agent. cynic makes changes to simplify code, but sometimes those changes break tests.

## The Problem

cynic's job is to simplify code without changing behaviour. But sometimes:

1. A simplification looks safe but changes behaviour
2. Tests reveal the behaviour change
3. We need to undo the change and try something else

## Rollback Strategy

### Per-Change Rollback

cynic should be able to undo individual changes, not just all changes:

```
Change 1: Inline helper → Tests pass → Keep
Change 2: Remove dead code → Tests pass → Keep
Change 3: Flatten nesting → Tests FAIL → Rollback just this
Change 4: Rename variable → Tests pass → Keep
```

### Implementation

Before each change:

```bash
# Capture state before change
git stash push -m "pre-cynic-change-3"
# or
git add -A && git commit -m "WIP: pre-cynic-change-3"
```

After change, if tests fail:

```bash
# Rollback just this change
git stash pop
# or
git reset --hard HEAD~1
```

## Rollback Flow

```
cynic makes a change
│
├── Run tests
│
├── Tests pass?
│   │
│   ├── Yes →
│   │   ├── Record successful change
│   │   ├── Commit change
│   │   └── Continue to next simplification
│   │
│   └── No →
│       ├── Record failure reason
│       ├── Rollback this change
│       ├── Increment failure counter
│       └── Failure count < 3?
│           ├── Yes → Try different simplification
│           └── No → Stop cynic, report partial results
```

## Recording Rollbacks

```json
{
  "simplifications": {
    "attempted": 5,
    "successful": 3,
    "rolled_back": 2
  },
  "changes": [
    {
      "id": 1,
      "file": "src/auth.ts",
      "type": "inline_helper",
      "status": "kept",
      "lines_changed": -8
    },
    {
      "id": 2,
      "file": "src/utils.ts",
      "type": "remove_dead_code",
      "status": "kept",
      "lines_changed": -15
    },
    {
      "id": 3,
      "file": "src/db.ts",
      "type": "flatten_nesting",
      "status": "rolled_back",
      "reason": "Test 'db.connects' failed - early return changed async timing",
      "test_output": "Expected connection to be established, got undefined"
    },
    {
      "id": 4,
      "file": "src/db.ts",
      "type": "rename_variable",
      "status": "kept",
      "lines_changed": 0
    },
    {
      "id": 5,
      "file": "src/api.ts",
      "type": "inline_helper",
      "status": "rolled_back",
      "reason": "Test 'api.handles-errors' failed - helper had side effect",
      "test_output": "Expected error to be logged, got nothing"
    }
  ],
  "final_state": {
    "tests_passing": true,
    "net_lines_changed": -23
  }
}
```

## Common Rollback Scenarios

### Inlining a Helper with Side Effects

**Original:**

```typescript
function validateAndLog(input: string): boolean {
  console.log(`Validating: ${input}`);  // Side effect!
  return input.length > 0;
}

function process(input: string) {
  if (!validateAndLog(input)) {
    throw new Error('Invalid');
  }
  // ...
}
```

**cynic inlines it:**

```typescript
function process(input: string) {
  if (!(input.length > 0)) {  // Lost the logging!
    throw new Error('Invalid');
  }
  // ...
}
```

**Tests catch:** "Expected console.log to be called with 'Validating:...'"

**Rollback reason:** Helper had logging side effect that was lost.

### Flattening Async Nesting

**Original:**

```typescript
async function getData() {
  try {
    const response = await fetch('/api');
    if (response.ok) {
      const data = await response.json();
      if (data.valid) {
        return data.value;
      }
    }
    return null;
  } catch {
    return null;
  }
}
```

**cynic flattens:**

```typescript
async function getData() {
  try {
    const response = await fetch('/api');
    if (!response.ok) return null;

    const data = await response.json();
    if (!data.valid) return null;

    return data.value;
  } catch {
    return null;
  }
}
```

**This might be safe**, but if tests rely on specific error handling timing, it could break.

### Removing "Dead" Code That Isn't Dead

**Original:**

```typescript
class EventEmitter {
  private handlers: Map<string, Function[]> = new Map();

  // Looks unused...
  clearAll() {
    this.handlers.clear();
  }
}
```

**cynic removes it** as dead code.

**Tests catch:** Integration test calls `emitter.clearAll()` via reflection or in teardown.

**Rollback reason:** Method was used via dynamic access, not visible in static analysis.

## Preventing Unnecessary Rollbacks

### cynic Should Check First

Before making a change, cynic should:

1. **Grep for usage** - Is this helper/variable used elsewhere?
2. **Check for side effects** - Does this code log, mutate, or call external APIs?
3. **Look for dynamic access** - Is it accessed via `[]` notation or reflection?

### Red Flags for cynic

| Red Flag | Why Risky |
|----------|-----------|
| `console.log` in helper | Side effect will be lost |
| `await` in helper | Timing may change |
| Global mutation | Side effect will be lost |
| Event emission | Subscribers may break |
| Metrics/telemetry | Observability will be lost |

### Safe Simplifications

| Type | Safety | Notes |
|------|--------|-------|
| Rename variable | Very safe | Purely cosmetic |
| Remove unused import | Very safe | No runtime effect |
| Inline pure function | Safe | No side effects |
| Remove unreachable code | Safe | Never executed anyway |
| Flatten pure conditionals | Usually safe | Watch for short-circuit changes |
| Inline helper with side effects | Risky | Side effects may be lost |
| Remove "unused" methods | Risky | May have dynamic usage |

## Three-Strike Rule

cynic should stop after 3 consecutive rollbacks:

```
Rollback 1 → Try different simplification
Rollback 2 → Try different simplification
Rollback 3 → STOP

Reason: If 3 simplifications in a row break tests,
the code is more fragile than expected.
Better to stop than risk introducing bugs.
```

## Human Checkpoint After Rollbacks

If rollbacks occurred, flag them:

```
Code Simplification Complete
────────────────────────────

Simplifications made: 3
Simplifications rolled back: 2

Kept:
  ✓ src/auth.ts: Inlined validateToken helper (-8 lines)
  ✓ src/utils.ts: Removed dead formatDate function (-15 lines)
  ✓ src/db.ts: Renamed 'x' to 'connectionPool'

Rolled back:
  ✗ src/db.ts: Flatten nesting (broke async timing)
  ✗ src/api.ts: Inline logAndValidate (had logging side effect)

Net change: -23 lines
Tests: ✓ All passing

[Accept kept changes] [Review rollbacks] [Revert all]
```

## Full Rollback

If all cynic changes need to be undone:

```bash
# If using commits
git reset --hard pre-cynic

# If using stash
git stash pop

# If using branch
git checkout pre-cynic-branch
```

## See Also

- [agent-integration.md](agent-integration.md) - How cynic fits in the flow
- [verification-checklist.md](verification-checklist.md) - Phase 3 checklist
- [red-flags.md](red-flags.md) - When to be suspicious of "simplifications"
