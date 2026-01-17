# Verify State Compression (S-18)

How to manage verification state for large projects where full state would be too large or slow.

## The Problem

For large projects, verification state can grow unwieldy:

- Thousands of test results
- Hundreds of lint issues
- Large evidence files (screenshots)
- Detailed agent outputs

This causes:
- Slow state file reads/writes
- Context bloat when presenting to human
- Disk space issues in CI

## Compression Strategies

### 1. Summary + Detail Split

Keep summary in main state, details in separate files:

**Main state (compact):**

```json
{
  "session_id": "verify-2026-01-16-1100",
  "phases": {
    "test_suite": {
      "status": "PASS",
      "summary": "1247 passed, 0 failed",
      "details_file": ".claude/verify-details/tests.json"
    },
    "lint": {
      "status": "PASS",
      "summary": "0 errors, 23 warnings",
      "details_file": ".claude/verify-details/lint.json"
    }
  },
  "all_checks_passed": true
}
```

**Detail file (full data):**

```json
{
  "tests": [
    { "file": "auth.test.ts", "tests": 45, "passed": 45, "failed": 0 },
    { "file": "db.test.ts", "tests": 123, "passed": 123, "failed": 0 }
    // ... 1000+ more
  ]
}
```

### 2. Threshold-Based Detail

Only record details for failures and warnings:

```json
{
  "test_suite": {
    "status": "PASS",
    "total": 1247,
    "passed": 1247,
    "failed": 0,
    "failures": []  // Empty because all passed
  }
}
```

vs. when there are failures:

```json
{
  "test_suite": {
    "status": "FAIL",
    "total": 1247,
    "passed": 1245,
    "failed": 2,
    "failures": [
      {
        "file": "auth.test.ts",
        "test": "handles expired token",
        "error": "Expected 401, got 200",
        "line": 145
      },
      {
        "file": "api.test.ts",
        "test": "validates input",
        "error": "AssertionError: expected undefined to equal 'admin'",
        "line": 67
      }
    ]
  }
}
```

### 3. Evidence Compression

For screenshots and large outputs:

**Store references, not content:**

```json
{
  "evidence": {
    "screenshots": [
      {
        "id": "home-page",
        "path": ".claude/evidence/home.png",
        "size_kb": 145,
        "hash": "sha256:abc123"
      }
    ]
  }
}
```

**Thumbnail generation:**

```bash
# Generate thumbnail for quick viewing
convert original.png -resize 200x200 thumbnail.png
```

**Reference in state:**

```json
{
  "screenshot": {
    "full": ".claude/evidence/home.png",
    "thumbnail": ".claude/evidence/home-thumb.png"
  }
}
```

### 4. Rolling Window for History

Don't keep all historical verification runs:

```bash
# Keep only last 10 verification states
ls -t .claude/verify-history/*.json | tail -n +11 | xargs rm -f
```

**Or compress old states:**

```bash
# Compress states older than 7 days
find .claude/verify-history -name '*.json' -mtime +7 -exec gzip {} \;
```

## State File Size Limits

| Component | Target Size | Max Size |
|-----------|-------------|----------|
| Main state | < 10 KB | 50 KB |
| Detail files | < 100 KB each | 1 MB |
| Evidence files | < 500 KB each | 5 MB |
| Total verification dir | < 10 MB | 50 MB |

## Compression Decision Tree

```
State file > 50 KB?
│
├── No → Use as-is
│
└── Yes → Identify large sections
    │
    ├── Test results large?
    │   └── Extract to tests.json, keep summary
    │
    ├── Lint output large?
    │   └── Extract to lint.json, keep counts
    │
    ├── Agent outputs large?
    │   └── Extract to agent-outputs/, keep status
    │
    └── Evidence large?
        └── Store paths only, generate thumbnails
```

## Implementing Compression

### In verify-state.json Write

```bash
#!/bin/bash
# verify-state-write.sh

STATE="$1"
MAX_SIZE=51200  # 50 KB

# Check size
SIZE=$(echo "$STATE" | wc -c)

if [ "$SIZE" -gt "$MAX_SIZE" ]; then
  # Extract large sections
  echo "$STATE" | jq '.phases.test_suite.results' > .claude/verify-details/tests.json
  echo "$STATE" | jq '.phases.lint.issues' > .claude/verify-details/lint.json

  # Compress main state
  COMPRESSED=$(echo "$STATE" | jq '
    .phases.test_suite.results = "see tests.json" |
    .phases.lint.issues = "see lint.json"
  ')

  echo "$COMPRESSED" > .claude/verify-state.json
else
  echo "$STATE" > .claude/verify-state.json
fi
```

### In verify-state.json Read

```bash
#!/bin/bash
# verify-state-read.sh

STATE=$(cat .claude/verify-state.json)

# Check for compressed sections
if echo "$STATE" | jq -e '.phases.test_suite.results == "see tests.json"' > /dev/null; then
  # Load from detail file
  TESTS=$(cat .claude/verify-details/tests.json)
  STATE=$(echo "$STATE" | jq --argjson tests "$TESTS" '.phases.test_suite.results = $tests')
fi

echo "$STATE"
```

## Human Checkpoint Compression

When presenting to human, summarise:

**Instead of:**

```
1247 tests:
- auth.test.ts: 45 passed
- db.test.ts: 123 passed
- api.test.ts: 89 passed
... (1000 more lines)
```

**Present:**

```
Tests: ✓ 1247/1247 passed
       (45 files, 0 failures)

Details available: .claude/verify-details/tests.json
```

## PreCompact Hook Integration

When context is compacting, preserve essential state:

```bash
#!/bin/bash
# preserve-state.sh (PreCompact hook)

# Preserve only essential verification state
ESSENTIAL=$(jq '{
  session_id,
  status: .all_checks_passed,
  phases: {
    test_suite: { status: .phases.test_suite.status },
    lint: { status: .phases.lint.status },
    type_check: { status: .phases.type_check.status },
    output_verification: { status: .phases.output_verification.status }
  },
  human_checkpoint: .human_checkpoint,
  unlock_ship
}' .claude/verify-state.json)

echo "$ESSENTIAL"
```

## Large Project Considerations

### Monorepos

For monorepos with multiple packages:

```json
{
  "packages": {
    "@app/core": {
      "tests": { "status": "PASS", "count": 234 },
      "lint": { "status": "PASS" }
    },
    "@app/web": {
      "tests": { "status": "PASS", "count": 567 },
      "lint": { "status": "PASS" }
    }
  },
  "summary": {
    "all_passed": true,
    "total_tests": 801
  }
}
```

### Incremental Verification

For very large projects, verify only changed packages:

```bash
# Detect changed packages
CHANGED=$(git diff --name-only HEAD~1 | xargs -I{} dirname {} | sort -u)

# Verify only those
for pkg in $CHANGED; do
  npm test --workspace=$pkg
done
```

**State records which packages verified:**

```json
{
  "scope": "incremental",
  "changed_packages": ["@app/core", "@app/api"],
  "verified_packages": ["@app/core", "@app/api"],
  "skipped_packages": ["@app/web", "@app/mobile"],
  "skip_reason": "No changes detected"
}
```

## Cleanup

After shipping, clean up large files:

```bash
# Remove evidence older than 7 days
find .claude/evidence -type f -mtime +7 -delete

# Remove detail files from old sessions
find .claude/verify-details -type f -mtime +7 -delete

# Keep only last 10 state files
ls -t .claude/verify-history/*.json | tail -n +11 | xargs rm -f
```

## See Also

- [verification-checklist.md](verification-checklist.md) - Full verification checklist
- [agent-integration.md](agent-integration.md) - Agent output handling
- [advanced-verification.md](advanced-verification.md) - Large project verification
