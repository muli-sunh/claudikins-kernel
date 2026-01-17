# Branch Guard Recovery

Recovering when git-branch-guard hook blocks legitimate operations.

## What git-branch-guard Blocks

The guard prevents agents from performing git operations that should be controlled by the orchestrating command.

### Always Blocked

| Command | Why Blocked |
|---------|-------------|
| `git checkout <branch>` | Agents work on assigned branch only |
| `git merge` | Command owns merge decisions |
| `git push` | Human approval required before push |
| `git reset --hard` | Destructive, loses work |
| `git rebase` | Can rewrite history unpredictably |
| `git branch -d/-D` | Branch cleanup is command's job |

### Allowed Operations

| Command | Why Allowed |
|---------|-------------|
| `git add` | Staging changes is normal workflow |
| `git commit` | Agents commit their work |
| `git status` | Read-only, information gathering |
| `git diff` | Read-only, reviewing changes |
| `git log` | Read-only, understanding history |
| `git checkout -- <file>` | Restore single file (not branch switch) |

### The Detection Pattern

```bash
# In git-branch-guard.sh
COMMAND="$BASH_COMMAND"

# Block branch-level operations
if echo "$COMMAND" | grep -qE 'git\s+(checkout|merge|push|reset\s+--hard|rebase|branch\s+-[dD])'; then
  # Check if it's file checkout (allowed) vs branch checkout (blocked)
  if echo "$COMMAND" | grep -qE 'git\s+checkout\s+--\s+'; then
    exit 0  # File restore is OK
  fi
  echo "BLOCKED: $COMMAND"
  echo "Agents cannot perform branch-level git operations."
  exit 2
fi
```

## False Positive Scenarios

### Scenario 1: File Checkout vs Branch Checkout

**Blocked incorrectly:**
```bash
git checkout -- src/auth.ts  # Restore file to last commit
```

**Solution:** Guard should detect `--` separator indicating file operation.

```bash
# Correct detection
if echo "$COMMAND" | grep -qE 'git\s+checkout\s+--\s+'; then
  exit 0  # This is file restore, not branch switch
fi
```

### Scenario 2: Test Framework Git Operations

Some test frameworks use git internally:

```bash
# Jest snapshot testing
git diff --no-index expected.snap actual.snap

# Playwright uses git for baselines
git show HEAD:baseline.png
```

**Solution:** Whitelist read-only git operations:

```bash
# Read-only operations are always safe
if echo "$COMMAND" | grep -qE 'git\s+(status|diff|log|show|ls-files|rev-parse)'; then
  exit 0
fi
```

### Scenario 3: Submodule Operations

Project uses git submodules:

```bash
git submodule update --init
```

**Solution:** This is a gray area. Present to human:

```
git-branch-guard blocked: git submodule update --init

This operation modifies the working tree but may be required for the task.

[Allow once]     - Permit this specific command
[Allow pattern]  - Whitelist submodule commands for session
[Block]          - Maintain block, find alternative approach
[Klaus]          - Need help understanding if this is safe
```

## Recovery Options

### Option 1: Temporary Bypass

Human can approve a single blocked command:

```
BLOCKED: git checkout feature-branch

This command was blocked by git-branch-guard.
Agents should not switch branches.

If this is a legitimate need:
[Allow once]  - Execute this command, then re-enable guard
[Block]       - Maintain block
[Klaus]       - Debug why agent needs this
```

After approval, command executes with guard temporarily disabled.

### Option 2: Session Whitelist

Add pattern to session whitelist:

```json
// In execute-state.json
{
  "guard_whitelist": [
    "git submodule update",
    "git checkout -- tests/"
  ]
}
```

Guard checks whitelist before blocking:

```bash
WHITELIST_FILE="$PROJECT_DIR/.claude/execute-state.json"
WHITELIST=$(jq -r '.guard_whitelist[]?' "$WHITELIST_FILE" 2>/dev/null)

for pattern in $WHITELIST; do
  if echo "$COMMAND" | grep -qF "$pattern"; then
    exit 0  # Whitelisted
  fi
done
```

### Option 3: Klaus Escalation

When the block seems wrong but you're not sure why:

```
git-branch-guard blocked an operation that seems legitimate.

Command: git checkout develop -- package.json
Context: Trying to restore package.json from develop branch
Task: Update dependencies

[Klaus debug]

Klaus will:
- Analyse why this command is needed
- Determine if it's safe in this context
- Suggest alternative approaches if risky
- Recommend whitelist patterns if appropriate
```

## Debugging Blocked Operations

### Check Guard Logs

```bash
cat .claude/logs/branch-guard.log

2026-01-16T14:30:00 BLOCKED git checkout main
2026-01-16T14:30:05 ALLOWED git add src/auth.ts
2026-01-16T14:30:10 BLOCKED git merge feature
```

### Understand Context

Ask: Why does the agent think it needs this operation?

| Agent Reason | Likely Cause | Solution |
|--------------|--------------|----------|
| "Need to see other branch's code" | Missing context | Provide file contents in task description |
| "Merging my changes" | Confused about workflow | Remind: command handles merges |
| "Pushing for CI" | Eager to verify | Remind: human approves push |
| "Reverting mistake" | Made an error | Allow file-level checkout |

### Common Misunderstandings

**Agent thinks:** "I need to checkout main to see the original file."
**Reality:** Agent can use `git show main:path/to/file` (read-only, allowed).

**Agent thinks:** "I should merge my branch when done."
**Reality:** Agent commits, command handles merge after review.

**Agent thinks:** "I need to push so tests run."
**Reality:** Tests run locally or command pushes after approval.

## Anti-Patterns

### Disabling Guard Entirely

**Wrong:** `--no-branch-guard` flag that disables all protection.

**Right:** Granular whitelist for specific patterns.

### Auto-Allowing Everything

**Wrong:** Guard logs but never blocks.

**Right:** Block by default, require explicit human approval.

### Blocking Read-Only Operations

**Wrong:** Block `git log` because it contains "git".

**Right:** Whitelist all read-only git operations.
