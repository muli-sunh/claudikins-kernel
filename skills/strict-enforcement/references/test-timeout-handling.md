# Test Timeout Handling (S-13)

What to do when tests hang or take too long. This is a common failure mode that blocks verification.

## Timeout Thresholds

| Context | Default Timeout | Maximum |
|---------|-----------------|---------|
| Individual test | 5s | 30s |
| Test suite | 5 min | 15 min |
| Single test file | 60s | 5 min |

## Detecting Timeouts

### Symptoms

```
Test suite hangs:
├── No output for 60+ seconds
├── Process using 100% CPU (infinite loop)
├── Process using 0% CPU (deadlock/waiting)
└── Memory growing unbounded (memory leak)
```

### Detection Command

```bash
# Run tests with timeout
timeout 300 npm test

# Exit code 124 = timeout
if [ $? -eq 124 ]; then
  echo "Test suite timed out after 5 minutes"
fi
```

## Common Causes

| Cause | Symptoms | Solution |
|-------|----------|----------|
| Infinite loop | 100% CPU, no output | Find loop, add termination condition |
| Deadlock | 0% CPU, stuck | Check async/await, mutex usage |
| Missing callback | Test never completes | Ensure done() called or promise resolved |
| External dependency | Waiting for network | Mock external services |
| Database connection | Stuck on connect | Check connection string, mock DB |
| File system | Waiting on I/O | Check file paths, permissions |

## Response Flow

```
Test suite times out
│
├── Kill the process
│   └── timeout --signal=KILL 10 npm test
│
├── Identify which test hung
│   ├── Run tests in verbose mode
│   ├── Run tests one file at a time
│   └── Binary search test files
│
├── Once identified:
│   ├── Is it a known flaky test?
│   │   └── Yes → [Skip it] [Fix it] [Quarantine]
│   └── No →
│       ├── Can we fix quickly?
│       │   └── Yes → Fix and re-run
│       └── No →
│           └── STOP: [Skip test] [Abort verification]
│
└── Record in state
    └── "test_timeout": { "file": "...", "resolution": "..." }
```

## Identifying the Hanging Test

### Verbose Mode

```bash
# Jest
npm test -- --verbose

# Pytest
pytest -v

# Cargo
cargo test -- --nocapture
```

### Run Files Individually

```bash
# Jest - run single file
npm test -- auth.test.ts

# Pytest - run single file
pytest tests/test_auth.py

# If that passes, binary search:
# Run first half of test files
# If hangs, issue is in first half
# If passes, issue is in second half
# Repeat until isolated
```

### Add Timeout Logging

```javascript
// Jest - add to test
jest.setTimeout(10000); // 10 seconds

beforeEach(() => {
  console.log(`Starting: ${expect.getState().currentTestName}`);
});

afterEach(() => {
  console.log(`Finished: ${expect.getState().currentTestName}`);
});
```

## Fixing Common Issues

### Missing Async Handling

**Problem:**

```javascript
// BAD - test completes before async operation
test('fetches user', () => {
  fetchUser(1).then(user => {
    expect(user.name).toBe('Alice');
  });
});
```

**Solution:**

```javascript
// GOOD - async/await
test('fetches user', async () => {
  const user = await fetchUser(1);
  expect(user.name).toBe('Alice');
});

// OR - return promise
test('fetches user', () => {
  return fetchUser(1).then(user => {
    expect(user.name).toBe('Alice');
  });
});
```

### Unmocked External Calls

**Problem:**

```javascript
// BAD - actually calls Stripe
test('creates payment', async () => {
  const result = await createPayment(100);
  expect(result.status).toBe('succeeded');
});
```

**Solution:**

```javascript
// GOOD - mocked
jest.mock('../stripe');

test('creates payment', async () => {
  stripe.createCharge.mockResolvedValue({ status: 'succeeded' });
  const result = await createPayment(100);
  expect(result.status).toBe('succeeded');
});
```

### Database Connection Issues

**Problem:** Tests hang waiting for database connection.

**Solution:**

```javascript
// Use in-memory database for tests
beforeAll(async () => {
  await db.connect(process.env.TEST_DATABASE_URL || 'sqlite::memory:');
});

afterAll(async () => {
  await db.disconnect();
});
```

### Unresolved Promises

**Problem:**

```javascript
// BAD - promise never resolves
test('waits forever', async () => {
  await new Promise(() => {}); // Never resolves
});
```

**Detection:** Look for promises without resolve/reject calls.

## Timeout Configuration

### Jest

```javascript
// jest.config.js
module.exports = {
  testTimeout: 10000, // 10 seconds per test
};

// Or per-test:
test('slow test', async () => {
  // ...
}, 30000); // 30 second timeout for this test
```

### Pytest

```python
# pytest.ini
[pytest]
timeout = 60

# Or per-test:
@pytest.mark.timeout(30)
def test_slow_operation():
    pass
```

### Cargo

```toml
# Cargo.toml - no built-in timeout, use wrapper
```

```bash
# Use timeout command
timeout 60 cargo test test_name
```

## Recording Timeout Events

```json
{
  "phase": "test_suite",
  "status": "TIMEOUT",
  "timeout_ms": 300000,
  "identified_test": "tests/integration/payment.test.ts",
  "resolution": "skipped",
  "reason": "External Stripe API not mocked",
  "action_taken": "Added to skip list, noted as caveat"
}
```

## Human Checkpoint Options

When timeout occurs, present:

```
Test suite timed out after 5 minutes.

Identified: tests/integration/payment.test.ts
Cause: Waiting on external Stripe API (not mocked)

Options:
[Fix now]      - Mock Stripe and re-run
[Skip test]    - Continue without this test (note as caveat)
[Abort]        - Stop verification entirely
[Increase timeout] - Try with 15 minute timeout
```

## Prevention

### In Test Design

- Mock all external services
- Use test database, not production
- Set explicit timeouts per test
- Avoid real network calls
- Clean up resources in afterEach/afterAll

### In CI Configuration

```yaml
# GitHub Actions
- name: Run tests
  run: npm test
  timeout-minutes: 10
```

### In Project Setup

```bash
# .nvmrc or similar
# Ensure consistent Node version

# package.json
{
  "scripts": {
    "test": "jest --forceExit --detectOpenHandles"
  }
}
```

`--forceExit` kills Jest after tests complete (catches hanging handles).
`--detectOpenHandles` reports what's keeping the process alive.

## See Also

- [verification-checklist.md](verification-checklist.md) - Full test verification checklist
- [advanced-verification.md](advanced-verification.md) - Complex test scenarios
