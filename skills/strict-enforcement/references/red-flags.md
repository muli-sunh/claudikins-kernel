# Red Flags

Rationalisation patterns that indicate verification is being skipped or faked. These are the failure modes we're defending against.

## The Core Problem

Claude (and humans) naturally rationalise. When under pressure to complete, the temptation is to skip evidence gathering and claim confidence instead.

**This is the failure mode verification exists to prevent.**

The patterns below are warning signs that verification is being bypassed through reasoning rather than evidence.

## Verbal Red Flags

### "It should work because..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Reasoning from first principles instead of observation |
| **Why it's wrong** | Code doesn't care about your reasoning. It either works or it doesn't. |
| **What to do** | Run it. See it. Capture evidence. |

**Examples:**
- "It should work because I followed the same pattern as the other endpoint"
- "It should work because the types are correct"
- "It should work because I've done this before"

### "The tests pass so..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Treating tests as proof of correctness |
| **Why it's wrong** | Tests only cover what they cover. They don't prove end-to-end functionality. |
| **What to do** | Run the app. Screenshot the output. Curl the endpoints. |

**The test coverage illusion:**

```
What tests prove:    [████████░░░░░░░░░░░░] 40%
What "works" means:  [████████████████████] 100%
```

Tests verify isolated units. They don't verify:
- Integration between units
- Runtime environment
- Real data behaviour
- UI rendering
- Error recovery flows

### "I'm confident that..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Substituting feeling for evidence |
| **Why it's wrong** | Confidence is not a verification method |
| **What to do** | Convert confidence into evidence. What would make you confident? Do that, capture it. |

**Confidence vs Evidence:**

| Statement | Type | Value |
|-----------|------|-------|
| "I'm confident the API works" | Feeling | Zero |
| "I curled /api/users and got 200 OK" | Evidence | High |
| "I'm sure the login flow works" | Feeling | Zero |
| "Screenshot shows successful login redirect" | Evidence | High |

### "It worked before..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Assuming past state predicts current state |
| **Why it's wrong** | Code changes. Dependencies update. Environments drift. |
| **What to do** | Verify it works NOW. Fresh evidence for fresh claims. |

**Things that change:**
- Your code (obviously)
- Dependencies (npm update, pip upgrade)
- Environment variables
- Database state
- External APIs
- Runtime versions

### "The types check so..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Treating type safety as runtime correctness |
| **Why it's wrong** | Types don't catch runtime errors, async issues, external API changes |
| **What to do** | Types are necessary but not sufficient. Still need runtime verification. |

**What types catch:**
- Wrong argument types
- Missing properties
- Interface mismatches

**What types miss:**
- Runtime exceptions
- Async timing issues
- External API contract changes
- Environment configuration
- Data corruption
- Race conditions

### "I already checked this..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Relying on cached verification from earlier |
| **Why it's wrong** | Code may have changed since then. Verification is per-state. |
| **What to do** | Re-verify after changes. File manifest catches drift. |

**The staleness problem:**

```
Verified at: commit abc123
Current at:  commit def456
             ^^^^^^^^^^^^^^
             3 commits of unverified changes
```

### "It's a simple change..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Assuming simplicity implies safety |
| **Why it's wrong** | Simple changes can have complex effects. Off-by-one errors are "simple". |
| **What to do** | Verify proportionally, but still verify. |

**Famous "simple" bugs:**
- Off-by-one in loop bounds
- Null check in wrong order
- String vs number comparison
- Timezone handling
- Unicode edge cases

### "We can verify later..."

| Aspect | Detail |
|--------|--------|
| **What it means** | Deferring verification to skip it entirely |
| **Why it's wrong** | Later never comes. Technical debt compounds. |
| **What to do** | Verify now or explicitly mark as unverified with risk accepted. |

## Behavioural Red Flags

### Skipping catastrophiser

**What it looks like:** "Tests pass, let's ship."

**Why it's wrong:** catastrophiser is the feedback loop. It's how Claude learns what actually works vs what should work.

**The feedback loop:**

```
Without catastrophiser:
  Write code → Tests pass → Ship → Production bug → Learn nothing

With catastrophiser:
  Write code → Tests pass → SEE it working → Ship → Confidence justified
```

### Auto-approving checkpoints

**What it looks like:** Human clicks "Approve" without reviewing evidence.

**Why it's wrong:** Human checkpoint is the last line of defence. If it's rubber-stamped, it provides no value.

**Signs of rubber-stamping:**
- Approval within 2 seconds of prompt
- No questions asked
- No evidence reviewed
- Pattern of always approving

### Ignoring flaky test warnings

**What it looks like:** "It passed the second time, good enough."

**Why it's wrong:** Flaky tests hide real failures. They erode trust in the test suite.

**Flaky test lifecycle:**

```
1. Test sometimes fails
2. Team starts ignoring failures
3. Real bugs hide behind "it's just flaky"
4. Test suite becomes meaningless
5. Ship bugs to production
```

### Proceeding after lint/type failures

**What it looks like:** "It's just style" or "It's just a type warning."

**Why it's wrong:** Lint rules and type checks exist for reasons. Ignoring them normalises ignoring quality gates.

**The slippery slope:**

```
Week 1: "Just this one lint warning"
Week 2: "These 5 warnings are fine"
Week 4: "We'll fix the lint issues later"
Week 8: "Nobody looks at lint anymore"
```

### Modifying code after verification

**What it looks like:** "Just a quick fix before we ship."

**Why it's wrong:** Post-verification changes invalidate the verification. The file manifest exists to catch this.

**Why the manifest matters:**

```
Verified:  sha256:abc123 (for file.ts)
Current:   sha256:def456 (for file.ts)
           ^^^^^^^^^^^^^^
           VERIFICATION INVALID
```

### Dismissing failed verifications

**What it looks like:** "That failure doesn't matter" or "It's not related."

**Why it's wrong:** Every failure is information. Dismissing failures without investigation is ignoring data.

**Proper response to failure:**

```
Verification failed?
├── Investigate why
├── Determine if it's:
│   ├── Real bug → Fix it
│   ├── Test issue → Fix the test
│   ├── Environment → Document and handle
│   └── Transient → Retry with logging
└── NEVER just dismiss
```

## Red Flag Response Protocol

When you catch yourself or others using these patterns:

### 1. Stop

Don't proceed with the rationalisation. Pause the verification flow.

### 2. Name It

Call out the specific pattern:
- "That's a red flag: 'It should work because...'"
- "I'm hearing 'tests pass so' - we need actual evidence"

### 3. Get Evidence

Do the verification that was being skipped:
- Run the app
- Capture screenshots
- Curl the endpoints
- Check the logs

### 4. Record It

Note the near-miss for future learning:

```json
{
  "near_miss": {
    "timestamp": "2026-01-16T11:30:00Z",
    "red_flag": "tests_pass_so",
    "context": "Tried to skip output verification for API endpoint",
    "resolution": "Ran curl tests, found 500 error on edge case"
  }
}
```

## Red Flag Severity

| Red Flag | Severity | Why |
|----------|----------|-----|
| Skip catastrophiser | Critical | Removes entire feedback loop |
| Modify after verify | Critical | Invalidates verification |
| Auto-approve checkpoint | High | Human gate becomes useless |
| "Tests pass so" | High | Misunderstands what tests prove |
| "It should work" | Medium | Missing evidence |
| Ignore flaky tests | Medium | Erodes test trust |
| "Simple change" | Low | Still needs proportional check |

## See Also

- [verification-checklist.md](verification-checklist.md) - What to actually verify
- [advanced-verification.md](advanced-verification.md) - Complex scenarios
- [agent-integration.md](agent-integration.md) - How catastrophiser provides evidence
