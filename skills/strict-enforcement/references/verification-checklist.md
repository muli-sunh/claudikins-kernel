# Verification Checklist

Complete checklist for /verify phases. Use this to ensure nothing is missed.

## Pre-Verification Gate

Before verification can begin, validate the execution state.

### Required State (C-14)

```bash
# These MUST exist
.claude/execute-state.json     # Execution completed
.claude/plan-state.json        # Plan was approved

# execute-state.json must show:
{
  "status": "completed",
  "all_tasks_complete": true
}
```

### Pre-Flight Checks

| Check | How | Fail Action |
|-------|-----|-------------|
| Execute state exists | `[ -f .claude/execute-state.json ]` | Exit 2: "Run /execute first" |
| Execute completed | `jq -r '.status' == "completed"` | Exit 2: "/execute incomplete" |
| On task branch | `git branch --show-current` | Warning: verify from correct branch |
| Clean working tree | `git status --porcelain` | Warning: uncommitted changes |

## Phase 1: Automated Quality Checks

### Stage 1: Test Suite

**Detection:**

| Stack | Test Command | Detection Pattern |
|-------|--------------|-------------------|
| Node.js | `npm test` | package.json scripts.test |
| Python | `pytest` | pytest.ini, pyproject.toml |
| Rust | `cargo test` | Cargo.toml |
| Go | `go test ./...` | *_test.go files |
| Java | `mvn test` | pom.xml |

**Checklist:**

- [ ] Test command detected or specified
- [ ] Tests execute without hanging (timeout: 5 min default)
- [ ] Exit code is 0
- [ ] Test count captured (X passing, Y failing)
- [ ] No skipped tests that should run
- [ ] Coverage threshold met (if configured)

**Flaky Test Handling (C-12):**

```
Test fails?
│
├── Re-run ONLY failed tests
│   └── Pass 2nd time?
│       ├── Yes → FLAKY detected
│       │   └── STOP: [Accept flakiness] [Fix tests] [Abort]
│       └── No → GENUINE failure
│           ├── Run isolated (single test)
│           └── Still fails?
│               ├── Yes → Real bug
│               │   └── STOP: [Fix] [Skip] [Abort]
│               └── No → Test interaction bug
│                   └── STOP: [Fix] [Skip] [Abort]
```

**Recording:**

```json
{
  "phase": "test_suite",
  "status": "PASS",
  "command": "npm test",
  "exit_code": 0,
  "tests": { "passed": 47, "failed": 0, "skipped": 0 },
  "duration_ms": 3200,
  "flaky_detected": false
}
```

### Stage 2: Linting

**Detection:**

| Stack | Lint Command | Detection Pattern |
|-------|--------------|-------------------|
| Node.js | `npm run lint` | package.json scripts.lint |
| Python | `ruff check .` | ruff.toml, pyproject.toml |
| Rust | `cargo clippy` | Cargo.toml |
| Go | `golangci-lint run` | .golangci.yml |

**Checklist:**

- [ ] Lint command detected or specified
- [ ] Lint executes successfully
- [ ] Zero errors (warnings acceptable)
- [ ] No pending auto-fix changes

**Auto-Fix Handling:**

```
Lint errors found?
│
├── --fix-lint flag set?
│   ├── Yes → Run auto-fix
│   │   └── Re-run lint
│   │       └── Still errors?
│   │           ├── Yes → STOP: [Manual fix] [Skip] [Abort]
│   │           └── No → PASS (note: auto-fixed)
│   └── No → STOP: [Fix] [Auto-fix] [Skip]
```

See [lint-fix-validation.md](lint-fix-validation.md) for validating auto-fix safety.

**Recording:**

```json
{
  "phase": "lint",
  "status": "PASS",
  "command": "npm run lint",
  "exit_code": 0,
  "errors": 0,
  "warnings": 3,
  "auto_fixed": false
}
```

### Stage 3: Type Check

**Detection:**

| Stack | Type Command | Detection Pattern |
|-------|--------------|-------------------|
| TypeScript | `tsc --noEmit` | tsconfig.json |
| Python | `mypy .` | mypy.ini, pyproject.toml |
| Rust | `cargo check` | Cargo.toml (always) |

**Checklist:**

- [ ] Type check command detected
- [ ] Type check passes
- [ ] No errors (warnings acceptable)
- [ ] No `any` type escapes (unless justified)

**Recording:**

```json
{
  "phase": "type_check",
  "status": "PASS",
  "command": "tsc --noEmit",
  "exit_code": 0,
  "errors": 0
}
```

### Stage 4: Build (Optional)

Only run if build is configured and relevant.

**Detection:**

| Stack | Build Command | When Required |
|-------|---------------|---------------|
| Node.js | `npm run build` | If scripts.build exists |
| Rust | `cargo build --release` | If deploying binary |
| Go | `go build ./...` | If deploying binary |

**Checklist:**

- [ ] Build completes successfully
- [ ] Output artefacts generated
- [ ] No warnings treated as errors
- [ ] Bundle size within limits (if configured)

## Phase 2: Output Verification

**This is the critical phase.** Claude sees its code working.

### Project Type Detection

```
Detect project type:
├── package.json + src/app or pages/ → Web app
├── package.json + src/routes or controllers/ → API
├── Cargo.toml + src/main.rs with clap → CLI
├── pyproject.toml + __main__.py → CLI
├── **/lib.rs or setup.py → Library
└── Dockerfile or docker-compose.yml → Service
```

### Web Application Checklist

- [ ] Dev server starts (`npm run dev`, `cargo run`, etc.)
- [ ] Server responds on expected port
- [ ] Key pages render without console errors
- [ ] Critical user flows complete successfully
- [ ] Screenshots captured as evidence

**Evidence required:**

```json
{
  "project_type": "web",
  "verification": {
    "server_started": true,
    "port": 3000,
    "pages_checked": [
      { "path": "/", "status": 200, "screenshot": ".claude/evidence/home.png" },
      { "path": "/login", "status": 200, "screenshot": ".claude/evidence/login.png" }
    ],
    "console_errors": []
  }
}
```

### API Checklist

- [ ] Server starts or is already running
- [ ] Key endpoints respond
- [ ] Response status codes correct
- [ ] Response shapes match expectations
- [ ] Error responses formatted correctly

**Evidence required:**

```json
{
  "project_type": "api",
  "verification": {
    "endpoints_tested": [
      { "method": "GET", "path": "/api/users", "status": 200, "body_valid": true },
      { "method": "POST", "path": "/api/auth", "status": 200, "body_valid": true },
      { "method": "GET", "path": "/api/invalid", "status": 404, "body_valid": true }
    ]
  }
}
```

### CLI Checklist

- [ ] Help command works (`--help`)
- [ ] Primary commands execute
- [ ] Exit codes are correct
- [ ] Error messages are helpful
- [ ] Input validation works

**Evidence required:**

```json
{
  "project_type": "cli",
  "verification": {
    "commands_tested": [
      { "command": "mycli --help", "exit_code": 0, "stdout_contains": "Usage:" },
      { "command": "mycli process file.txt", "exit_code": 0 },
      { "command": "mycli process nonexistent.txt", "exit_code": 1 }
    ]
  }
}
```

### Library Checklist

- [ ] Unit tests pass (covered in Phase 1)
- [ ] Example usage from docs works
- [ ] Exported types are correct
- [ ] No runtime type errors

### Service Checklist

- [ ] Service starts successfully
- [ ] Health endpoint responds
- [ ] Logs show expected startup sequence
- [ ] Dependencies connect (DB, cache, etc.)

## Phase 3: Code Simplification

**Prerequisites:**
- Phase 1: All automated checks PASS
- Phase 2: Output verification PASS
- Human approves: "Run cynic for polish pass?"

### Simplification Checklist

- [ ] Only runs after successful verification
- [ ] Human approved the polish pass
- [ ] Tests run after each change
- [ ] Tests still pass after all changes
- [ ] No behaviour changes introduced
- [ ] Rollback available if needed

### What cynic Should Change

| Target | Action |
|--------|--------|
| Single-use helpers | Inline them |
| Unclear names | Rename for clarity |
| Dead code | Delete it |
| Deep nesting | Flatten with early returns |
| Redundant abstraction | Remove indirection |

### What cynic Must NOT Change

| Forbidden | Why |
|-----------|-----|
| Public APIs | Breaks consumers |
| New features | Scope creep |
| Unrelated code | Stay focused |
| Working patterns | If it works, don't "improve" |

## Phase 5: Human Checkpoint

The final gate. Human makes the decision.

### Report Format

```
Verification Report
═══════════════════════════════════════════════════

Session: verify-2026-01-16-1100
Branch:  execute/task-1-auth-middleware

Phase 1: Automated Checks
─────────────────────────
Tests:  ✓ 47/47 passed (3.2s)
Lint:   ✓ 0 errors, 3 warnings
Types:  ✓ 0 errors
Build:  ✓ success

Phase 2: Output Verification
────────────────────────────
Method: Web app screenshot + curl
Evidence:
  • Screenshot: .claude/evidence/login-flow.png
  • API test: POST /api/auth → 200 OK
  • Console: 0 errors

Phase 3: Code Simplification
────────────────────────────
Status: Completed
Changes: 3 simplifications, -15 lines
Tests: Still passing

Caveats
───────
• 3 lint warnings (style only)
• Flaky test detected in auth.test.ts (accepted)

═══════════════════════════════════════════════════

[Ready to Ship] [Needs Work] [Accept with Caveats]
```

### Decision Recording

```json
{
  "human_checkpoint": {
    "prompted_at": "2026-01-16T11:15:00Z",
    "decision": "ready_to_ship",
    "caveats": ["3 lint warnings accepted"],
    "reviewer": "human"
  }
}
```

## Post-Verification

### File Manifest Generation (C-6)

After human approves, generate integrity manifest:

```bash
find . \( -name '*.ts' -o -name '*.tsx' -o -name '*.js' \
  -o -name '*.py' -o -name '*.rs' -o -name '*.go' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' \
  | sort | xargs sha256sum > .claude/verify-manifest.txt
```

This allows /ship to detect post-verification modifications.

### Final State

```json
{
  "session_id": "verify-2026-01-16-1100",
  "all_checks_passed": true,
  "human_checkpoint": {
    "decision": "ready_to_ship"
  },
  "unlock_ship": true,
  "verified_manifest": "sha256:abc123...",
  "verified_commit_sha": "def456..."
}
```

## Quick Reference

| Phase | What | Evidence |
|-------|------|----------|
| Pre-flight | Execute completed | execute-state.json |
| 1a | Tests pass | Exit code, count |
| 1b | Lint clean | Exit code, error count |
| 1c | Types check | Exit code |
| 2 | See it working | Screenshots, curl, CLI output |
| 3 | Polish (optional) | Diff, test results |
| 5 | Human approves | Decision in state |
| Post | Manifest generated | SHA256 hashes |
