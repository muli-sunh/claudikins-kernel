# Force Push Protection (S-23)

Preventing accidental force pushes during claudikins-kernel:ship.

## The Danger

Force push can:

- Destroy commit history
- Break other developers' branches
- Lose reviewed and approved changes
- Cause CI to re-run unnecessarily
- Create confusion about what was shipped

## Protected Branches

Never force push to:

| Branch | Why Protected |
|--------|---------------|
| main | Production code |
| master | Production code (legacy name) |
| release/* | Release branches |
| develop | Integration branch |
| staging | Staging environment |

## Detection in ship-init.sh

```bash
# Define protected branches
PROTECTED_BRANCHES="main master release develop staging"

# Get target branch
TARGET=$(jq -r '.target // "main"' "$SHIP_STATE" 2>/dev/null || echo "main")

# Check if force push attempted
if [ "$FORCE_PUSH" = "true" ]; then
  for branch in $PROTECTED_BRANCHES; do
    if [ "$TARGET" = "$branch" ] || [[ "$TARGET" == release/* ]]; then
      echo "ERROR: Cannot force push to protected branch: $TARGET" >&2
      echo "Force push is disabled for: $PROTECTED_BRANCHES" >&2
      exit 2
    fi
  done
fi
```

## Git Configuration

### Local Protection

```bash
# Prevent force push to specific branches
git config --local receive.denyNonFastForwards true

# Or per-branch
git config --local branch.main.pushRemote no_push
```

### Pre-Push Hook

Create `.git/hooks/pre-push`:

```bash
#!/bin/bash

protected_branches="main master release"
current_branch=$(git symbolic-ref HEAD | sed -e 's,.*/\(.*\),\1,')

for branch in $protected_branches; do
  if [ "$current_branch" = "$branch" ]; then
    # Check if this is a force push
    if echo "$@" | grep -q "\-\-force\|\-f"; then
      echo "ERROR: Force push to $branch is not allowed"
      exit 1
    fi
  fi
done

exit 0
```

### GitHub Branch Protection

Configure in repo settings:

```
Branch protection rules for "main":
✓ Require pull request reviews
✓ Require status checks to pass
✓ Require branches to be up to date
✓ Do not allow force pushes
✓ Do not allow deletions
```

## Safe Alternatives to Force Push

### Instead of Force Push After Rebase

```bash
# DON'T: Force push rebased branch
git push --force origin feature-branch

# DO: Create new branch
git checkout -b feature-branch-v2
git push origin feature-branch-v2
# Update PR to use new branch
```

### Instead of Force Push to Fix Commit

```bash
# DON'T: Amend and force push
git commit --amend
git push --force

# DO: Add fixup commit
git commit -m "fix: correct typo in previous commit"
git push
# Squash when merging PR
```

### Instead of Force Push to Clean History

```bash
# DON'T: Rebase and force push
git rebase -i HEAD~5
git push --force

# DO: Squash merge the PR
gh pr merge 42 --squash
```

## When Force Push is Detected

```
Force push attempted to protected branch: main

This is not allowed because:
- main is a protected branch
- Force push can destroy history
- Other developers may have based work on current HEAD

Options:
[Create new branch instead]
[Squash merge PR]
[Abort]
```

## Emergency Force Push

In rare cases where force push is necessary (e.g., removing secrets):

```
EMERGENCY: Force push required

You've indicated this is an emergency requiring force push.

Reason: [Select reason]
- Accidentally committed secrets
- Removing large binary
- Fixing corrupted history
- Other (explain)

This will be logged and requires confirmation.

[Confirm emergency force push] [Abort]
```

**Logging:**
```json
{
  "emergency_force_push": {
    "timestamp": "2026-01-17T12:00:00Z",
    "branch": "main",
    "reason": "Accidentally committed API key",
    "previous_head": "abc123",
    "new_head": "def456",
    "user": "ethan"
  }
}
```

## Recovery from Accidental Force Push

If force push happened:

```bash
# Find the previous HEAD
git reflog

# Example output:
# def456 HEAD@{0}: push --force
# abc123 HEAD@{1}: commit: Real changes

# Reset to previous state
git reset --hard abc123

# Force push to restore (yes, force push to fix force push)
git push --force origin main

# Notify team
```

## Integration with claudikins-kernel:ship

### Check Before Merge

```bash
# In ship flow, verify merge strategy is safe
MERGE_STRATEGY=$(jq -r '.commit_strategy.strategy' "$SHIP_STATE")

if [ "$MERGE_STRATEGY" = "rebase" ]; then
  # Rebase on main means we need to check for force push risk
  if git log --oneline origin/main..HEAD | wc -l | grep -q "^0$"; then
    echo "Branch is already up to date, safe to merge"
  else
    echo "WARNING: Rebase will rewrite history"
    echo "Use squash merge instead for protected branches"
  fi
fi
```

### Merge Strategies by Target

| Target | Allowed Strategies | Force Push Risk |
|--------|-------------------|-----------------|
| main | merge, squash | None |
| feature/* | merge, squash, rebase | Low |
| release/* | merge only | None |

## Best Practices

1. **Never force push to main** - Use squash/merge
2. **Configure branch protection** - Enforce at GitHub level
3. **Use squash merges** - Clean history without force push
4. **Create new branches** - Instead of rewriting existing
5. **Log emergency pushes** - Audit trail for incidents
6. **Notify on force push** - Team should know if it happens

## Checklist Before Any Push

- [ ] Am I on a feature branch? (not main/master)
- [ ] Am I using --force or -f? (should I be?)
- [ ] Is the target branch protected?
- [ ] Have I communicated with team if needed?
- [ ] Is there a safer alternative?
