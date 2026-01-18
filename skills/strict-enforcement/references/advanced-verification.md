# Advanced Verification

Complex verification scenarios that go beyond standard web/API/CLI patterns. Use this reference when the basic verification methods don't apply.

## Multi-Service Architectures

When the project involves multiple interconnected services.

### Microservices

**Challenge:** Service A depends on Service B depends on Service C. How do you verify?

**Approach:**

```
1. Identify service dependency graph
2. Start services in dependency order (leaves first)
3. Verify each service in isolation
4. Verify integration points
5. Verify end-to-end flow
```

**Evidence required:**

```json
{
  "architecture": "microservices",
  "services": [
    { "name": "auth-service", "port": 3001, "status": "healthy" },
    { "name": "user-service", "port": 3002, "status": "healthy" },
    { "name": "api-gateway", "port": 3000, "status": "healthy" }
  ],
  "integration_tests": [
    {
      "flow": "login → get user profile",
      "services_involved": ["api-gateway", "auth-service", "user-service"],
      "status": "PASS"
    }
  ]
}
```

### Docker Compose Environments

**Challenge:** Services defined in docker-compose.yml need orchestration.

**Approach:**

```bash
# Start all services
docker-compose up -d

# Wait for health checks
docker-compose ps --filter "health=healthy"

# Run verification against exposed ports
curl localhost:3000/health

# Capture logs as evidence
docker-compose logs --tail=50 > .claude/evidence/docker-logs.txt
```

**Timeout consideration:** Allow extra time for container startup (60s+ vs 30s).

## Database-Dependent Verification

When verification requires specific database state.

### Test Database Setup

**Never verify against production data.**

```
1. Check for test database configuration
2. If exists: use it
3. If not: create temporary SQLite/in-memory
4. Seed with minimal test data
5. Run verification
6. Tear down (or leave for debugging)
```

**Evidence required:**

```json
{
  "database": {
    "type": "postgresql",
    "mode": "test",
    "seeded": true,
    "tables_verified": ["users", "sessions", "tokens"]
  }
}
```

### Migration Verification

**Challenge:** Database migrations need to run successfully.

**Approach:**

```bash
# Run migrations
npm run db:migrate

# Verify schema
npm run db:schema:check

# Run seed (if applicable)
npm run db:seed

# Verify data integrity
npm run db:verify
```

## Authentication Flows

When the app requires authentication to verify.

### Session-Based Auth

**Approach:**

```
1. Hit login endpoint with test credentials
2. Capture session cookie
3. Use cookie for subsequent requests
4. Verify protected routes return 200
5. Verify logout invalidates session
```

**Evidence:**

```json
{
  "auth_flow": "session",
  "steps": [
    { "action": "login", "status": 200, "cookie_received": true },
    { "action": "access_protected", "status": 200 },
    { "action": "logout", "status": 200 },
    { "action": "access_protected_after_logout", "status": 401 }
  ]
}
```

### Token-Based Auth (JWT)

**Approach:**

```
1. Hit login endpoint
2. Extract token from response
3. Use token in Authorization header
4. Verify protected routes
5. Verify expired token handling (if testable)
```

### OAuth Flows

**Challenge:** OAuth requires external provider interaction.

**Options:**

| Option | When to Use |
|--------|-------------|
| Mock OAuth provider | Development/CI |
| Skip OAuth verification | Note as caveat |
| Manual verification | Document steps for human |

**Evidence when skipped:**

```json
{
  "auth_flow": "oauth",
  "verification": "skipped",
  "reason": "Requires external provider",
  "manual_verification_steps": [
    "Click 'Login with Google'",
    "Complete OAuth flow",
    "Verify redirect to dashboard"
  ]
}
```

## Real-Time Features

WebSockets, Server-Sent Events, and other real-time patterns.

### WebSocket Verification

**Approach:**

```
1. Open WebSocket connection
2. Send test message
3. Verify echo/response received
4. Verify connection cleanup
```

**Using tool-executor for WebSocket:**

```typescript
// In catastrophiser via tool-executor
const ws = new WebSocket('ws://localhost:3000/ws');

ws.on('open', () => {
  ws.send(JSON.stringify({ type: 'ping' }));
});

ws.on('message', (data) => {
  const response = JSON.parse(data);
  // Verify response
  ws.close();
});
```

### Server-Sent Events

**Approach:**

```bash
# Open SSE connection, capture first few events
curl -N localhost:3000/events | head -10 > .claude/evidence/sse-events.txt
```

## Scheduled Tasks / Cron Jobs

**Challenge:** Can't wait for scheduled time.

**Options:**

| Option | Approach |
|--------|----------|
| Trigger manually | If endpoint exists to trigger |
| Reduce interval | Temporarily set to 1s for verification |
| Mock time | If framework supports |
| Code review only | Verify logic, not timing |

**Evidence:**

```json
{
  "scheduled_task": "daily-cleanup",
  "verification_method": "manual_trigger",
  "trigger_endpoint": "POST /admin/trigger-cleanup",
  "result": {
    "records_cleaned": 15,
    "duration_ms": 230
  }
}
```

## File Processing

When the app processes files (uploads, exports, transformations).

### File Upload Verification

**Approach:**

```bash
# Upload test file
curl -X POST -F "file=@test.pdf" localhost:3000/upload

# Verify file appears in storage
ls -la uploads/

# Verify metadata saved
curl localhost:3000/api/files
```

### File Export Verification

**Approach:**

```bash
# Trigger export
curl localhost:3000/api/export/users?format=csv -o export.csv

# Verify file is valid CSV
head -5 export.csv
wc -l export.csv
```

## External API Integration

When the app calls external APIs.

### With Mock Server

**Preferred approach when possible.**

```
1. Start mock server (e.g., WireMock, MSW)
2. Configure mock responses
3. Run verification against real app
4. App calls mock instead of real API
```

### Without Mock

**When mocking not available:**

| Scenario | Approach |
|----------|----------|
| API has sandbox | Use sandbox credentials |
| API is read-only | Safe to call real API |
| API has side effects | Skip, document as caveat |
| API costs money | Skip, document as caveat |

**Evidence when skipped:**

```json
{
  "external_api": "stripe",
  "verification": "skipped",
  "reason": "Would create real charges",
  "caveat": "Stripe integration not runtime-verified",
  "code_review": "PASS - correct API usage patterns"
}
```

## Performance-Sensitive Code

When verification needs to check performance characteristics.

### Basic Timing

```bash
# Time the operation
time curl localhost:3000/api/heavy-operation

# Check response time
curl -w "%{time_total}" -o /dev/null localhost:3000/api/endpoint
```

### Load Testing (Light)

**Only for critical paths, not full load test:**

```bash
# Simple concurrent requests
for i in {1..10}; do
  curl -s localhost:3000/api/endpoint &
done
wait
```

**Evidence:**

```json
{
  "performance": {
    "endpoint": "/api/search",
    "requests": 10,
    "avg_response_ms": 145,
    "max_response_ms": 320,
    "threshold_ms": 500,
    "status": "PASS"
  }
}
```

## Security-Sensitive Verification

When changes affect security.

### Input Validation

**Verify with malicious inputs:**

```bash
# SQL injection attempt
curl "localhost:3000/api/users?id=1;DROP TABLE users"
# Should return 400 or sanitised response

# XSS attempt
curl "localhost:3000/api/search?q=<script>alert(1)</script>"
# Should return escaped/sanitised

# Path traversal
curl "localhost:3000/files/../../../etc/passwd"
# Should return 400 or 404
```

### Authentication Bypass

**Verify protected routes are protected:**

```bash
# Without auth
curl localhost:3000/api/admin
# Should return 401

# With invalid token
curl -H "Authorization: Bearer invalid" localhost:3000/api/admin
# Should return 401
```

## Partial Verification

When full verification isn't possible.

### What to Do

```
1. Verify what CAN be verified
2. Document what CANNOT be verified
3. Explain WHY it can't be verified
4. Suggest manual verification steps
5. Mark as caveat in human checkpoint
```

### Caveat Format

```json
{
  "verified": ["unit tests", "type check", "lint", "API endpoints"],
  "not_verified": ["OAuth flow", "payment processing", "email sending"],
  "reasons": {
    "OAuth flow": "Requires external provider",
    "payment processing": "Would create real charges",
    "email sending": "No email sandbox configured"
  },
  "manual_steps": {
    "OAuth flow": "1. Click login, 2. Complete Google auth, 3. Verify redirect",
    "payment processing": "Use Stripe test mode in staging",
    "email sending": "Check Mailtrap after manual test"
  }
}
```

## Verification in CI/CD Context

When claudikins-kernel:verify runs in automated pipelines.

### Headless Browser

For web verification without display:

```bash
# Playwright in headless mode
npx playwright test --headed=false

# Capture screenshots anyway
npx playwright screenshot localhost:3000 .claude/evidence/ci-home.png
```

### Port Conflicts

```bash
# Check if port available
nc -z localhost 3000 && echo "Port in use" || echo "Port available"

# Use random port
PORT=$(shuf -i 3000-4000 -n 1)
npm run dev -- --port $PORT
```

### Timeout Adjustments

CI environments are often slower:

| Environment | Default Timeout | Recommended |
|-------------|-----------------|-------------|
| Local | 30s | 30s |
| CI (standard) | 30s | 60s |
| CI (under load) | 30s | 120s |

## See Also

- [verification-checklist.md](verification-checklist.md) - Standard checklist
- [verification-method-fallback.md](verification-method-fallback.md) - When methods fail
- [agent-integration.md](agent-integration.md) - How catastrophiser handles these
