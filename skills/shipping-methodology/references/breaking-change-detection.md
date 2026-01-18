# Breaking Change Detection (S-24)

Detecting and handling breaking changes before shipping.

## What is a Breaking Change?

A change that requires consumers to modify their code or behaviour.

## Breaking Change Signals

### Definite Breaking Changes

| Signal | Example | Severity |
|--------|---------|----------|
| Removed public function | `export function login()` deleted | Critical |
| Removed public class | `export class AuthService` deleted | Critical |
| Removed API endpoint | `DELETE /api/v1/users` removed | Critical |
| Removed config option | `enableLegacyAuth` no longer works | Critical |
| Changed function signature | `login(email)` → `login(email, options)` | Critical |
| Changed return type | `string` → `number` | Critical |
| Changed error type | Different exception thrown | High |

### Potentially Breaking Changes

| Signal | Example | Severity |
|--------|---------|----------|
| Changed default value | `timeout: 30` → `timeout: 60` | Medium |
| Changed validation | Now rejects previously valid input | Medium |
| Changed ordering | Results now sorted differently | Medium |
| Changed timing | Async where sync before | Medium |
| Renamed public API | `getUser` → `fetchUser` | High |

### Not Breaking (Usually)

| Signal | Example |
|--------|---------|
| Added new function | New export added |
| Added optional parameter | `login(email, options?)` |
| Added new field to response | `{ user, newField }` |
| Internal refactoring | Private code changed |
| Performance improvements | Same API, faster |

## Detection Methods

### Static Analysis

```bash
# Compare exports between versions
# TypeScript
npx ts-node scripts/compare-exports.ts

# JavaScript
diff <(grep -r "export" src/ --include="*.js" | sort) \
     <(git show HEAD~1:src/**/*.js | grep "export" | sort)
```

### Export Comparison

```typescript
// scripts/compare-exports.ts
import { Project } from 'ts-morph';

const project = new Project();
project.addSourceFilesAtPaths('src/**/*.ts');

const exports = project.getSourceFiles()
  .flatMap(f => f.getExportedDeclarations())
  .map(([name, decls]) => ({
    name,
    type: decls[0].getKindName()
  }));

console.log(JSON.stringify(exports, null, 2));
```

### API Endpoint Comparison

```bash
# Extract routes from codebase
grep -r "app\.\(get\|post\|put\|delete\|patch\)" src/ \
  | sed 's/.*app\.\(get\|post\|put\|delete\|patch\)(\([^)]*\).*/\U\1 \2/'
```

### Package.json Analysis

```bash
# Check for removed dependencies that might affect API
diff <(jq '.dependencies | keys[]' package.json.old) \
     <(jq '.dependencies | keys[]' package.json)
```

## Automated Detection

### Pre-Ship Check

```bash
#!/bin/bash
# detect-breaking-changes.sh

BREAKING_CHANGES=()

# Check for removed exports
REMOVED_EXPORTS=$(git diff HEAD~1 --name-only -- '*.ts' '*.js' | \
  xargs -I{} sh -c 'git show HEAD~1:{} 2>/dev/null | grep "^export"' | \
  sort | uniq)

CURRENT_EXPORTS=$(find src -name '*.ts' -o -name '*.js' | \
  xargs grep "^export" | sort | uniq)

# Compare (simplified)
while read export; do
  if ! echo "$CURRENT_EXPORTS" | grep -q "$export"; then
    BREAKING_CHANGES+=("Removed: $export")
  fi
done <<< "$REMOVED_EXPORTS"

if [ ${#BREAKING_CHANGES[@]} -gt 0 ]; then
  echo "BREAKING CHANGES DETECTED:"
  printf '%s\n' "${BREAKING_CHANGES[@]}"
  exit 1
fi
```

### TypeScript API Extractor

Use `@microsoft/api-extractor` for comprehensive API comparison:

```bash
# Generate API report
npx api-extractor run --local

# Compare with previous
diff api-report/project.api.md api-report/project.api.md.old
```

## Detection in claudikins-kernel:ship

```
Scanning for breaking changes...

Breaking changes detected:

1. REMOVED: export function authenticate()
   Location: src/auth/index.ts:45
   Consumers: Likely external

2. CHANGED: login() signature
   Before: login(email: string): Promise<User>
   After:  login(email: string, options: LoginOptions): Promise<User>
   Location: src/auth/login.ts:12

3. REMOVED: /api/v1/auth endpoint
   Location: src/routes/auth.ts
   Replaced by: /api/v2/auth

This requires a MAJOR version bump (1.x.x → 2.0.0)

[Acknowledge and continue] [View migration guide] [Abort]
```

## Handling Detected Breaking Changes

### Version Bump

```
Breaking changes require MAJOR version bump.

Current version: 1.5.2
Suggested version: 2.0.0

[Accept 2.0.0] [Choose different version] [Abort]
```

### Migration Guide Prompt

```
Breaking changes detected. A migration guide is recommended.

Would you like to create MIGRATION.md?

[Yes - create guide] [No - skip] [I'll write it manually]
```

### Migration Guide Template

```markdown
# Migration Guide: v1.x to v2.0

## Breaking Changes

### `authenticate()` removed

**Before:**
```typescript
import { authenticate } from 'my-package';
authenticate(token);
```

**After:**
```typescript
import { verifyToken } from 'my-package';
verifyToken(token, { strict: true });
```

### `login()` signature changed

**Before:**
```typescript
const user = await login(email);
```

**After:**
```typescript
const user = await login(email, { remember: true });
// Or with defaults:
const user = await login(email, {});
```

## Deprecation Timeline

- v1.5.0: Deprecation warnings added
- v2.0.0: Breaking changes applied
```

## Changelog Entry for Breaking Changes

```markdown
## [2.0.0] - 2026-01-17

### BREAKING CHANGES

- **`authenticate()` removed** - Use `verifyToken()` instead (#100)
- **`login()` requires options parameter** - Pass empty object for defaults (#101)
- **`/api/v1/auth` removed** - Use `/api/v2/auth` (#102)

See [MIGRATION.md](./MIGRATION.md) for upgrade instructions.

### Added
- New `verifyToken()` function with improved security (#100)
- `LoginOptions` for customisable login behaviour (#101)
```

## Commit Message for Breaking Changes

```
feat(auth)!: Replace authenticate with verifyToken

BREAKING CHANGE: The `authenticate()` function has been removed.
Use `verifyToken(token, options)` instead.

Migration:
- Replace `authenticate(token)` with `verifyToken(token, { strict: true })`
- Update imports to use new function name

Closes #100
```

## False Positive Handling

Sometimes detection flags non-breaking changes:

```
Potential breaking change detected:

RENAMED: getUserById → fetchUserById
Location: src/internal/users.ts

This appears to be an internal function (not exported).

Is this actually breaking?

[No - ignore] [Yes - it's breaking] [Not sure]
```

## Suppressing Detection

For known non-breaking changes:

```bash
# In commit message
# @breaking-change-ok: Renamed internal function
```

Or in config:

```json
{
  "breakingChangeIgnore": [
    "src/internal/**",
    "src/**/*.test.ts"
  ]
}
```

## Best Practices

1. **Detect early** - Run detection before shipping
2. **Require acknowledgement** - Don't auto-ignore breaking changes
3. **Bump major version** - Follow semver strictly
4. **Write migration guide** - Help consumers upgrade
5. **Deprecate first** - Warn before removing (when possible)
6. **Communicate** - Notify consumers before release
