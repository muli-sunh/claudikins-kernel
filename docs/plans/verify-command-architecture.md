# /verify Command Architecture

**Date:** 2026-01-16
**Source:** Guru Panel Final Consensus (18 points unanimous)
**Status:** Ready for implementation

---

## Philosophy

> "Evidence before assertions. Always." - Verification philosophy

- Verification is the gate between /execute and /ship
- Claude MUST see its code working (not just tests passing)
- Human checkpoint with comprehensive report
- Exit code 2 blocks /ship until verification passes
- All Opus models for agents (no compromises on judgement)

---

## Dependencies

### Build Dependencies (must exist first)
| Component | Type | Priority |
|-----------|------|----------|
| strict-enforcement/ | skill | P0 |
| catastrophiser.md | agent | P0 |
| hooks.json | hooks | P0 |
| All /execute components | command | P0 |

### Optional Build Dependencies
| Component | Type | Priority |
|-----------|------|----------|
| cynic.md | agent | P1 |

### Plugin Dependencies
| Plugin | Required | Purpose |
|--------|----------|---------|
| claudikins-tool-executor | YES | MCP access for verification tools |
| claudikins-automatic-context-manager | YES | Context monitoring at 60% |
| claudikins-klaus | NO | Stuck escalation |

---

## File Structure

```
claudikins-kernel/
├── commands/
│   ├── plan.md                          # From /plan
│   ├── execute.md                       # From /execute
│   └── verify.md                        # This command (~200 lines)
│
├── agents/
│   ├── taxonomy-extremist.md            # From /plan
│   ├── babyclaude.md                    # From /execute
│   ├── spec-reviewer.md                 # From /execute
│   ├── code-reviewer.md                 # From /execute
│   ├── catastrophiser.md                # See code working (P0)
│   └── cynic.md                         # Polish pass (P1)
│
├── skills/
│   ├── brain-jam-plan/                  # From /plan
│   ├── git-workflow/                    # From /execute
│   └── strict-enforcement/
│       ├── SKILL.md                     # ~180 lines declarative
│       └── references/
│           ├── verification-checklist.md
│           ├── red-flags.md
│           ├── agent-integration.md
│           └── advanced-verification.md
│
└── hooks/
    ├── hooks.json                       # Extended for verification
    ├── verify-init.sh                   # SessionStart
    ├── capture-catastrophiser.sh        # SubagentStop
    ├── capture-simplifier.sh            # SubagentStop (cynic)
    └── verify-gate.sh                   # Stop - exit code 2 enforcement
```

---

## The Flow

```
/verify [scope]
    │
    │   Flags:
    │   --branch NAME      Verify specific branch (default: current)
    │   --scope SCOPE      test|lint|types|all (default: all)
    │   --fast-mode        60-second iteration cycles
    │   --session-id ID    Resume previous session
    │   --skip-simplify    Skip cynic polish pass
    │   --fix-lint         Auto-apply lint fixes
    │
    ├── Phase 1: Automated Quality Checks
    │     ├── Stage 1: Test Suite
    │     │     └── npm test | pytest | cargo test | go test
    │     │     └── FAIL? Flaky Test Detection (C-12):
    │     │           └── Re-run failed tests for flake detection
    │     │           └── If PASS 2nd time: STOP [Accept flakiness] [Fix tests] [Abort]
    │     │           └── If FAIL 2nd time: catastrophiser tries isolated test run
    │     │           └── If still FAIL: STOP [Fix] [Skip] [Abort]
    │     │
    │     ├── Stage 2: Linting
    │     │     └── npm run lint | ruff | clippy
    │     │     └── FAIL? STOP: [Fix] [Auto-fix] [Skip]
    │     │
    │     └── Stage 3: Type Check
    │           └── tsc | mypy | cargo check
    │           └── FAIL? STOP: [Fix] [Skip] [Abort]
    │
    ├── Phase 2: Output Verification (catastrophiser)
    │     └── Spawn catastrophiser agent (context: fork, opus, background: true)
    │     └── Agent SEES code running:
    │           └── Web: Start server, screenshot, test flows
    │           └── API: Curl endpoints, check responses
    │           └── CLI: Run commands, verify output
    │           └── Library: Run examples, check results
    │     └── Fallback hierarchy (A-3):
    │           └── If can't start server → run tests only
    │           └── If tests unavailable → CLI verification
    │           └── If CLI unavailable → code review only
    │     └── Timeout: 30s per verification method (CMD-30)
    │     └── STOP: [Accept] [Debug] [Skip]
    │
    ├── Phase 3: Code Simplification (Optional, default ON) (I-16)
    │     └── PREREQUISITE: Phase 2 (catastrophiser) must PASS
    │     └── AskUserQuestion: "Run cynic for polish pass?"
    │     └── If yes: Spawn cynic (context: fork, opus)
    │     └── Re-run tests after changes
    │     └── If tests FAIL: Log failure reasons, show human, proceed anyway (A-5)
    │     └── STOP: [Accept] [Review changes] [Revert]
    │
    ├── Phase 4: Klaus Escalation (if stuck) (I-20, I-21)
    │     └── Check if mcp__claudikins-klaus available (E-16)
    │     └── If Klaus unavailable:
    │           └── Offer [Manual review by human] [Ask Claude differently] (E-17)
    │           └── Fallback: [Accept with uncertainty] [Max retries, then abort] (E-18)
    │     └── If available: Spawn escalate-to-klaus.sh via SubagentStop hook
    │
    └── Phase 5: Human Checkpoint
          └── Comprehensive verification report
          └── STOP: [Ready to Ship] [Needs Work] [Accept with Caveats]
          └── If approved: Set unlock_ship = true
```

---

## Component Specifications

### 1. verify.md (Command)

```yaml
---
name: verify
description: Post-execution verification gate. Tests, lint, type-check, then see it working.
argument-hint: [--branch NAME] [--scope SCOPE] [--skip-simplify] [--fix-lint]
model: opus
color: purple
status: stable
version: "1.0.0"
merge_strategy: jq
# === Flags (I-1 to I-4) ===
flags:
  --branch: Verify specific branch (default: current)
  --scope: test|lint|types|all (default: all)
  --skip-simplify: Skip cynic polish pass
  --fix-lint: Auto-apply lint fixes
  --fast-mode: 60-second iteration cycles (I-1)
  --session-id: Resume previous session by ID (I-2)
  --timing: Show phase durations for velocity tracking (I-3)
  --list-sessions: Show available sessions for resume (I-4)
agent_outputs:
  - agent: catastrophiser
    capture_to: .claude/agent-outputs/verification/
    merge_strategy: jq -s 'add'
  - agent: cynic
    capture_to: .claude/agent-outputs/simplification/
    merge_strategy: concat
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - Task
  - AskUserQuestion
  - TodoWrite
---
```

**Key behaviours:**
- Detects project type automatically
- Runs appropriate checks per stack
- Spawns catastrophiser to SEE code working
- Optional cynic for polish
- Human checkpoint with full report
- Exit code 2 blocks /ship until approved

---

### 2. catastrophiser.md (Agent) - P0

```yaml
---
name: catastrophiser
description: |
  See code working. Run the app, test endpoints, capture evidence.
  The most important agent - gives Claude feedback on its work.
model: opus
color: purple
context: fork
status: stable
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
---

You verify that code WORKS by SEEING its output.

> "Give Claude a tool to see the output of the code." - Boris

This is the feedback loop that makes Claude's code actually work.

## Verification Methods

### Web Applications
- Start dev server: npm run dev | cargo run | python manage.py runserver
- Wait for startup (check port)
- Use Playwright/Puppeteer via tool-executor for screenshots
- Test critical user flows
- Check browser console for errors

### APIs
- Start server if needed
- Curl key endpoints with test data
- Verify response status codes
- Check error handling
- Verify response shapes match expectations

### CLI Tools
- Run command with various inputs
- Capture stdout and stderr
- Verify expected output patterns
- Test edge cases (empty input, invalid input)
- Check exit codes

### Libraries
- Run unit tests (already done in Phase 1)
- Run example usage from docs
- Check coverage if available

## Output Format

```json
{
  "verified_at": "2026-01-16T11:00:00Z",
  "project_type": "web|api|cli|library",
  "verification_method": "screenshot|curl|run|test",
  "evidence": {
    "screenshots": ["path/to/screenshot.png"],
    "curl_responses": [{ "endpoint": "/api/users", "status": 200, "body": "..." }],
    "command_outputs": [{ "command": "mycli --help", "stdout": "...", "exit_code": 0 }]
  },
  "status": "PASS|FAIL",
  "issues": [
    { "severity": "critical|warning", "description": "...", "evidence": "..." }
  ],
  "recommendations": ["..."]
}
```

## Critical Rule

If the app does NOT work, report it clearly. Do not skip issues.
This is the feedback loop that makes Claude's code actually work in production.

<example>
Context: User has completed implementation and wants to verify it works
user: "Can you check if this actually works?"
assistant: "I'll use the catastrophiser agent to test the implementation and capture evidence"
<commentary>
User wants functional verification. catastrophiser runs the code, captures screenshots/responses, proves it works.
</commentary>
</example>

<example>
Context: API implementation complete, need to verify endpoints
user: "The auth endpoints are done, let's make sure they work"
assistant: "Spawning catastrophiser to curl the auth endpoints and verify responses"
<commentary>
API verification. catastrophiser will curl each endpoint, check status codes, verify response shapes.
</commentary>
</example>
```

---

### 3. cynic.md (Agent) - P1

```yaml
---
name: cynic
description: |
  Polish pass after verification. Simplify without changing behaviour.
  Run after tests pass but before shipping.
model: opus
color: orange
context: fork
status: stable
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
---

You simplify code. This is a POLISH pass, not a rewrite.

## Core Rules

1. **Preserve exact behaviour** - Tests MUST still pass after each change
2. **Remove unnecessary abstraction** - If used once, inline it
3. **Improve naming clarity** - Clear names over clever names
4. **Delete dead code** - If it's not called, remove it
5. **Flatten nested conditionals** - Early returns over deep nesting

## Process

1. Read implementation
2. Identify ONE simplification opportunity
3. Make the change
4. Run tests
5. If pass: commit and continue
6. If fail: revert and try different simplification
7. Repeat until no more improvements or 3 passes complete

## What You MUST NOT Do

- Add new features
- Change public APIs
- Refactor unrelated code
- Make subjective style choices
- "Improve" working code that's already clear

## Output Format

```json
{
  "simplifications_made": [
    { "file": "...", "description": "Inlined single-use helper", "lines_removed": 5 }
  ],
  "tests_still_pass": true,
  "code_delta": { "lines_added": 10, "lines_removed": 25 }
}
```

<example>
Context: Tests pass but code feels over-engineered
user: "The code works but it's complex, can you simplify?"
assistant: "I'll use cynic to polish the implementation without changing behaviour"
<commentary>
Polish pass. cynic simplifies while preserving tests passing. Focuses on clarity, not cleverness.
</commentary>
</example>
```

---

### 4. strict-enforcement/SKILL.md

```yaml
---
name: strict-enforcement
description: |
  Verification methodology for ensuring code works. Use when about to claim work complete,
  committing code, creating PRs, or verifying implementation. Evidence before assertions.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "verify"
    - "check"
    - "test"
    - "works"
    - "complete"
    - "ship"
---

# Strict Enforcement Methodology

## The Iron Law

> "Evidence before assertions. Always."

Never claim code works without seeing it work.

## Project-Specific Verification

| Project Type | How to Verify |
|--------------|---------------|
| Web app | Screenshot key pages, check console |
| API | Curl endpoints, verify responses |
| CLI | Run commands, check output |
| Library | Run tests, run examples |
| Service | Check logs, verify health endpoint |

## Three Verification Phases

### Phase 1: Automated Checks
- Tests pass
- Lint clean
- Types check
- Build succeeds

### Phase 2: Code Simplification (Optional)
- cynic polish pass
- Behaviour preserved
- Complexity reduced

### Phase 3: Output Verification
- catastrophiser sees it working
- Evidence captured
- Human reviews evidence

## Red Flags

Watch for rationalisations like:
- "It should work because..."
- "The tests pass so..."
- "I'm confident that..."

If you catch yourself saying these, STOP and get evidence.

## References

See references/ for:
- verification-checklist.md - Full verification checklist
- red-flags.md - Common failure patterns
- agent-integration.md - How agents work together
- advanced-verification.md - Complex verification scenarios
- test-timeout-handling.md (S-13) - When tests hang or timeout
- lint-fix-validation.md (S-14) - Validating auto-fix didn't break code
- verification-method-fallback.md (S-15) - Fallback when primary method fails
- type-check-confidence.md (S-16) - Interpreting type-check results
- cynic-rollback.md (S-17) - Rolling back failed simplifications
- verify-state-compression.md (S-18) - Compressing state for large projects
```

---

### 5. hooks/hooks.json (Verify Section)

**verify-init.sh must check execute-state.json exists (C-14):**

```bash
#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
EXECUTE_STATE="$PROJECT_DIR/.claude/execute-state.json"

# === Cross-Command Gate (C-14) ===
if [ ! -f "$EXECUTE_STATE" ]; then
  echo "ERROR: /execute has not been run" >&2
  echo "Run /execute before /verify" >&2
  exit 2
fi

# Validate execute state is complete
EXECUTE_STATUS=$(jq -r '.status // "unknown"' "$EXECUTE_STATE")
if [ "$EXECUTE_STATUS" != "completed" ]; then
  echo "ERROR: /execute did not complete successfully" >&2
  echo "Status: $EXECUTE_STATUS" >&2
  exit 2
fi

echo "Execution state validated. Proceeding with /verify."
```

```json
{
  "hooks": {
    "SessionStart": [
      {
        "sequence": 1,
        "matcher": "/verify",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/verify-init.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "sequence": 1,
        "matcher": "catastrophiser",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/capture-catastrophiser.sh"
          }
        ]
      },
      {
        "sequence": 2,
        "matcher": "cynic",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/capture-simplifier.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "sequence": 1,
        "matcher": "/verify",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/verify-gate.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Exit Code 2 Pattern (CRITICAL)

The verify-gate.sh hook enforces the gate with **code integrity manifest**:

```bash
#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
VERIFY_STATE="$PROJECT_DIR/.claude/verify-state.json"
MANIFEST_FILE="$PROJECT_DIR/.claude/verify-manifest.txt"

# === Dependency Check (H-3) ===
for cmd in jq git sha256sum find; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd not installed" >&2
    exit 127
  fi
done

# === Error handling (H-1) ===
trap 'echo "Hook crashed: $?" >&2; exit 1' ERR

# === ENV validation (H-2) ===
if [ "$PROJECT_DIR" = "." ]; then
  echo "WARNING: Using current directory (CLAUDE_PROJECT_DIR unset)" >&2
fi

# === File Locking (C-8) ===
LOCK_FILE="$VERIFY_STATE.lock"
exec 200>"$LOCK_FILE"
flock -x 200
trap 'flock -u 200; rm -f "$LOCK_FILE"' EXIT

# === State File Corruption Check (H-4) ===
if [ -f "$VERIFY_STATE" ] && ! jq empty "$VERIFY_STATE" 2>/dev/null; then
  echo "ERROR: verify-state.json corrupted" >&2
  exit 2
fi

# Check verification complete
if [ ! -f "$VERIFY_STATE" ]; then
  echo "Verification not started" >&2
  exit 2
fi

ALL_PASSED=$(jq -r '.all_checks_passed // false' "$VERIFY_STATE")
HUMAN_APPROVED=$(jq -r '.human_checkpoint.decision // ""' "$VERIFY_STATE")

if [ "$ALL_PASSED" != "true" ]; then
  echo "Verification checks not all passed" >&2
  exit 2
fi

if [ "$HUMAN_APPROVED" != "ready_to_ship" ]; then
  echo "Human has not approved for shipping" >&2
  exit 2
fi

# === Generate File Hash Manifest (C-6) ===
# Captures SHA256 of all source files for integrity checking in /ship
find "$PROJECT_DIR" \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' -o -name '*.jsx' \
  -o -name '*.py' -o -name '*.rs' -o -name '*.go' -o -name '*.java' \
  -o -name '*.c' -o -name '*.cpp' -o -name '*.h' -o -name '*.hpp' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -not -path '*/target/*' \
  -not -path '*/dist/*' -not -path '*/__pycache__/*' \
  | sort | xargs sha256sum 2>/dev/null \
  | tee "$MANIFEST_FILE" > /dev/null

MANIFEST_SHA=$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)

# === Atomic Write Pattern (C-9) ===
TEMP_FILE=$(mktemp "$VERIFY_STATE.XXXXXX")
trap "rm -f $TEMP_FILE; flock -u 200; rm -f $LOCK_FILE" EXIT

# Set unlock flag and manifest hash
if ! jq --arg manifest "$MANIFEST_SHA" --arg commit "$(git rev-parse HEAD)" \
  '.unlock_ship = true | .verified_manifest = $manifest | .verified_commit_sha = $commit' \
  "$VERIFY_STATE" > "$TEMP_FILE"; then
  echo "ERROR: Failed to update state (disk full?)" >&2
  exit 2
fi

# Validate JSON before committing
if ! jq empty "$TEMP_FILE" 2>/dev/null; then
  echo "ERROR: State file write incomplete" >&2
  exit 2
fi

mv "$TEMP_FILE" "$VERIFY_STATE"
echo "Verification complete. Ship unlocked."
exit 0
```

This prevents /ship from running until /verify completes successfully, and generates a file manifest for integrity checking.

---

## State Tracking

### verify-state.json

```json
{
  "session_id": "verify-2026-01-16-1100",
  "execute_session_id": "execute-2026-01-16-1030",
  "branch": "execute/task-1-auth-middleware",
  "started_at": "2026-01-16T11:00:00Z",
  "phases": {
    "test_suite": {
      "status": "PASS",
      "command": "npm test",
      "exit_code": 0,
      "count": 34,
      "duration_ms": 2500
    },
    "lint": {
      "status": "PASS",
      "command": "npm run lint",
      "exit_code": 0,
      "issues": 0
    },
    "type_check": {
      "status": "PASS",
      "command": "npm run typecheck",
      "exit_code": 0,
      "errors": 0
    },
    "code_simplification": {
      "status": "PASS",
      "agent": "cynic",
      "changes": ["src/auth.ts: inlined single-use helper"]
    },
    "output_verification": {
      "status": "PASS",
      "agent": "catastrophiser",
      "evidence": {
        "screenshots": [".claude/evidence/login-page.png"],
        "curl_responses": 5,
        "all_passing": true
      }
    }
  },
  "all_checks_passed": true,
  "human_checkpoint": {
    "prompted_at": "2026-01-16T11:15:00Z",
    "decision": "ready_to_ship",
    "caveats": []
  },
  "verified_at": "2026-01-16T11:16:00Z",
  "unlock_ship": true
}
```

---

## Plugin Integrations

| Plugin | Role | Integration Point |
|--------|------|-------------------|
| **tool-executor** | Verification tools | catastrophiser uses Playwright, curl |
| **ACM** | Context monitoring | Checkpoint if approaching 60% |
| **Klaus** | Stuck escalation | If verification keeps failing |

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Agents | 2 (catastrophiser P0, cynic P1) |
| Human checkpoints | 1 (comprehensive report) |
| State survival | PreCompact hook preserves |
| Feedback loop | catastrophiser SEES code working |
| Gate enforcement | Exit code 2 blocks /ship |

---

## What We're NOT Building

| Killed | Why |
|--------|-----|
| realist agent | Unclear purpose, removed from consensus |
| Auto-fix everything | Human should approve changes |
| Skip visual verification | catastrophiser is the feedback loop |
| Complex retry logic | Max 2-3 retries, then escalate |
| Integration testing | Out of scope for this phase |

---

## Next Step Suggestion

At the end of `/verify`, Claude says:

```
Done! All checks passed.

Tests ✓  Lint ✓  Types ✓  App works ✓

When you're ready:
  /ship
```

---

## Build Checklist

- [ ] Create strict-enforcement/SKILL.md
- [ ] Create strict-enforcement/references/*.md (4 files)
- [ ] Create catastrophiser.md agent
- [ ] Create cynic.md agent (P1)
- [ ] Update hooks.json with verify hooks
- [ ] Create verify-init.sh hook
- [ ] Create capture-catastrophiser.sh hook
- [ ] Create capture-simplifier.sh hook
- [ ] Create verify-gate.sh hook (exit code 2)
- [ ] Create verify.md command
- [ ] Test exit code 2 behaviour
- [ ] Test with real verification task
