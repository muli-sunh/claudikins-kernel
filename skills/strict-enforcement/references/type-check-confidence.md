# Type Check Confidence (S-16)

How to interpret type-check results and understand what they do and don't prove. Types are necessary but not sufficient for verification.

## What Type Checks Prove

| Proven | Example |
|--------|---------|
| Function signatures match | `getUser(id: number)` called with number |
| Property access valid | `user.name` exists on User type |
| Return types correct | Function returns what it declares |
| Interface contracts | Object satisfies interface shape |
| Generic constraints | `T extends Comparable` is satisfied |
| Exhaustive switches | All enum cases handled |

## What Type Checks Don't Prove

| Not Proven | Example |
|------------|---------|
| Runtime values correct | `user.name` has correct value |
| Logic correct | `if (x > 0)` vs `if (x >= 0)` |
| API responses match | External API returns expected shape |
| Database queries work | SQL returns expected data |
| Async timing correct | Race conditions, deadlocks |
| Error handling works | Catch blocks actually catch |
| External contracts | Third-party API changes |

## Confidence Levels

### High Confidence

Type check result strongly indicates correctness.

```typescript
// Exhaustive enum handling
type Status = 'pending' | 'active' | 'complete';

function getColor(status: Status): string {
  switch (status) {
    case 'pending': return 'yellow';
    case 'active': return 'green';
    case 'complete': return 'gray';
  }
  // TypeScript ensures all cases handled
  // Adding new status WILL cause type error
}
```

**Confidence:** Very high that all statuses have colors.

### Medium Confidence

Type check passes but doesn't guarantee correctness.

```typescript
// Function signature correct, but logic might be wrong
function calculateDiscount(price: number, percent: number): number {
  return price * percent; // Bug: should be price * (percent / 100)
}
```

**Confidence:** Medium - types are correct, logic might not be.

### Low Confidence

Type check passes but runtime behaviour is uncertain.

```typescript
// Types say this works, but external API might disagree
interface ApiResponse {
  users: User[];
}

const response: ApiResponse = await fetch('/api/users').then(r => r.json());
// Type says response.users exists
// Runtime: API might return { data: { users: [] } } instead
```

**Confidence:** Low - external contract not enforced by types.

## Warning Signs in Type Check Output

### Excessive `any` Usage

```typescript
// BAD: any bypasses type checking
function process(data: any): any {
  return data.foo.bar.baz; // No type safety
}
```

**Red flag:** More than 5% of types are `any`.

**Action:** Flag for review, may indicate rushed code.

### Type Assertions (`as`)

```typescript
// Potentially unsafe
const user = response as User; // What if response isn't a User?
```

**Red flag:** Type assertions without runtime validation.

**Safer pattern:**

```typescript
// Runtime check before assertion
function isUser(obj: unknown): obj is User {
  return obj !== null && typeof obj === 'object' && 'id' in obj;
}

if (isUser(response)) {
  const user = response; // Type narrowed safely
}
```

### Non-Null Assertions (`!`)

```typescript
// Dangerous
const element = document.getElementById('app')!;
element.innerHTML = 'Hello'; // Crashes if element is null
```

**Red flag:** Non-null assertions on values that could be null.

**Action:** Review each `!` usage, ensure runtime check exists.

### `// @ts-ignore` or `// @ts-expect-error`

```typescript
// @ts-ignore
someFunction(wrongType); // Bypassing type check entirely
```

**Red flag:** Type errors being suppressed.

**Action:** Investigate why the error exists, fix root cause.

## Interpreting Type Check Results

### Clean Pass

```
$ npx tsc --noEmit
$ echo $?
0
```

**Interpretation:** Types are internally consistent. Does NOT mean:
- Logic is correct
- Runtime behaviour is correct
- External contracts are honoured

### Errors Found

```
$ npx tsc --noEmit
src/auth.ts:45:5 - error TS2322: Type 'string' is not assignable to type 'number'.
```

**Interpretation:** Genuine type mismatch. Must fix.

**DO NOT:**
- Add `as` assertion to silence it
- Add `// @ts-ignore`
- Change type to `any`

**DO:**
- Understand why types don't match
- Fix the actual type or the actual code

### Warnings (Strict Mode)

```
$ npx tsc --noEmit --strict
src/utils.ts:12:3 - error TS7006: Parameter 'x' implicitly has an 'any' type.
```

**Interpretation:** Loose typing detected. Consider adding explicit types.

## Strict Mode Checklist

For maximum type safety, enable these compiler options:

```json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "strictFunctionTypes": true,
    "strictBindCallApply": true,
    "strictPropertyInitialization": true,
    "noImplicitThis": true,
    "alwaysStrict": true
  }
}
```

### What Each Catches

| Option | Catches |
|--------|---------|
| noImplicitAny | Untyped parameters/variables |
| strictNullChecks | Null/undefined not handled |
| strictFunctionTypes | Contravariant function params |
| strictPropertyInitialization | Uninitialized class properties |
| noImplicitThis | `this` type unclear |

## Recording Type Check Results

```json
{
  "phase": "type_check",
  "status": "PASS",
  "command": "tsc --noEmit --strict",
  "exit_code": 0,
  "errors": 0,
  "warnings": 0,
  "analysis": {
    "strict_mode": true,
    "any_count": 3,
    "assertion_count": 5,
    "ts_ignore_count": 0
  },
  "confidence": "high",
  "notes": "3 `any` uses are in test mocks (acceptable)"
}
```

## When Type Check Isn't Enough

### External API Calls

```typescript
// Types say this is a User, but API might change
const user: User = await api.getUser(id);
```

**Additional verification needed:**
- Runtime type validation (zod, io-ts)
- Integration tests with real API
- Contract tests

### Database Queries

```typescript
// Types don't verify SQL correctness
const users = await db.query<User[]>('SELECT * FROM users');
```

**Additional verification needed:**
- Run actual query
- Check returned data shape
- Integration tests

### Complex Business Logic

```typescript
// Types don't verify business rules
function calculateTax(income: number, deductions: Deduction[]): number {
  // Complex logic that types can't verify
}
```

**Additional verification needed:**
- Unit tests with known inputs/outputs
- Property-based tests
- Manual verification of edge cases

## See Also

- [verification-checklist.md](verification-checklist.md) - Full verification checklist
- [red-flags.md](red-flags.md) - "Types check so..." is a red flag
- [advanced-verification.md](advanced-verification.md) - When static checks aren't enough
