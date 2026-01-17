# Task Decomposition

How to break a plan into executable tasks that babyclaude agents can complete in isolation.

## The ATIR Criteria

Every task must satisfy all four:

### Atomic

**Can be completed in one agent session without context death.**

| Good | Bad |
|------|-----|
| "Add auth middleware to `/api/users`" | "Build authentication system" |
| "Create `UserService.findById()` method" | "Implement user management" |
| "Add validation for email field" | "Add all form validations" |

**Rule of thumb:** If it needs more than 200 lines of changes, split it.

### Testable

**Has measurable acceptance criteria.**

| Good | Bad |
|------|-----|
| "Returns 401 for invalid token" | "Handles auth properly" |
| "Creates record in database" | "Saves user data" |
| "Renders within 100ms" | "Is fast enough" |

**Every task needs at least one concrete assertion** that can be verified.

### Independent

**Can be reviewed and potentially merged in isolation.**

| Good | Bad |
|------|-----|
| "Add endpoint (can be tested standalone)" | "Add endpoint that calls service that calls repo" |
| "Create service method" | "Create method and update all callers" |

**Dependencies are OK** - just declare them. But the task itself should make sense alone.

### Right-Sized

**Not too small (noise) or too large (context death).**

| Too Small | Just Right | Too Large |
|-----------|------------|-----------|
| "Add import statement" | "Add logger to auth module" | "Add logging throughout app" |
| "Fix typo in comment" | "Add input validation to form" | "Refactor all forms" |
| "Rename variable" | "Extract helper function" | "Refactor utils module" |

**Sweet spot:** 50-200 lines of changes, 2-5 acceptance criteria.

## Size Guidelines

### Lines of Code

| Size | Lines Changed | Recommendation |
|------|---------------|----------------|
| Tiny | < 20 | Consider batching with related tiny tasks |
| Small | 20-50 | Good for focused fixes |
| Medium | 50-200 | Ideal task size |
| Large | 200-500 | Consider splitting |
| Huge | > 500 | Must split |

### Acceptance Criteria Count

| Count | Assessment |
|-------|------------|
| 0 | Invalid - every task needs verification |
| 1-2 | Simple task, quick review |
| 3-5 | Standard task |
| 6-10 | Complex task, consider splitting |
| > 10 | Definitely split |

### Context Budget

Assume babyclaude gets ~50k tokens of context. Budget:

| Component | Tokens |
|-----------|--------|
| System prompt + skill context | ~10k |
| Task description + criteria | ~2k |
| Files to read | ~15k |
| Working space for edits | ~15k |
| Safety margin | ~8k |

**If the task requires reading more than 5-6 large files, split it.**

## Dependency Mapping

### Dependency Types

| Type | Symbol | Example |
|------|--------|---------|
| Hard | `→` | Task 2 cannot start until Task 1 commits |
| Soft | `~>` | Task 2 benefits from Task 1 but can proceed |
| None | `-` | Tasks can run in parallel |

### Recording Dependencies

In the task table:

```markdown
| # | Task | Deps |
|---|------|------|
| 1 | Create schema | - |
| 2 | Add service | 1 |
| 3 | Add endpoint | 2 |
| 4 | Add tests | 1 |
```

Tasks 2 and 4 can run in parallel (both depend only on 1).
Task 3 must wait for Task 2.

### Dependency Graph Validation

Before execution, validate:

1. **No cycles** - Task A depends on B depends on A
2. **All deps exist** - No reference to non-existent tasks
3. **Batches respect deps** - Tasks in same batch have no inter-dependencies

## Common Patterns

### CRUD Feature

```markdown
| # | Task | Deps | Batch |
|---|------|------|-------|
| 1 | Create database schema | - | 1 |
| 2 | Implement repository | 1 | 2 |
| 3 | Implement service | 2 | 2 |
| 4 | Implement controller | 3 | 3 |
| 5 | Add route | 4 | 3 |
| 6 | Add integration tests | 5 | 4 |
```

### Refactoring

```markdown
| # | Task | Deps | Batch |
|---|------|------|-------|
| 1 | Extract interface | - | 1 |
| 2 | Update implementation A | 1 | 2 |
| 3 | Update implementation B | 1 | 2 |
| 4 | Update callers | 2,3 | 3 |
| 5 | Remove old code | 4 | 4 |
```

### Bug Fix

```markdown
| # | Task | Deps | Batch |
|---|------|------|-------|
| 1 | Add failing test | - | 1 |
| 2 | Fix the bug | 1 | 2 |
| 3 | Add regression tests | 2 | 3 |
```

### Feature Flag Addition

```markdown
| # | Task | Deps | Batch |
|---|------|------|-------|
| 1 | Add flag to config | - | 1 |
| 2 | Add conditional logic | 1 | 2 |
| 3 | Add flag check to UI | 1 | 2 |
| 4 | Add tests for both states | 2,3 | 3 |
```

## Anti-Patterns

### Too Granular

**Bad:**
```markdown
| 1 | Import lodash |
| 2 | Add debounce call |
| 3 | Export function |
```

**Good:**
```markdown
| 1 | Add debounced search handler |
```

### Too Vague

**Bad:**
```markdown
| 1 | Fix the user bug |
```

**Good:**
```markdown
| 1 | Fix duplicate user creation on rapid form submit |
```

### Hidden Dependencies

**Bad:**
```markdown
| 1 | Add UserService | - |
| 2 | Add AuthService | - |  # Actually needs UserService!
```

**Good:**
```markdown
| 1 | Add UserService | - |
| 2 | Add AuthService | 1 |
```

### Scope Bundling

**Bad:**
```markdown
| 1 | Add user endpoint and also fix that login bug |
```

**Good:**
```markdown
| 1 | Add user endpoint |
| 2 | Fix login redirect bug |
```

## Decomposition Example

### Before (One Big Task)

> "Implement user authentication with JWT tokens, session management, and password reset functionality"

### After (Decomposed)

```markdown
| # | Task | Acceptance Criteria | Deps | Batch |
|---|------|---------------------|------|-------|
| 1 | Create User schema | - Schema has email, password_hash, created_at | - | 1 |
| 2 | Add password hashing util | - bcrypt with salt rounds config | - | 1 |
| 3 | Implement register endpoint | - Creates user, returns 201 | 1,2 | 2 |
| 4 | Implement login endpoint | - Returns JWT on valid creds, 401 on invalid | 1,2 | 2 |
| 5 | Add JWT middleware | - Validates token, attaches user to req | - | 2 |
| 6 | Implement logout | - Invalidates session | 5 | 3 |
| 7 | Add password reset request | - Sends email with reset token | 1 | 3 |
| 8 | Add password reset confirm | - Validates token, updates password | 7 | 4 |
| 9 | Add auth integration tests | - Full flow coverage | 3,4,6,8 | 5 |
```

**Result:** 9 atomic tasks instead of 1 impossible task.

## Checklist

Before finalising task decomposition:

- [ ] Every task satisfies ATIR criteria
- [ ] Dependencies are explicit and acyclic
- [ ] Acceptance criteria are measurable
- [ ] No task exceeds 200 lines estimated
- [ ] Batches respect dependency order
- [ ] No hidden "and also" scope bundling
