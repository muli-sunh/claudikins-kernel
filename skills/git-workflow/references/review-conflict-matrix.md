# Review Conflict Matrix

Handling disagreements between spec-reviewer and code-reviewer.

## The RESOLVE Framework

When humans reviewing code disagree, the RESOLVE framework categorises conflicts and prescribes resolution paths.

### Type I: Stylistic Conflicts (Subjective)

**Examples:** Variable naming, indentation, bracket placement, import ordering.

**Resolution:**
1. Defer to the Style Guide
2. If Style Guide is silent, Author's preference prevails
3. Mark comments as `Nit:` (non-blocking)

**Best Practice:** These should be enforced by linters (Prettier, ESLint, clang-format), not humans.

```
Reviewer: "I prefer camelCase for this variable"
Resolution: Check style guide. If no rule, author decides.
```

### Type II: Empirical Conflicts (Fact-Based)

**Examples:** Performance claims ("This loop is O(n^2)"), Security vulnerabilities, Correctness bugs.

**Resolution:**
1. **Data wins.** Provide evidence.
2. If reviewer claims performance issue, they must provide benchmark or complexity analysis
3. If data supports the claim, code must change

```
Reviewer: "This is O(n^2) and will timeout on large inputs"
Author: "Prove it"
Resolution: Reviewer runs benchmark showing 10s on 10k items. Code changes.
```

### Type III: Architectural Conflicts (Design)

**Examples:** Choice of design pattern, library selection, modularity boundaries.

**Resolution:**
1. **Synchronous discussion first** - Video/in-person. Text strips nuance.
2. **Document the tradeoff** in the CL/PR description
3. **If unresolved, escalate** to Tech Lead or Code Owner for binding decision

```
Reviewer: "Use the Repository pattern here"
Author: "Direct queries are simpler"
Resolution: Meeting → Document tradeoffs → Lead decides
```

### The Decision Matrix

For complex tradeoffs, use a weighted decision matrix to objectify the choice:

| Criterion | Weight | Option A Score | Option B Score |
|-----------|--------|----------------|----------------|
| Maintainability | 0.3 | 8 | 6 |
| Performance | 0.25 | 6 | 9 |
| Time to Implement | 0.2 | 9 | 4 |
| Team Familiarity | 0.25 | 7 | 5 |
| **Weighted Total** | | **7.45** | **6.05** |

This removes emotion from the equation. Option A wins.

## Understanding Reviewer Roles

The reviewers check **different things**:

| Reviewer | Question | Model | Focus |
|----------|----------|-------|-------|
| spec-reviewer | "Did it do what was asked?" | haiku | Compliance with requirements |
| code-reviewer | "Is it well-written?" | opus | Quality and maintainability |

**They should rarely conflict** because they're checking orthogonal dimensions. Conflicts usually indicate:
- Misunderstanding of task scope
- Ambiguous acceptance criteria
- Implementation that technically meets spec but is problematic

## Conflict Scenarios

### Scenario 1: Spec PASS, Code CONCERNS

Most common conflict. Implementation meets requirements but has quality issues.

**Example:**
- spec-reviewer: "PASS - All CRUD endpoints exist, return correct status codes"
- code-reviewer: "CONCERNS - No input validation, SQL injection vulnerability"

**Resolution:** The spec was incomplete. Accept the implementation meets current spec, but flag for follow-up.

### Scenario 2: Spec FAIL, Code PASS

Rare. Implementation is high-quality but doesn't match requirements.

**Example:**
- spec-reviewer: "FAIL - Spec said REST, implementation is GraphQL"
- code-reviewer: "PASS - Clean GraphQL implementation"

**Resolution:** Revert or revise. Good code that does the wrong thing is still wrong.

### Scenario 3: Both PASS, Different Evidence

Both approve but cite different aspects.

**Example:**
- spec-reviewer: "PASS - Endpoint returns 200 for valid input"
- code-reviewer: "PASS - Clean error handling, good test coverage"

**Resolution:** No conflict. Different reviewers noticed different strengths.

### Scenario 4: Contradictory Findings

One says X exists, other says X is missing.

**Example:**
- spec-reviewer: "PASS - Error handling exists at line 42"
- code-reviewer: "CONCERNS - Missing error handling for edge case"

**Resolution:** They're checking different scopes. spec-reviewer found the required error handling. code-reviewer found additional edge cases not in spec. Both are correct.

## Resolution Matrix

| Spec Verdict | Code Verdict | Action | Human Options |
|--------------|--------------|--------|---------------|
| PASS | PASS | Accept | [Accept] [Revise anyway] |
| PASS | CONCERNS (minor) | Accept with note | [Accept] [Fix minor] |
| PASS | CONCERNS (important) | Review needed | [Accept caveats] [Fix] [Klaus] |
| PASS | CONCERNS (critical) | Must address | [Fix critical] [Klaus] |
| FAIL | PASS | Revise | [Revise to match spec] [Update spec] |
| FAIL | CONCERNS | Revise | [Revise implementation] |
| FAIL | FAIL | Major revision | [Retry task] [Klaus] [Abort] |

### Decision Tree

```
Spec verdict?
├── PASS →
│   Code verdict?
│   ├── PASS → Accept (clean approval)
│   ├── CONCERNS (minor) → Accept with notes
│   ├── CONCERNS (important) →
│   │   Issue related to spec gap?
│   │   ├── Yes → Accept, add follow-up task
│   │   └── No → Fix before accepting
│   └── CONCERNS (critical) →
│       Security issue?
│       ├── Yes → Must fix, no exceptions
│       └── No → Human decides: fix or accept risk
│
└── FAIL →
    Failure reason?
    ├── Missing requirement → Revise implementation
    ├── Scope violation → Revert additions, retry
    └── Wrong approach → Klaus analysis or replan
```

## Escalation Paths

### Escalate to Klaus When:

1. **Reviewers directly contradict** - One says line 42 has handling, other says it doesn't
2. **Failure reason unclear** - "FAIL" without actionable feedback
3. **Fix attempts failing** - Revised twice, still failing review
4. **Potential spec issue** - Implementation seems correct, spec may be wrong

```
Review conflict detected - invoking Klaus.

spec-reviewer: PASS at line 42
code-reviewer: Missing handling for this case

Klaus will:
- Analyse both reviewer outputs
- Examine the actual code
- Determine if this is a spec gap, reviewer error, or real issue
```

### Escalate to Human When:

1. **Risk acceptance needed** - Code has known issues but may be acceptable
2. **Spec ambiguity** - Requirements can be interpreted multiple ways
3. **Priority decision** - Fix now vs. follow-up task
4. **Scope question** - Is this enhancement in or out of scope?

```
Human decision needed:

spec-reviewer: PASS
code-reviewer: CONCERNS - No rate limiting on auth endpoint

Options:
[Accept risk]      - Deploy without rate limiting
[Add follow-up]    - Create task for rate limiting
[Fix now]          - Add rate limiting to this task
[Clarify scope]    - Was rate limiting in requirements?
```

### Accept with Caveats When:

1. **Known limitation** - Spec didn't require X, code doesn't have X
2. **Minor style issues** - Doesn't match preferences but works
3. **Performance trade-off** - Correct but not optimal
4. **Tech debt noted** - Works but should be refactored later

```
Accepting with caveats:

Task: Add user endpoint
spec-reviewer: PASS
code-reviewer: CONCERNS (minor)

Caveats:
- Uses any type in one place (line 73)
- Could benefit from caching (line 89)

These are noted for future improvement, not blocking acceptance.
```

## Recording Conflict Resolution

In execute-state.json:

```json
{
  "tasks": {
    "task-3": {
      "reviews": {
        "spec": { "verdict": "PASS", "evidence": "..." },
        "code": { "verdict": "CONCERNS", "issues": [...] }
      },
      "conflict_resolution": {
        "type": "accept_with_caveats",
        "human_decision": true,
        "caveats": ["Missing rate limiting - follow-up task created"],
        "follow_up_tasks": ["task-12"],
        "timestamp": "2026-01-16T15:00:00Z"
      }
    }
  }
}
```

## Anti-Patterns

### Ignoring Code Concerns Because Spec Passed

**Wrong:** "Spec passed, ship it."

**Right:** Code concerns may reveal spec gaps. Review before accepting.

### Trusting One Reviewer Over Other

**Wrong:** "Opus is smarter, trust code-reviewer."

**Right:** They check different things. Both matter.

### Auto-Resolving Conflicts

**Wrong:** Algorithm picks winner based on severity.

**Right:** Human reviews conflicts, makes informed decision.
