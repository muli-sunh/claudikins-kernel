# Branch Collision Detection

Preventing duplicate branch names across parallel tasks or sessions.

## Collision Scenarios

### Scenario 1: Parallel Session Collision

Two Claude sessions running `/execute` simultaneously create branches for the same task:

```
Session A: git checkout -b execute/task-3-auth-abc123
Session B: git checkout -b execute/task-3-auth-def456

If both use same task ID without UUID → collision
```

### Scenario 2: Stale Branch from Crashed Session

Previous session crashed, left branch behind:

```
Existing: execute/task-3-auth-abc123 (from crash)
New session: tries to create execute/task-3-auth-...
```

### Scenario 3: Intentional Retry

User retries a failed task that still has its branch:

```
Existing: execute/task-3-auth-abc123 (failed attempt)
Retry: needs new branch for fresh attempt
```

## Branch Naming Convention

**Format:** `execute/task-{id}-{slug}-{uuid}`

| Component | Example | Purpose |
|-----------|---------|---------|
| `execute/` | `execute/` | Namespace prefix |
| `task-{id}` | `task-3` | Links to plan task number |
| `{slug}` | `auth-middleware` | Human-readable description |
| `{uuid}` | `a1b2c3d4` | 8-char unique suffix |

**Full example:** `execute/task-3-auth-middleware-a1b2c3d4`

### UUID Generation

Generate 8-character hex suffix:

```bash
UUID_SUFFIX=$(head -c 4 /dev/urandom | xxd -p)
# Output: a1b2c3d4
```

**Never reuse UUIDs.** Generate fresh for every branch creation.

## Prevention Mechanism

### Pre-Creation Check

Before creating branch, verify it doesn't exist:

```bash
#!/bin/bash
# In create-task-branch.sh

BRANCH_NAME="execute/task-${TASK_ID}-${SLUG}-${UUID}"

# Check local branches
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "ERROR: Branch already exists locally: $BRANCH_NAME"
  exit 2
fi

# Check remote branches
if git ls-remote --heads origin "$BRANCH_NAME" | grep -q .; then
  echo "ERROR: Branch already exists on remote: $BRANCH_NAME"
  exit 2
fi

# Safe to create
git checkout -b "$BRANCH_NAME"
```

### Session Locking

Write session ID to lock file before creating branches:

```bash
LOCK_FILE="$PROJECT_DIR/.claude/execute-session.lock"

if [ -f "$LOCK_FILE" ]; then
  OTHER_SESSION=$(cat "$LOCK_FILE")
  echo "ERROR: Another session ($OTHER_SESSION) is executing"
  echo "Use --resume $OTHER_SESSION or --force to override"
  exit 2
fi

echo "$SESSION_ID" > "$LOCK_FILE"
```

### Branch Registry

Track created branches in execute-state.json:

```json
{
  "branches": {
    "task-3": {
      "name": "execute/task-3-auth-middleware-a1b2c3d4",
      "created_at": "2026-01-16T14:00:00Z",
      "session_id": "execute-2026-01-16-1400",
      "status": "active"
    }
  }
}
```

## Detection and Recovery

### When Collision Detected

If pre-creation check finds existing branch:

```
Branch collision detected!

Existing: execute/task-3-auth-middleware-a1b2c3d4
Created by: session execute-2026-01-16-1200 (4 hours ago)
Status: No commits since creation

Options:
[Delete and recreate] - Remove stale branch, create fresh
[Use existing]        - Continue work on existing branch
[New UUID]            - Create parallel branch with different UUID
[Klaus debug]         - Something's wrong, need debugging help
```

**For bugfixing scenarios (branch in unexpected state, merge conflicts, corrupted state), escalate to Klaus.**

### Klaus Escalation Triggers

Invoke Klaus when collision involves:

- Branch has commits but task marked as incomplete
- Branch merged but task still in queue
- Multiple branches for same task exist
- Branch state doesn't match execute-state.json

```
Branch anomaly detected - invoking Klaus.

Situation:
- Branch execute/task-3-... has 3 commits
- execute-state.json shows task-3 status: "pending"
- This shouldn't be possible

Klaus will analyse and recommend fix.
```

### Stale Branch Cleanup

Branches older than session timeout (4 hours) with no activity:

```bash
#!/bin/bash
# Identify stale execute branches

git for-each-ref --format='%(refname:short) %(committerdate:unix)' refs/heads/execute/ | while read branch timestamp; do
  age=$(($(date +%s) - timestamp))
  if [ $age -gt 14400 ]; then  # 4 hours
    echo "Stale branch: $branch ($(($age/3600)) hours old)"
  fi
done
```

**Never auto-delete.** Present list to human for decision.

### Orphaned Branch Recovery

If session crashes and branches remain:

```
/execute --resume

Found orphaned branches from crashed session:
- execute/task-3-auth-middleware-a1b2c3d4 (2 commits)
- execute/task-4-validation-b2c3d4e5 (0 commits)

Options:
[Recover task-3] - Continue from existing commits
[Delete task-4]  - No commits, safe to remove
[Review all]     - Inspect branches before deciding
[Klaus]          - Debug why session crashed
```

## Anti-Patterns

### Reusing UUIDs

**Wrong:** Cache UUID and reuse for retries.

**Right:** Generate fresh UUID every time.

### Auto-Deleting Branches

**Wrong:** Automatically remove "stale" branches.

**Right:** Present to human, let them decide.

### Ignoring Lock Files

**Wrong:** Delete lock file and continue if session seems dead.

**Right:** Check if other session is truly dead before overriding.

### Silent Collision Handling

**Wrong:** Detect collision, pick alternative, continue silently.

**Right:** Always inform human when collision detected.
