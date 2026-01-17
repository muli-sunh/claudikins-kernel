# Commit Message Patterns

Complete guide to writing effective commit messages for /ship.

## Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

## Types

| Type | Use For | Example |
|------|---------|---------|
| `feat` | New feature | `feat(auth): Add JWT validation` |
| `fix` | Bug fix | `fix(api): Handle null response` |
| `docs` | Documentation only | `docs(readme): Update installation` |
| `style` | Formatting, no code change | `style(lint): Fix indentation` |
| `refactor` | Code change, no new feature or fix | `refactor(db): Simplify query builder` |
| `perf` | Performance improvement | `perf(cache): Add Redis caching` |
| `test` | Adding tests | `test(auth): Add token expiry tests` |
| `chore` | Maintenance | `chore(deps): Update lodash` |

## Scope

The scope is the module/component affected:

- `auth` - Authentication
- `api` - API endpoints
- `ui` - User interface
- `db` - Database
- `config` - Configuration
- `deps` - Dependencies

**Omit scope** if change is global or unclear.

## Subject Line Rules

1. **Imperative mood** - "Add feature" not "Added feature"
2. **No capitalisation** - Start lowercase after type
3. **No period** - Don't end with `.`
4. **Max 50 characters** - Keep it scannable
5. **What, not how** - Describe the change, not implementation

### Good Examples

```
feat(auth): add JWT token refresh
fix(api): handle empty response body
refactor(db): simplify connection pooling
```

### Bad Examples

```
feat(auth): Added JWT token refresh.     # Past tense, period
Fix API                                   # No type, vague
refactor: made database better           # Vague, past tense
```

## Body

Explain **why** the change was made, not **what** (the diff shows what).

```
feat(auth): add JWT token refresh

The previous implementation required users to re-login when tokens
expired. This adds automatic refresh using refresh tokens stored
in httpOnly cookies.

- Tokens refresh 5 minutes before expiry
- Failed refresh redirects to login
- Refresh tokens rotate on use
```

### When to Include Body

- Non-obvious changes
- Breaking changes
- Changes with trade-offs
- Changes fixing specific issues

### When to Skip Body

- Self-explanatory changes
- Simple fixes
- Dependency updates
- Style/formatting changes

## Footer

Reference issues and note breaking changes.

### Issue References

```
Closes #123           # Closes issue when merged
Fixes #456            # Fixes bug
Relates to #789       # Related but doesn't close
```

### Breaking Changes

**MUST use `!` in type and include `BREAKING CHANGE:` in footer:**

```
feat(api)!: change authentication endpoint

BREAKING CHANGE: The /auth endpoint now requires an API key header.
All clients must update to include X-API-Key header.

Migration:
1. Generate API key in dashboard
2. Add X-API-Key header to requests
3. Remove deprecated token parameter
```

## Multi-Commit vs Squash

### When to Squash

- Feature branch with messy history
- Multiple "fix typo" commits
- Work-in-progress commits
- Single logical change

### When to Preserve

- Multiple distinct features in branch
- Useful checkpoint history
- Large refactors with clear stages
- Collaborative work with multiple authors

## Examples by Scenario

### New Feature

```
feat(notifications): add email notifications for order status

Users can now receive email updates when their order status changes.
Supports: placed, shipped, delivered, cancelled.

- Uses SendGrid for email delivery
- Respects user notification preferences
- Includes order tracking link

Closes #234
```

### Bug Fix

```
fix(checkout): prevent double-charge on retry

Root cause: The payment processor retry logic didn't check for
existing successful transactions before retrying.

Fix: Added idempotency key check before processing payment.
If transaction exists and succeeded, return cached result.

Fixes #567
```

### Breaking Change

```
feat(api)!: require authentication for all endpoints

BREAKING CHANGE: All API endpoints now require authentication.
Previously, /health and /version were public.

Migration:
1. No action needed for authenticated clients
2. Service monitors must add auth headers
3. /health now returns 401 without auth (use /ping for unauthenticated health checks)

Closes #890
```

### Refactor

```
refactor(db): migrate from callbacks to async/await

Modernises database layer to use async/await instead of callbacks.
No functional changes - all existing tests pass.

Benefits:
- Cleaner error handling
- Easier debugging
- Better stack traces
```

### Chore

```
chore(deps): update dependencies

- lodash 4.17.20 → 4.17.21 (security)
- typescript 4.9.0 → 5.0.0 (new features)
- jest 28.0.0 → 29.0.0 (performance)

No breaking changes in our usage.
```

## Co-Author Attribution

When Claude assists:

```
feat(auth): add authentication middleware

- JWT token validation
- Role-based access control

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Commit Message Generation

When generating commit messages:

1. Read the diff (`git diff --staged`)
2. Identify the type of change
3. Determine the scope
4. Write imperative subject
5. Add body if non-obvious
6. Reference issues if applicable
7. Note breaking changes if any

**Fallback if generation fails:**

See [message-generation-fallback.md](message-generation-fallback.md).
