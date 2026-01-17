# Verification Method Fallback (S-15)

What to do when the primary verification method fails. This reference covers the fallback hierarchy (A-3) and decision points.

## The Fallback Hierarchy

When catastrophiser's primary verification method fails, it should fall back in this order:

```
Level 1: Full Runtime Verification (preferred)
├── Web: Start server + screenshot + test flows
├── API: Start server + curl endpoints
├── CLI: Run commands + capture output
└── Service: Start + health check + logs
    │
    ▼ If Level 1 fails
    │
Level 2: Test-Based Verification
├── Run full test suite
├── Run integration tests only
└── Check test coverage
    │
    ▼ If Level 2 fails
    │
Level 3: Static Verification
├── Run examples from docs
├── Type check with strict mode
└── Lint with security rules
    │
    ▼ If Level 3 fails
    │
Level 4: Code Review Only (last resort)
└── Manual inspection of changes
    └── Mark as "unverified at runtime"
```

## When to Fall Back

### Server Won't Start

**Symptoms:**
- Port already in use
- Missing environment variables
- Database not available
- Dependency service down

**Detection:**

```bash
# Check if server started
timeout 30 bash -c 'until nc -z localhost 3000; do sleep 1; done'

# Exit code 124 = timeout (server didn't start)
```

**Fallback to:** Level 2 (tests)

### Screenshot Fails

**Symptoms:**
- Playwright not available
- Browser won't launch (CI/headless issue)
- Page doesn't render (JS error)

**Detection:**

```bash
# Check Playwright available
npx playwright --version

# Check browser launches
npx playwright screenshot about:blank test.png
```

**Fallback to:** API verification (if endpoints exist) or Level 2 (tests)

### Curl Gets Unexpected Response

**Symptoms:**
- 500 errors on all endpoints
- Connection refused
- Timeout

**Fallback to:** Level 2 (tests)

### Tests Won't Run

**Symptoms:**
- Test framework not installed
- Test config broken
- No tests exist

**Fallback to:** Level 3 (static verification)

## Fallback Decision Tree

```
Primary method attempted
│
├── Success?
│   └── Yes → Use this evidence
│
└── No → Identify failure reason
    │
    ├── Transient (network, timing)?
    │   └── Retry once with backoff
    │
    ├── Environment issue?
    │   ├── Can be fixed quickly?
    │   │   ├── Yes → Fix and retry
    │   │   └── No → Fall back
    │   └── Examples:
    │       ├── Port in use → try different port
    │       ├── Missing env var → check .env.example
    │       └── DB not running → try in-memory
    │
    ├── Missing dependency?
    │   ├── Can install?
    │   │   ├── Yes → Install and retry
    │   │   └── No → Fall back
    │   └── Examples:
    │       ├── Playwright → npm i playwright
    │       └── Database driver → npm i pg
    │
    └── Fundamental incompatibility?
        └── Fall back to next level
```

## Recording Fallbacks

Each fallback should be recorded:

```json
{
  "verification": {
    "primary_method": "screenshot",
    "primary_status": "FAILED",
    "primary_failure_reason": "Playwright not available in CI",
    "fallback_attempts": [
      {
        "level": 2,
        "method": "integration_tests",
        "status": "PASS",
        "evidence": "42 integration tests passed"
      }
    ],
    "final_method": "integration_tests",
    "final_status": "PASS",
    "confidence": "medium",
    "caveats": ["No visual verification - screenshots not available"]
  }
}
```

## Confidence Levels by Method

| Method | Confidence | What It Proves |
|--------|------------|----------------|
| Full runtime (screenshot + curl) | High | App works end-to-end |
| Runtime (curl only) | High | API contracts work |
| Runtime (CLI only) | High | CLI functions work |
| Integration tests | Medium | Components integrate |
| Unit tests | Medium | Individual units work |
| Type check | Low | Types are consistent |
| Code review | Very Low | Code looks correct |

**Confidence impacts human checkpoint:**

```
Verification Method: Integration tests (fallback from screenshot)
Confidence: Medium

What was verified:
✓ All 42 integration tests pass
✓ API response shapes correct
✓ Auth flow works

What was NOT verified:
✗ Visual rendering
✗ Browser console errors
✗ CSS/layout issues

Caveat: Visual verification skipped - Playwright unavailable

[Accept with caveat] [Retry with screenshot] [Manual check]
```

## Level-Specific Guidance

### Level 1: Full Runtime

**Web Apps:**

```bash
# Start dev server
npm run dev &
PID=$!

# Wait for server
sleep 5

# Screenshot
npx playwright screenshot http://localhost:3000 home.png

# Test flows
npx playwright test e2e/

# Cleanup
kill $PID
```

**APIs:**

```bash
# Start server
npm start &
PID=$!

# Wait and test
sleep 3
curl -f http://localhost:3000/health
curl -f http://localhost:3000/api/users

# Cleanup
kill $PID
```

**CLIs:**

```bash
# Test primary commands
./mycli --help
./mycli process test-input.txt
./mycli validate --strict
```

### Level 2: Test-Based

```bash
# Full suite
npm test

# Integration only (if separated)
npm run test:integration

# With coverage
npm test -- --coverage
```

### Level 3: Static

```bash
# Examples from docs
node examples/basic-usage.js

# Strict type check
npx tsc --noEmit --strict

# Security lint
npm run lint -- --rule 'security/*'
```

### Level 4: Code Review

When all else fails:

```
Code Review Checklist:
- [ ] Changes match requirements
- [ ] No obvious bugs in logic
- [ ] Error handling present
- [ ] No security red flags
- [ ] Tests exist for new code

NOTE: This is NOT a substitute for runtime verification.
Mark as "unverified" and recommend manual testing.
```

## Human Checkpoint for Fallbacks

When using fallback methods, be explicit:

```
Verification completed with FALLBACK method.

Primary: Screenshot verification
Status: FAILED (Playwright unavailable)

Fallback: Integration tests
Status: PASS (42/42 tests)

Confidence: Medium (no visual verification)

This means:
✓ Backend logic verified
✓ API contracts verified
✗ Frontend rendering NOT verified
✗ Browser compatibility NOT verified

Recommended: Manual visual check before shipping

[Accept with caveats]
[Block until visual verification]
[Abort]
```

## Preventing Fallback Situations

### Ensure Playwright Available

```json
// package.json
{
  "devDependencies": {
    "playwright": "^1.40.0"
  },
  "scripts": {
    "postinstall": "playwright install"
  }
}
```

### Handle Port Conflicts

```javascript
// Use dynamic port
const port = process.env.PORT || 0; // 0 = random available
server.listen(port, () => {
  console.log(`Server on port ${server.address().port}`);
});
```

### Mock External Dependencies

```javascript
// In tests
jest.mock('./stripe-client');
jest.mock('./email-service');
```

## See Also

- [agent-integration.md](agent-integration.md) - How catastrophiser handles fallbacks
- [advanced-verification.md](advanced-verification.md) - Complex verification scenarios
- [verification-checklist.md](verification-checklist.md) - Full checklist
