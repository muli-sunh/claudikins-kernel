# PR Creation Strategy

Templates and patterns for creating pull requests during claudikins-kernel:ship.

## PR Title Format

```
<type>(<scope>): <description>
```

Same format as commit messages for consistency.

### Examples

```
feat(auth): Add authentication middleware
fix(api): Handle null response in user endpoint
refactor(db): Migrate to connection pooling
docs(readme): Update installation instructions
```

## PR Body Template

```markdown
## Summary

[2-3 bullet points describing the change at a high level]

## Changes

[Detailed breakdown of what changed]

## Testing

[How the changes were verified]

## Screenshots

[If applicable - UI changes, CLI output]

## Checklist

- [ ] Tests pass
- [ ] Lint passes
- [ ] Documentation updated
- [ ] Breaking changes noted
```

## Section-by-Section Approval

Each section is drafted and approved individually:

### 1. Summary

```
PR Summary
----------
Draft:
- Added JWT-based authentication
- Implemented role-based access control
- Added session management

[Accept] [Revise]
```

### 2. Changes

```
PR Changes Section
------------------
Draft:
### Authentication
- Added `authenticate()` middleware
- Added `requireRole()` decorator
- JWT tokens expire after 24 hours

### Session Management
- Sessions stored in Redis
- Auto-cleanup after 7 days

[Accept] [Revise]
```

### 3. Testing

```
PR Testing Section
------------------
Draft:
- Unit tests: 47 new tests, all passing
- Integration tests: Auth flow verified
- Manual testing: Login/logout flow tested
- catastrophiser verification: PASS

Evidence:
- Screenshot: .claude/evidence/login-flow.png
- API test: POST /api/auth returned 200

[Accept] [Revise]
```

### 4. Screenshots

```
PR Screenshots Section
----------------------
Include screenshots?

[Yes - select files] [No - skip]
```

If yes, select from `.claude/evidence/`:

```
Available evidence:
1. login-flow.png (12KB)
2. dashboard.png (45KB)
3. api-response.json (2KB)

[Include 1, 2] [Include all] [Skip]
```

## PR Labels

Suggest labels based on change type:

| Change Type | Suggested Labels |
|-------------|------------------|
| feat | `enhancement`, `feature` |
| fix | `bug`, `fix` |
| docs | `documentation` |
| refactor | `refactor`, `tech-debt` |
| perf | `performance` |
| breaking | `breaking-change` |

```
Suggested labels: enhancement, feature

[Accept] [Add more] [Skip labels]
```

## Reviewers

```
Request reviewers?

Team members with relevant expertise:
- @alice (auth expert)
- @bob (backend lead)

[Request @alice, @bob] [Skip - merge directly]
```

## Draft vs Ready

```
PR status:

[Create as ready for review]
[Create as draft]
```

**Draft** when:
- CI needs to pass first
- Want feedback before formal review
- Documentation incomplete

**Ready** when:
- All checks pass
- Confident in changes
- Ready for immediate review

## GitHub CLI Commands

### Create PR

```bash
gh pr create \
  --title "feat(auth): Add authentication middleware" \
  --body "$(cat pr-body.md)" \
  --label "enhancement" \
  --reviewer "alice,bob"
```

### Create Draft PR

```bash
gh pr create \
  --title "feat(auth): Add authentication middleware" \
  --body "$(cat pr-body.md)" \
  --draft
```

### Add Labels After Creation

```bash
gh pr edit 42 --add-label "breaking-change"
```

## PR Body by Scenario

### Feature PR

```markdown
## Summary

- Added authentication middleware with JWT support
- Implemented role-based access control
- Added session management with Redis

## Changes

### New Files
- `src/auth/middleware.ts` - Auth middleware
- `src/auth/roles.ts` - Role definitions
- `src/auth/session.ts` - Session management

### Modified Files
- `src/app.ts` - Added auth middleware
- `package.json` - Added jwt, bcrypt deps

## Testing

- 47 new unit tests (all passing)
- Integration test for full auth flow
- Manual testing of login/logout
- catastrophiser PASS with evidence

## Screenshots

![Login Flow](/.claude/evidence/login-flow.png)

## Checklist

- [x] Tests pass
- [x] Lint passes
- [x] Documentation updated
- [x] No breaking changes

Closes #42
```

### Bug Fix PR

```markdown
## Summary

- Fixed race condition in token refresh
- Added idempotency check for payments

## Root Cause

The payment processor retry logic didn't check for existing successful
transactions, causing double-charges on network timeouts.

## Fix

Added idempotency key lookup before processing. If transaction exists
and succeeded, return cached result instead of processing again.

## Testing

- Added regression test for double-charge scenario
- Verified fix in staging environment
- catastrophiser PASS

## Checklist

- [x] Tests pass
- [x] Regression test added
- [x] No breaking changes

Fixes #567
```

### Breaking Change PR

```markdown
## Summary

- Changed authentication endpoint to require API key
- Removed deprecated token parameter

## Breaking Changes

**All clients must update:**

1. Generate API key in dashboard
2. Add `X-API-Key` header to requests
3. Remove `?token=` query parameter

### Before
```bash
curl https://api.example.com/users?token=abc123
```

### After
```bash
curl -H "X-API-Key: abc123" https://api.example.com/users
```

## Migration Guide

See [MIGRATION.md](./MIGRATION.md) for detailed steps.

## Testing

- All existing tests updated
- Migration tested on staging
- Backwards compatibility removed intentionally

## Checklist

- [x] Tests pass
- [x] Documentation updated
- [x] Migration guide written
- [x] Breaking change noted in CHANGELOG

Closes #890
```

## Error Handling

### gh CLI Not Available

```
GitHub CLI (gh) not found.

[Install gh] [Create PR manually] [Skip PR creation]
```

### Not Authenticated

```
Not authenticated with GitHub.

Run: gh auth login

[Retry after auth] [Skip PR creation]
```

### PR Creation Failed

```
PR creation failed.

Error: Resource not accessible by integration

[Retry] [Create manually] [Save PR body to file]
```

If saving to file:
```bash
# Saved to .claude/pending-pr.md
# Create manually with:
gh pr create --body-file .claude/pending-pr.md
```
