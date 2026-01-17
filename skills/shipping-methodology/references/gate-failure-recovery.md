# Gate Failure Recovery (S-19)

Recovering when ship-init.sh gate check fails.

## Gate Check Failures

The gate can fail for several reasons:

| Failure | Error Message | Recovery |
|---------|---------------|----------|
| No verify state | "/verify has not been run" | Run /verify first |
| Not unlocked | "/verify did not pass or was not approved" | Complete /verify |
| Commit mismatch | "Code changed since verification" | Re-run /verify |
| Manifest mismatch | "Source files changed after verification" | Re-run /verify |
| Corrupted state | "verify-state.json corrupted" | Re-run /verify |

## Recovery Flows

### Verify State Missing

```
ERROR: /verify has not been run

Run /verify before /ship

[Run /verify now] [Abort]
```

**Recovery:**
```bash
# Run verification
/verify

# Then retry ship
/ship
```

### Unlock Flag Not Set

```
ERROR: /verify did not pass or was not approved

Human must approve verification before shipping.

Current verify state:
  all_checks_passed: true
  human_checkpoint.decision: null

[Resume /verify for human checkpoint] [Abort]
```

**Recovery:**
```bash
# Resume verification for approval
/verify --resume

# Approve at human checkpoint
# Then retry ship
/ship
```

### Commit Hash Mismatch (C-5)

```
ERROR: Code changed since verification

Verified commit: abc123def
Current commit:  789xyz456

Changes since verification:
- 2 commits added
- 5 files modified

[View changes] [Re-run /verify] [Abort]
```

**This happens when:**
- Additional commits made after /verify
- Branch rebased after /verify
- Merge from main pulled in changes

**Recovery:**
```bash
# Option 1: Re-verify current state
/verify

# Option 2: View what changed
git log abc123def..HEAD --oneline
git diff abc123def HEAD

# Then decide: re-verify or revert
```

### Manifest Hash Mismatch (C-7)

```
ERROR: Source files changed after verification

Verified manifest: sha256:abc123...
Current manifest:  sha256:def456...

Modified files:
- src/auth/middleware.ts
- src/api/routes.ts

[View changes] [Re-run /verify] [Abort]
```

**This happens when:**
- Files edited after /verify
- Auto-formatter ran after /verify
- IDE modified files

**Recovery:**
```bash
# Check what changed
git status
git diff

# Option 1: Commit changes and re-verify
git add .
git commit -m "chore: post-verify fixes"
/verify

# Option 2: Discard changes
git checkout -- .
/ship
```

### Corrupted State File

```
ERROR: verify-state.json corrupted

The verification state file is not valid JSON.

[Re-run /verify] [View raw file] [Abort]
```

**This happens when:**
- Disk write interrupted
- Manual editing broke JSON
- Concurrent modification

**Recovery:**
```bash
# Option 1: Re-run verification from scratch
rm .claude/verify-state.json
/verify

# Option 2: Check for backup
ls .claude/verify-state.json.bak

# Option 3: View and fix manually
cat .claude/verify-state.json
# Fix JSON syntax
jq . .claude/verify-state.json  # Validate
```

## Diagnostic Commands

### Check Verify State

```bash
# View verify state
cat .claude/verify-state.json | jq .

# Check specific fields
jq '.unlock_ship' .claude/verify-state.json
jq '.human_checkpoint.decision' .claude/verify-state.json
jq '.verified_commit_sha' .claude/verify-state.json
```

### Check Code Integrity

```bash
# Compare commits
VERIFY_COMMIT=$(jq -r '.verified_commit_sha' .claude/verify-state.json)
CURRENT_COMMIT=$(git rev-parse HEAD)
echo "Verified: $VERIFY_COMMIT"
echo "Current:  $CURRENT_COMMIT"

# Compare manifests
VERIFY_MANIFEST=$(jq -r '.verified_manifest' .claude/verify-state.json)
CURRENT_MANIFEST=$(sha256sum .claude/verify-manifest.txt | cut -d' ' -f1)
echo "Verified: $VERIFY_MANIFEST"
echo "Current:  $CURRENT_MANIFEST"
```

### Regenerate Manifest

```bash
# Regenerate file manifest
find . \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
  -o -name '*.py' -o -name '*.rs' -o -name '*.go' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  | sort | xargs sha256sum > .claude/verify-manifest.txt
```

## Prevention

### Avoid Post-Verify Changes

After /verify passes:

1. Don't make code changes
2. Don't run formatters
3. Don't pull/merge
4. Run /ship immediately

### Lock Working Directory

```bash
# After verify, immediately ship
/verify && /ship
```

### Use Atomic Ship Flow

The ideal flow is:

```
/verify
  └── Human approves
      └── /ship (immediately)
          └── Merge
```

Don't:
```
/verify
  └── Human approves
      └── "Let me just fix this one thing..."  # NO!
          └── /ship fails
```

## Manual Override

In emergencies, if you're certain code is correct:

```bash
# Reset verify state (DANGEROUS)
jq '.unlock_ship = true | .verified_commit_sha = "'$(git rev-parse HEAD)'"' \
  .claude/verify-state.json > tmp && mv tmp .claude/verify-state.json

# Regenerate manifest
# ... (see above)

# Update manifest hash
NEW_HASH=$(sha256sum .claude/verify-manifest.txt | cut -d' ' -f1)
jq --arg h "$NEW_HASH" '.verified_manifest = $h' \
  .claude/verify-state.json > tmp && mv tmp .claude/verify-state.json
```

**Use only when:**
- You understand why gate failed
- You've verified changes are safe
- Re-running /verify is impractical

**Never use to:**
- Skip actual verification
- Ship untested code
- Bypass human checkpoint
