# Review Criteria

Detailed checklists for the two-stage review process. spec-reviewer handles compliance, code-reviewer handles quality.

## The 400 LOC Threshold

Research indicates that code review efficacy degrades rapidly as volume increases. **The optimal batch size for a review is fewer than 400 lines of code (LOC).**

Beyond this threshold, the "defect detection rate" drops significantly. Reviewers shift from deep logic and security analysis to superficial stylistic checks (bikeshedding).

### Implications for Task Decomposition

| LOC | Review Quality | Action |
|-----|----------------|--------|
| 0-200 | Excellent | Ideal task size |
| 200-400 | Good | Acceptable |
| 400-600 | Degraded | Consider splitting |
| 600+ | Poor | Must split before review |

**Pre-review check:** Before spawning reviewers, estimate the diff size. If >400 LOC, flag for human decision:

```
Task diff exceeds 400 LOC threshold (estimated: 650 lines).
Review efficacy may be compromised.

Options:
[Review anyway]     - Accept degraded quality detection
[Split task]        - Break into smaller reviewable units
[Human review only] - Skip automated review, human handles
```

### What Counts as a "Line"

- Added lines (green in diff)
- Modified lines (context changes)
- **Exclude:** Deleted lines, auto-generated code, lock files

## Spec Reviewer Checklist

The spec-reviewer (haiku) answers: **"Did it do what was asked?"**

### Mandatory Checks

| Check | Question | Evidence Required |
|-------|----------|-------------------|
| Criteria coverage | Is each acceptance criterion addressed? | Line reference per criterion |
| Completeness | Are all required items implemented? | No TODO/FIXME for required items |
| Scope adherence | Is anything added beyond spec? | List any additions |
| Output format | Does agent JSON match schema? | Valid JSON with required fields |

### How to Map Criteria

For each acceptance criterion in the task:

```json
{
  "criterion": "Returns 401 for invalid token",
  "met": true,
  "evidence": "src/middleware/auth.ts:45 - throws UnauthorizedError"
}
```

**Every criterion needs explicit evidence.** "I looked and it seems fine" is not evidence.

### Scope Creep Detection

Scope creep = features added that weren't in the spec.

| OK | Not OK |
|----|--------|
| Small refactors necessary for the change | Refactoring unrelated code "while here" |
| Bug fixes discovered during implementation | Feature additions not in spec |
| Type improvements to touched code | Adding logging/metrics not requested |

**Report scope creep but don't auto-fail.** Let human decide if it's acceptable.

### Spec Reviewer Decision Tree

```
All acceptance criteria have evidence?
├── No → FAIL (missing: [list criteria without evidence])
└── Yes →
    Any scope creep detected?
    ├── Yes (minor) → PASS with note
    ├── Yes (major) → FAIL (scope violation: [list additions])
    └── No → PASS
```

## Code Reviewer Checklist

The code-reviewer (opus) answers: **"Is it well-written?"**

Assumes spec compliance already verified. Don't re-check requirements.

### Quality Dimensions

| Dimension | What to Check |
|-----------|---------------|
| **Style** | Matches existing codebase patterns (naming conventions, formatting, idioms) |
| **Error handling** | All failure paths have explicit handling; errors propagate correctly |
| **Edge cases** | Null/undefined checks, empty arrays, zero values, boundary conditions |
| **Security** | No injection vectors, secrets exposure, unsafe operations, path traversal |
| **Performance** | No obvious N+1 queries, unnecessary loops, blocking operations in hot paths |
| **Naming** | Variables and functions are self-documenting; no single-letter names (except iterators) |
| **Complexity** | Reasonable cyclomatic complexity; no deep nesting (>3 levels); functions under 50 lines |
| **Testability** | Can be unit tested; dependencies are injectable; no hidden global state |

### Detailed Sub-Checks

#### Error Handling
- [ ] Try/catch blocks have specific error types
- [ ] Errors include context (what failed, why)
- [ ] Async errors are properly caught
- [ ] Error recovery or clean failure (no silent swallowing)

#### Security
- [ ] User input validated before use
- [ ] SQL queries use parameterised statements
- [ ] File paths sanitised
- [ ] No `eval()` or equivalent with user data
- [ ] Secrets not logged or exposed

### Attack Surface Tracing Protocol

Security reviews require identifying the application's **Attack Surface**. Trace data flow from all entry points to sinks.

**Entry Points (Sources):**
- Browser input (forms, query params, headers)
- Cookies and session data
- External API feeds
- File uploads
- WebSocket messages
- Environment variables (user-controlled)

**Dangerous Sinks:**
- Database queries
- File system operations
- HTML/template output
- Command execution
- Log files
- External API calls

**Tracing Process:**

```
1. Identify all entry points in the diff
2. For each entry point, trace the data flow:
   Entry → Processing → Sink
3. At each step, verify:
   - Is the data validated?
   - Is the data sanitised for the sink type?
   - Can the data escape its intended context?
```

**Example Trace:**

```
Entry: req.query.search (line 45)
  ↓
Processing: None (direct use)
  ↓
Sink: db.query(`SELECT * FROM items WHERE name LIKE '%${search}%'`)
  ↓
VULNERABILITY: SQL injection - no parameterisation
Confidence: 95
```

**Secrets Management:**

No API keys, passwords, or cryptographic material should be hardcoded. These become permanent fixtures in git history.

| Check | Pattern to Flag |
|-------|-----------------|
| Hardcoded secrets | `password = "..."`, `apiKey: "sk-..."` |
| Committed .env | `.env` in diff (should be in .gitignore) |
| Config with secrets | `config.json` with credentials |
| Debug credentials | `admin/admin`, `test123` in code |

#### Edge Cases
- [ ] Empty array handling
- [ ] Null/undefined parameter handling
- [ ] Zero and negative number handling
- [ ] Empty string handling
- [ ] Maximum/minimum boundary values

## Confidence Scoring

**Only report issues you're confident about.**

| Confidence | Level | Action |
|------------|-------|--------|
| 0-25 | Very low | DO NOT report - probably wrong |
| 26-50 | Low | Note internally only |
| 51-79 | Medium | Report as "Minor" if pattern clearly violated |
| 80-89 | High | Report as "Important" |
| 90-100 | Very high | Report as "Critical" |

### Confidence Examples

| Issue | Confidence | Why |
|-------|------------|-----|
| SQL injection with string concat | 95 | Clear vulnerability pattern |
| Missing null check | 85 | Could cause runtime error |
| Inconsistent naming | 70 | Subjective, codebase varies |
| "Could be more efficient" | 40 | May be premature optimisation |
| "I don't like this pattern" | 20 | Pure preference |

### What Affects Confidence

**Increases confidence:**
- Issue causes definite runtime error
- Security vulnerability with known exploit
- Violates explicit codebase convention
- Reproducible test case exists

**Decreases confidence:**
- Framework might handle this
- Context you can't see might justify it
- Stylistic preference vs actual problem
- No concrete failure scenario

## Code Reviewer Decision Tree

```
Any critical issues (confidence 90+)?
├── Yes → CONCERNS (critical: [list with evidence])
└── No →
    Any important issues (confidence 80-89)?
    ├── Yes → CONCERNS (important: [list with evidence])
    └── No →
        Any minor issues (confidence 51-79)?
        ├── Yes → PASS with notes
        └── No → PASS
```

## Evidence Requirements

### Line Number Format

Always use: `filepath:line_number`

```
src/services/auth.ts:42
tests/auth.test.ts:156-162
```

### Test Output Format

```json
{
  "command": "npm test -- --grep 'auth'",
  "exit_code": 0,
  "relevant_output": "12 passing, 0 failing"
}
```

### Git Diff References

Reference specific hunks:

```
In the diff for src/auth.ts:
+  if (!token) {
+    throw new UnauthorizedError('Token required');
+  }
This addresses criterion: "Returns 401 for missing token"
```

### Screenshot Evidence

When verification requires visual check:

```json
{
  "screenshot": ".claude/evidence/login-form.png",
  "description": "Login form renders with email and password fields",
  "criterion": "Form displays correctly"
}
```

## Common False Positives

Issues that look wrong but aren't:

| False Positive | Why It's Not a Problem |
|----------------|------------------------|
| "Missing error handling in route" | Express error middleware catches it |
| "Unused import" | Tree-shaken by bundler, or type-only import |
| "No null check for parameter" | TypeScript strict mode + required param |
| "Hardcoded string" | Intentional for error messages, not config |
| "Magic number" | Well-known constant (HTTP 200, port 3000) |
| "Function too long" | Clear linear flow, splitting would obscure logic |
| "No logging" | Not requested in spec, would add noise |

### Before Reporting, Ask:

1. Does the framework/runtime handle this?
2. Does TypeScript's type system prevent this?
3. Is there context I'm missing that justifies this?
4. Would "fixing" this make the code worse?

If answer to any is "yes", increase your doubt threshold.

## Output Schemas

### Spec Reviewer Output

```json
{
  "task_id": "task-3",
  "verdict": "PASS",
  "criteria_checked": [
    { "criterion": "Returns 401 for invalid token", "met": true, "evidence": "src/auth.ts:45" },
    { "criterion": "Logs failed attempts", "met": true, "evidence": "src/auth.ts:48" }
  ],
  "scope_creep": [],
  "missing": []
}
```

### Code Reviewer Output

```json
{
  "task_id": "task-3",
  "verdict": "CONCERNS",
  "critical_issues": [],
  "important_issues": [
    {
      "file": "src/auth.ts",
      "line": 52,
      "issue": "Password compared without timing-safe comparison",
      "confidence": 85,
      "fix": "Use crypto.timingSafeEqual() instead of ==="
    }
  ],
  "minor_issues": [],
  "strengths": ["Clean separation of concerns", "Good error messages"]
}
```
