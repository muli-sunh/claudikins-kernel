# Agent Integration

How catastrophiser and cynic coordinate during claudikins-kernel:verify. This document covers agent configuration, coordination patterns, and hook integration.

## Agent Overview

| Agent | Purpose | Phase | Model | Required |
|-------|---------|-------|-------|----------|
| catastrophiser | See code working | 2 | opus | Yes |
| cynic | Polish pass | 3 | opus | No (optional) |

Both agents use `context: fork` (clean slate) and `background: true` (non-blocking spawn).

## catastrophiser

### Role

The most important agent in the verification flow. catastrophiser gives Claude feedback on whether code actually works by SEEING the output - not just trusting tests.

> "Give Claude a tool to see the output of the code." - Boris

This is the feedback loop that makes Claude's code actually work in production.

### Configuration

```yaml
name: catastrophiser
model: opus
context: fork
background: true
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - WebFetch
  - mcp__tool-executor__search_tools
  - mcp__tool-executor__get_tool_schema
  - mcp__tool-executor__execute_code
disallowedTools:
  - Edit
  - Write
  - Task
```

**Why these tools:**
- Read/Grep/Glob: Understand codebase structure
- Bash: Run servers, curl endpoints, execute CLI
- WebFetch: Fetch pages, check responses
- tool-executor: Playwright for screenshots, browser automation

**Why Edit/Write/Task disallowed:**
- catastrophiser OBSERVES, it doesn't MODIFY
- Modifications would invalidate the verification
- Task spawning would complicate the flow

### Verification Methods

catastrophiser chooses the appropriate method based on project type:

| Project Type | Primary Method | Evidence |
|--------------|----------------|----------|
| Web app | Start server + screenshot | PNG files, console logs |
| API | Curl endpoints | Status codes, response bodies |
| CLI | Run commands | stdout, stderr, exit codes |
| Library | Run examples | Output values |
| Service | Check health endpoint | Health response, logs |

### Fallback Hierarchy (A-3)

If the primary method fails, fall back in order:

```
1. Screenshot (web) / Curl (API) / Run (CLI)
   └── Failed? Try next
2. Run tests only
   └── Failed? Try next
3. Run examples
   └── Failed? Try next
4. Code review only (last resort)
   └── Report: "Unable to verify runtime behaviour"
```

### Output Format

```json
{
  "verified_at": "2026-01-16T11:00:00Z",
  "project_type": "web",
  "verification_method": "screenshot",
  "fallbacks_attempted": [],
  "evidence": {
    "screenshots": [
      { "path": ".claude/evidence/home.png", "description": "Home page renders" },
      { "path": ".claude/evidence/login.png", "description": "Login form visible" }
    ],
    "curl_responses": [],
    "command_outputs": []
  },
  "status": "PASS",
  "issues": [],
  "recommendations": []
}
```

### Failure Output

When verification fails:

```json
{
  "verified_at": "2026-01-16T11:00:00Z",
  "project_type": "api",
  "verification_method": "curl",
  "status": "FAIL",
  "issues": [
    {
      "severity": "critical",
      "description": "POST /api/auth returns 500",
      "evidence": {
        "command": "curl -X POST localhost:3000/api/auth -d '{}'",
        "status_code": 500,
        "body": "Internal Server Error"
      }
    }
  ],
  "recommendations": [
    "Check error handling in auth controller",
    "Verify database connection"
  ]
}
```

### Timeout Handling

Default timeout: 30 seconds per verification method (CMD-30).

```
Method times out?
├── Log timeout with method attempted
├── Try next fallback method
└── If all methods timeout:
    └── Report: "Verification timed out. Manual check recommended."
```

## cynic

### Role

Optional polish pass after verification succeeds. Simplifies code without changing behaviour. Only runs if:
1. Phase 2 (catastrophiser) passes
2. Human approves the polish pass

### Configuration

```yaml
name: cynic
model: opus
context: fork
background: true
tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Bash
disallowedTools:
  - Write
  - Task
```

**Why Edit but not Write:**
- Edit modifies existing code (simplification)
- Write creates new files (not simplification)

**Why Bash:**
- Needs to run tests after each change
- Tests verify behaviour preservation

### Simplification Targets

| Target | Action | Example |
|--------|--------|---------|
| Single-use helper | Inline it | `getUser()` called once → inline the query |
| Unclear name | Rename | `x` → `userCount` |
| Dead code | Delete | Unused function → remove |
| Deep nesting | Flatten | if/if/if → early returns |
| Redundant abstraction | Remove | Wrapper that just calls wrapped |

### Forbidden Actions

| Action | Why Forbidden |
|--------|---------------|
| Add features | Scope creep |
| Change public APIs | Breaks consumers |
| Refactor unrelated code | Stay focused |
| Subjective style changes | Not simplification |
| "Improve" working code | If it works, leave it |

### Process

```
1. Read implementation
2. Identify ONE simplification opportunity
3. Make the change (Edit tool)
4. Run tests (Bash tool)
5. Tests pass?
   ├── Yes → Commit change, continue to step 2
   └── No → Revert change, try different simplification
6. Repeat until:
   - No more improvements found, OR
   - 3 passes complete, OR
   - 3 consecutive failures
```

### Output Format

```json
{
  "started_at": "2026-01-16T11:10:00Z",
  "completed_at": "2026-01-16T11:12:00Z",
  "simplifications_made": [
    {
      "file": "src/auth.ts",
      "line": 45,
      "description": "Inlined single-use validateToken helper",
      "lines_removed": 8,
      "lines_added": 3
    },
    {
      "file": "src/utils.ts",
      "line": 12,
      "description": "Removed dead formatDate function",
      "lines_removed": 15,
      "lines_added": 0
    }
  ],
  "simplifications_reverted": [
    {
      "file": "src/db.ts",
      "description": "Attempted to inline query builder, broke tests",
      "reason": "Query builder used for both read and write paths"
    }
  ],
  "tests_still_pass": true,
  "code_delta": {
    "lines_added": 3,
    "lines_removed": 23,
    "net": -20
  }
}
```

## Coordination Flow

```
claudikins-kernel:verify starts
│
├── Phase 1: Automated checks (no agents)
│   ├── Tests
│   ├── Lint
│   ├── Types
│   └── Build
│
├── Phase 2: catastrophiser
│   │
│   ├── Spawn agent
│   │   └── context: fork, background: true
│   │
│   ├── Agent executes
│   │   ├── Detect project type
│   │   ├── Choose verification method
│   │   ├── Capture evidence
│   │   └── Return JSON result
│   │
│   ├── SubagentStop hook fires
│   │   └── capture-catastrophiser.sh runs
│   │       └── Saves output to .claude/agent-outputs/verification/
│   │
│   └── STOP checkpoint
│       └── [Accept] [Debug] [Skip]
│
├── Phase 3: cynic (conditional)
│   │
│   ├── Prerequisites
│   │   ├── Phase 2 status == PASS
│   │   └── Human approves polish pass
│   │
│   ├── Spawn agent
│   │   └── context: fork, background: true
│   │
│   ├── Agent executes
│   │   ├── Find simplification opportunities
│   │   ├── Make changes
│   │   ├── Run tests after each
│   │   └── Return JSON result
│   │
│   ├── SubagentStop hook fires
│   │   └── capture-cynic.sh runs
│   │       └── Saves output to .claude/agent-outputs/simplification/
│   │
│   ├── Re-run tests (verify behaviour preserved)
│   │
│   └── STOP checkpoint
│       └── [Accept] [Review changes] [Revert]
│
└── Phase 5: Human checkpoint
    └── Present all evidence from both agents
```

## Hook Integration

### capture-catastrophiser.sh

Triggered by SubagentStop when catastrophiser completes.

```bash
#!/bin/bash
set -euo pipefail

OUTPUT="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
DEST_DIR="$PROJECT_DIR/.claude/agent-outputs/verification"
TIMESTAMP=$(date +%s)
DEST_FILE="$DEST_DIR/catastrophiser-$TIMESTAMP.json"

# Ensure directory exists
mkdir -p "$DEST_DIR"

# Validate JSON
if ! echo "$OUTPUT" | jq empty 2>/dev/null; then
  echo "WARNING: Invalid JSON from catastrophiser" >&2
  echo "$OUTPUT" > "$DEST_FILE.raw"
  exit 1
fi

# Save output
echo "$OUTPUT" | jq . > "$DEST_FILE"

# Update verify-state.json
STATE_FILE="$PROJECT_DIR/.claude/verify-state.json"
if [ -f "$STATE_FILE" ]; then
  jq --arg file "$DEST_FILE" \
     --arg status "$(echo "$OUTPUT" | jq -r '.status')" \
     '.phases.output_verification.output_file = $file |
      .phases.output_verification.status = $status' \
     "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

echo "Captured catastrophiser output to $DEST_FILE"
```

### capture-cynic.sh

Triggered by SubagentStop when cynic completes.

```bash
#!/bin/bash
set -euo pipefail

OUTPUT="$1"
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
DEST_DIR="$PROJECT_DIR/.claude/agent-outputs/simplification"
TIMESTAMP=$(date +%s)
DEST_FILE="$DEST_DIR/cynic-$TIMESTAMP.json"

# Ensure directory exists
mkdir -p "$DEST_DIR"

# Validate JSON
if ! echo "$OUTPUT" | jq empty 2>/dev/null; then
  echo "WARNING: Invalid JSON from cynic" >&2
  echo "$OUTPUT" > "$DEST_FILE.raw"
  exit 1
fi

# Save output
echo "$OUTPUT" | jq . > "$DEST_FILE"

# Update verify-state.json
STATE_FILE="$PROJECT_DIR/.claude/verify-state.json"
if [ -f "$STATE_FILE" ]; then
  jq --arg file "$DEST_FILE" \
     --argjson pass "$(echo "$OUTPUT" | jq '.tests_still_pass')" \
     '.phases.code_simplification.output_file = $file |
      .phases.code_simplification.tests_pass = $pass' \
     "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
fi

echo "Captured cynic output to $DEST_FILE"
```

## Error States

| Error | Agent | Detection | Response |
|-------|-------|-----------|----------|
| Timeout | catastrophiser | 30s without completion | Try fallback method |
| Invalid JSON | Either | jq parse fails | Save raw, warn, continue |
| Tests fail post-simplify | cynic | exit code != 0 | Revert last change |
| Context exhaustion | Either | ACM warning | Output partial, mark incomplete |
| Tool unavailable | catastrophiser | MCP error | Fall back to bash-only verification |
| Server won't start | catastrophiser | Port not responding | Try test-only verification |

## State File Updates

Both hooks update verify-state.json:

```json
{
  "phases": {
    "output_verification": {
      "status": "PASS",
      "agent": "catastrophiser",
      "output_file": ".claude/agent-outputs/verification/catastrophiser-1705406400.json",
      "evidence_count": 3
    },
    "code_simplification": {
      "status": "PASS",
      "agent": "cynic",
      "output_file": ".claude/agent-outputs/simplification/cynic-1705406520.json",
      "tests_pass": true,
      "changes_count": 2
    }
  }
}
```

## See Also

- [verification-method-fallback.md](verification-method-fallback.md) - When primary method fails
- [cynic-rollback.md](cynic-rollback.md) - Rolling back failed simplifications
- [verification-checklist.md](verification-checklist.md) - Complete checklist
