# Lint Fix Validation (S-14)

How to safely validate that auto-fix didn't break code. Auto-fix is convenient but can introduce bugs.

## The Risk

Auto-fix tools transform code automatically. Most fixes are safe, but some can change behaviour:

| Fix Type | Risk Level | Example |
|----------|------------|---------|
| Formatting | None | Whitespace, semicolons |
| Import sorting | None | Reorder imports |
| Unused variable removal | Low | Remove `const x = 5;` |
| Auto-type narrowing | Medium | Adding type assertions |
| Code simplification | Medium | `!!value` → `Boolean(value)` |
| Async/await conversion | High | Promise chains → async/await |

## Validation Flow

```
Lint errors found
│
├── --fix-lint flag set?
│   │
│   ├── No → STOP: [Manual fix] [Apply auto-fix] [Skip]
│   │
│   └── Yes →
│       │
│       ├── Capture pre-fix state
│       │   └── git stash or save diff
│       │
│       ├── Run auto-fix
│       │   └── npm run lint -- --fix
│       │
│       ├── Validate fix
│       │   ├── Re-run lint (should pass now)
│       │   ├── Run tests (must still pass)
│       │   └── Type check (must still pass)
│       │
│       ├── All validations pass?
│       │   │
│       │   ├── Yes → Continue with fixed code
│       │   │   └── Record: "Auto-fix applied and validated"
│       │   │
│       │   └── No →
│       │       ├── Revert to pre-fix state
│       │       └── STOP: [Manual fix] [Skip lint] [Abort]
│       │
│       └── Show diff of changes made
│           └── Human can review what changed
```

## Pre-Fix Capture

Before running auto-fix, capture the current state:

```bash
# Option 1: Git stash (if clean working tree)
git stash push -m "pre-lint-fix"

# Option 2: Save diff
git diff > .claude/pre-lint-fix.diff

# Option 3: Copy affected files
mkdir -p .claude/pre-lint-fix
cp src/affected.ts .claude/pre-lint-fix/
```

## Running Auto-Fix

### ESLint

```bash
npm run lint -- --fix
# or
npx eslint . --fix
```

### Prettier

```bash
npx prettier --write .
```

### Ruff (Python)

```bash
ruff check --fix .
```

### Clippy (Rust)

```bash
cargo clippy --fix
```

## Post-Fix Validation

### Step 1: Lint Clean

```bash
npm run lint
# Exit code must be 0
```

### Step 2: Tests Pass

```bash
npm test
# Exit code must be 0
```

### Step 3: Types Check

```bash
npm run typecheck
# Exit code must be 0
```

### Step 4: Review Diff

```bash
git diff
# Examine what changed
```

## Dangerous Fixes to Watch

### Unused Import Removal

**Usually safe, but:**

```typescript
// BEFORE
import { SideEffectModule } from './side-effects';

// AFTER (auto-fixed - import removed)
// SideEffectModule's side effects no longer run!
```

**Watch for:** Imports that exist purely for side effects.

### Async/Await Conversion

**Can change timing:**

```javascript
// BEFORE
function getData() {
  return fetch('/api').then(r => r.json());
}

// AFTER (auto-fixed)
async function getData() {
  const r = await fetch('/api');
  return r.json();
}
```

**Usually equivalent, but:** Error handling may differ. Promise rejection vs thrown exception.

### Optional Chaining Addition

**Can change return value:**

```javascript
// BEFORE
const name = user && user.profile && user.profile.name;
// Returns: false, null, undefined, or name

// AFTER (auto-fixed)
const name = user?.profile?.name;
// Returns: undefined or name (never false/null)
```

**Safe if:** You only care about truthiness, not specific falsy value.

### Nullish Coalescing

**Can change behaviour:**

```javascript
// BEFORE
const value = input || 'default';
// 'default' if input is: false, 0, '', null, undefined

// AFTER (auto-fixed)
const value = input ?? 'default';
// 'default' only if input is: null, undefined
```

**Breaking change if:** Empty string or 0 should use default.

### Type Assertion Addition

**Can hide bugs:**

```typescript
// BEFORE (type error)
const el = document.getElementById('app');
el.innerHTML = 'Hello'; // Error: el might be null

// AFTER (auto-fixed)
const el = document.getElementById('app')!;
el.innerHTML = 'Hello'; // No error, but crashes if el is null
```

**Watch for:** Non-null assertions (`!`) that suppress valid errors.

## Recording Auto-Fix Results

```json
{
  "phase": "lint",
  "auto_fix_applied": true,
  "pre_fix_errors": 5,
  "post_fix_errors": 0,
  "files_modified": [
    "src/utils.ts",
    "src/auth.ts"
  ],
  "validation": {
    "lint_clean": true,
    "tests_pass": true,
    "types_check": true
  },
  "diff_summary": "Removed 2 unused imports, added 3 semicolons",
  "diff_file": ".claude/lint-fix.diff"
}
```

## Rollback Procedure

If validation fails:

```bash
# Option 1: Git restore
git checkout -- .

# Option 2: Apply saved diff in reverse
git apply -R .claude/pre-lint-fix.diff

# Option 3: Restore from backup
cp .claude/pre-lint-fix/* src/
```

## Human Checkpoint

If auto-fix changes significant code, prompt human:

```
Auto-fix made the following changes:

src/utils.ts:
  - Removed unused import 'lodash'
  - Converted callback to async/await

src/auth.ts:
  - Added non-null assertion on line 45

Tests: ✓ Passing
Types: ✓ Clean

The non-null assertion on auth.ts:45 may suppress a valid error.

[Accept changes]
[Review auth.ts:45]
[Revert and fix manually]
```

## Safe Fix Patterns

These are always safe to auto-fix:

| Pattern | Example |
|---------|---------|
| Trailing whitespace | Remove spaces at end of lines |
| Missing semicolons | Add `;` |
| Quote style | `"` → `'` |
| Import order | Sort alphabetically |
| Trailing commas | Add/remove |
| Indentation | Tabs ↔ spaces |

## Risky Fix Patterns

Review these before accepting:

| Pattern | Risk |
|---------|------|
| Unused variable removal | Might remove intentional placeholders |
| Type assertion addition | Might hide real errors |
| Async conversion | Might change error handling |
| Optional chaining | Might change falsy behaviour |
| Nullish coalescing | Might change falsy behaviour |

## See Also

- [verification-checklist.md](verification-checklist.md) - Full lint verification checklist
- [red-flags.md](red-flags.md) - Why "it's just lint" is a red flag
