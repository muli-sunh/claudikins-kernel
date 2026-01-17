# Task Branch Recovery

Recovering orphaned branches from crashed or abandoned sessions.

## What Makes a Branch Orphaned

A branch is "orphaned" when:

1. **Session crashed** - Agent died mid-task, branch left behind
2. **Session abandoned** - Human stopped execution without cleanup
3. **State mismatch** - Branch exists but execute-state.json doesn't reference it
4. **Stale session** - Branch from session older than 4 hours

### Identifying Orphaned Branches

```bash
# List all execute branches
git branch --list 'execute/*'

# Compare against execute-state.json
TRACKED_BRANCHES=$(jq -r '.tasks[].branch' .claude/execute-state.json 2>/dev/null)

for branch in $(git branch --list 'execute/*' --format='%(refname:short)'); do
  if ! echo "$TRACKED_BRANCHES" | grep -q "$branch"; then
    echo "ORPHANED: $branch"
  fi
done
```

### Session State vs. Git State

| State File Says | Git Says | Status |
|-----------------|----------|--------|
| Task in progress | Branch exists with commits | Normal |
| Task completed | Branch merged/deleted | Normal |
| No record of task | Branch exists | ORPHANED |
| Task in progress | Branch missing | CORRUPTED |

## Recovery Options

### Option 1: Resume from Orphaned Branch

Continue work where crashed session left off.

```
Found orphaned branch: execute/task-3-auth-middleware-a1b2c3d4

Branch info:
- 2 commits since creation
- Last commit: "Add auth middleware base structure"
- Last modified: 2 hours ago

Options:
[Resume]         - Continue task on this branch
[Fresh start]    - Delete and start new branch
[Inspect first]  - Show commits before deciding
```

**Resume workflow:**
1. Update execute-state.json to track branch
2. Spawn babyclaude with context: "Continue from existing commits"
3. Agent picks up where previous agent left off

### Option 2: Salvage Commits

Cherry-pick useful commits into a new task branch.

```
Orphaned branch has 4 commits:
1. abc123 - Add auth types
2. def456 - Add middleware skeleton
3. ghi789 - Incomplete: Add validation... (no tests)
4. jkl012 - WIP: debugging...

[Cherry-pick 1-2]  - Take useful commits, discard WIP
[Cherry-pick all]  - Take everything
[Skip]             - Don't salvage, start fresh
```

**Salvage workflow:**
1. Create new task branch
2. Cherry-pick selected commits
3. Fresh agent continues from salvaged state

### Option 3: Clean Delete

Branch had no useful work. Safe to remove.

```
Orphaned branch: execute/task-5-validation-x1y2z3

Branch info:
- 0 commits since creation
- Only contains initial checkout

This branch has no work to salvage.

[Delete]     - Remove branch entirely
[Archive]    - Rename to archive/task-5-... and keep
```

### Option 4: Archive

Keep branch but mark as abandoned.

```
Orphaned branch: execute/task-7-feature-flag-p9q8r7

Branch info:
- 5 commits with substantial work
- Task was deprioritised, may resume later

[Archive]    - Rename to archive/task-7-...
[Delete]     - Remove entirely
[Resume now] - Continue this task
```

**Archive naming:** `archive/task-{id}-{date}-{reason}`

Example: `archive/task-7-2026-01-16-deprioritised`

## Recovery Decision Tree

```
Found orphaned branch
│
├── Has commits?
│   ├── No → [Delete] (no work to lose)
│   └── Yes →
│       │
│       Are commits complete/useful?
│       ├── Yes →
│       │   Task still needed?
│       │   ├── Yes → [Resume]
│       │   └── No → [Archive]
│       │
│       └── Partial/WIP →
│           Salvageable commits?
│           ├── Yes → [Cherry-pick useful, delete rest]
│           └── No → [Delete] or [Archive for reference]
```

## Prevention

### Checkpointing During Long Tasks

Every 5 minutes or 10 tool calls:

```bash
# In execute-tracker.sh
CHECKPOINT_INTERVAL=300  # 5 minutes

if [ $(($(date +%s) - LAST_CHECKPOINT)) -gt $CHECKPOINT_INTERVAL ]; then
  # Save current state
  jq '.tasks["'$TASK_ID'"].last_checkpoint = "'$(date -Iseconds)'"' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

  # Commit WIP if there are staged changes
  if git diff --cached --quiet; then
    : # No staged changes
  else
    git commit -m "WIP: checkpoint at $(date -Iseconds)"
  fi
fi
```

### Session Lock Files

Detect active sessions before cleanup:

```bash
LOCK_FILE=".claude/execute-session.lock"

if [ -f "$LOCK_FILE" ]; then
  SESSION_ID=$(cat "$LOCK_FILE")
  LOCK_AGE=$(($(date +%s) - $(stat -c %Y "$LOCK_FILE")))

  if [ $LOCK_AGE -lt 3600 ]; then
    echo "Session $SESSION_ID appears active (lock $LOCK_AGE seconds old)"
    echo "Cannot clean orphaned branches while session may be running"
    exit 1
  fi
fi
```

### Graceful Shutdown

When `/execute --abort` or context dies:

```bash
# In batch-checkpoint-gate.sh
cleanup_on_exit() {
  # Save final state
  jq '.status = "aborted" | .aborted_at = "'$(date -Iseconds)'"' \
    "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"

  # Mark active tasks as interrupted
  for task in $(jq -r '.tasks | to_entries[] | select(.value.status == "in_progress") | .key' "$STATE_FILE"); do
    jq '.tasks["'$task'"].status = "interrupted"' \
      "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
  done

  # Remove lock file
  rm -f "$LOCK_FILE"
}

trap cleanup_on_exit EXIT
```

## Bulk Recovery

When multiple orphaned branches exist:

```
Found 5 orphaned branches:

| Branch | Commits | Age | Action |
|--------|---------|-----|--------|
| execute/task-3-auth-... | 2 | 2 hours | [Resume] |
| execute/task-4-valid-... | 0 | 3 hours | [Delete] |
| execute/task-5-tests-... | 4 | 5 hours | [Archive] |
| execute/task-6-docs-... | 1 | 6 hours | [Inspect] |
| execute/task-7-feat-... | 3 | 8 hours | [Archive] |

Bulk actions:
[Delete all empty]  - Remove branches with 0 commits
[Archive all stale] - Archive branches > 4 hours old
[Interactive]       - Decide each one individually
```

## Anti-Patterns

### Auto-Deleting "Stale" Branches

**Wrong:** Delete any branch older than X hours automatically.

**Right:** Present to human, let them decide. Work may be valuable.

### Resuming Without Verification

**Wrong:** Blindly continue from orphaned branch state.

**Right:** Show commits, verify they're usable, then resume.

### Ignoring Orphans

**Wrong:** Leave orphaned branches accumulating forever.

**Right:** Periodic cleanup prompts during `/execute --resume`.
