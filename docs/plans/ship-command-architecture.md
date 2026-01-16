# /ship Command Architecture

**Date:** 2026-01-16
**Source:** Guru Panel Final Consensus (18 points unanimous)
**Status:** Ready for implementation

---

## Philosophy

> "Ship with confidence, not hope."

- Only runs if /verify passed (exit code 2 gate)
- GRFP-style workflow for each shipping stage
- git-perfectionist handles docs via github-readme plugin
- Human checkpoint before final push
- Iterative, section-by-section approval

---

## Dependencies

### Build Dependencies (must exist first)
| Component | Type | Priority |
|-----------|------|----------|
| shipping-methodology/ | skill | P0 |
| git-perfectionist.md | agent | P0 |
| hooks.json | hooks | P0 |
| All /verify components | command | P0 |

### Plugin Dependencies
| Plugin | Required | Purpose |
|--------|----------|---------|
| claudikins-tool-executor | YES | MCP access |
| claudikins-automatic-context-manager | YES | Context monitoring |
| claudikins-github-readme | YES | GRFP for docs generation |
| claudikins-klaus | NO | Final review if requested |

---

## File Structure

```
claudikins-kernel/
├── commands/
│   ├── plan.md                          # From /plan
│   ├── execute.md                       # From /execute
│   ├── verify.md                        # From /verify
│   └── ship.md                          # This command (~200 lines)
│
├── agents/
│   ├── taxonomy-extremist.md            # From /plan
│   ├── babyclaude.md                    # From /execute
│   ├── spec-reviewer.md                 # From /execute
│   ├── code-reviewer.md                 # From /execute
│   ├── catastrophiser.md                # From /verify
│   ├── cynic.md                         # From /verify
│   └── git-perfectionist.md             # GRFP docs agent (opus)
│
├── skills/
│   ├── brain-jam-plan/                  # From /plan
│   ├── git-workflow/                    # From /execute
│   ├── strict-enforcement/              # From /verify
│   └── shipping-methodology/
│       ├── SKILL.md                     # ~200 lines, GRFP pattern for shipping
│       └── references/
│           ├── commit-message-patterns.md
│           ├── grfp-checklist.md
│           ├── pr-creation-strategy.md
│           └── deployment-checklist.md
│
└── hooks/
    ├── hooks.json                       # Extended for shipping
    ├── ship-init.sh                     # SessionStart - verify gate check
    ├── capture-perfectionist.sh         # SubagentStop
    └── ship-complete.sh                 # Stop - final notifications
```

---

## The Flow

```
/ship [target]
    │
    │   Flags:
    │   --target TARGET     main|staging|release (default: main)
    │   --skip-docs         Skip git-perfectionist docs pass
    │   --fast-mode         60-second iteration cycles
    │   --session-id ID     Resume previous session
    │   --dry-run           Show what would happen
    │   --squash            Squash commits before merge
    │   --no-delete-branch  Keep feature branch after merge
    │
    ├── Phase 0: Gate Check
    │     └── Check .claude/verify-state.json exists
    │     └── Check unlock_ship == true
    │     └── If not: STOP with "Run /verify first"
    │
    ├── Phase 1: Pre-Ship Review (GRFP-style)
    │     └── Show summary of what's being shipped
    │     └── List all branches to merge
    │     └── Show verification evidence summary
    │     └── STOP: [Continue] [Back to Verify] [Abort]
    │
    ├── Phase 2: Commit Strategy (GRFP-style)
    │     └── AskUserQuestion: Squash or preserve history?
    │     └── Draft commit message(s)
    │     └── Section-by-section approval
    │     └── STOP: [Accept] [Revise] [Back]
    │
    ├── Phase 3: Documentation (GRFP via github-readme)
    │     └── Spawn git-perfectionist (context: fork, opus)
    │     └── Agent uses GRFP from claudikins-github-readme
    │     └── Updates: README, CHANGELOG, version if needed
    │     └── STOP: [Accept] [Revise] [Skip]
    │
    ├── Phase 4: PR Creation (GRFP-style) (E-6 to E-8)
    │     └── Draft PR title and body
    │     └── Section-by-section approval
    │     └── Create PR via gh CLI
    │     └── External service failure handling:
    │           └── Retry logic: max 3 attempts with exponential backoff (E-6)
    │           └── On persistent failure: Save state with "pending_merge: true" (E-7)
    │           └── Offer [Manual merge] [Try again] [Save as draft PR] (E-8)
    │     └── STOP: [Merge now] [Wait for CI] [Request review]
    │
    └── Phase 5: Final Merge
          └── If CI passes and approved: merge
          └── CI failure handling:
                └── ci-status-poller.sh monitors CI status (NH-8)
                └── On CI failure: Offer [View logs] [Fix] [Skip CI]
          └── Delete feature branches (unless --no-delete-branch)
          └── STOP: [Done] [Celebrate]
```

---

## Component Specifications

### 1. ship.md (Command)

```yaml
---
name: ship
description: Ship verified code to production. Gate-checked, GRFP-style iterative flow.
argument-hint: [--target TARGET] [--skip-docs] [--squash] [--dry-run]
model: opus
color: red
status: stable
version: "1.0.0"
merge_strategy: jq
# === Flags (I-1 to I-4) ===
flags:
  --target: main|staging|release (default: main)
  --skip-docs: Skip git-perfectionist docs pass
  --squash: Squash commits before merge
  --no-delete-branch: Keep feature branch after merge
  --dry-run: Show what would happen
  --fast-mode: 60-second iteration cycles (I-1)
  --session-id: Resume previous session by ID (I-2)
  --timing: Show phase durations for velocity tracking (I-3)
  --list-sessions: Show available sessions for resume (I-4)
agent_outputs:
  - agent: git-perfectionist
    capture_to: .claude/agent-outputs/docs/
    merge_strategy: concat
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
  - Task
  - AskUserQuestion
  - TodoWrite
---
```

**Key behaviours:**
- Gate check: requires /verify to have passed
- GRFP-style iterative approval at each stage
- Spawns git-perfectionist for docs (uses github-readme plugin)
- Human checkpoint before final merge
- Cleanup: delete branches, notify

---

### 2. git-perfectionist.md (Agent)

```yaml
---
name: git-perfectionist
description: |
  Documentation perfectionist for shipping. Uses GRFP from github-readme plugin
  to update README, CHANGELOG, version. Run during /ship Phase 3.
model: opus
color: red
context: fork
status: stable
background: false
tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
  - mcp__tool-executor__search_tools
  - mcp__tool-executor__get_tool_schema
  - mcp__tool-executor__execute_code
disallowedTools:
  - Task
---

You update documentation for shipping using GRFP methodology.

## Your Role

You're the documentation stage of /ship. You use the GRFP workflow from
claudikins-github-readme to ensure docs are ship-ready.

## GRFP Integration

Invoke the GRFP skill from github-readme plugin:
1. Analyse what changed (from execute-state.json)
2. Run GRFP deep-dive on documentation gaps
3. Run GRFP pen-wielding for updates
4. Section-by-section human approval

## What You Update

### README.md
- Features section if new features added
- Usage examples if API changed
- Installation if dependencies changed
- Remove outdated information

### CHANGELOG.md
- Add entry for this release
- Follow Keep a Changelog format
- Reference PR/issue numbers

### Version (if applicable)
- package.json version bump
- Cargo.toml version bump
- pyproject.toml version bump

## Output Format

```json
{
  "docs_updated": [
    { "file": "README.md", "sections": ["Features", "Usage"], "changes": "Added auth docs" },
    { "file": "CHANGELOG.md", "sections": ["Unreleased"], "changes": "Added v1.2.0 entry" }
  ],
  "version_bumped": {
    "from": "1.1.0",
    "to": "1.2.0",
    "type": "minor"
  },
  "grfp_phases_completed": ["deep-dive", "pen-wielding"]
}
```

<example>
Context: New feature has been verified and ready to ship
user: "Update the docs for shipping"
assistant: "I'll spawn git-perfectionist to update README and CHANGELOG using GRFP methodology"
<commentary>
Documentation pass before shipping. git-perfectionist uses the GRFP workflow from github-readme plugin for thorough, iterative docs updates.
</commentary>
</example>

<example>
Context: Bug fix ready to ship, minimal doc changes needed
user: "Quick ship, just update the changelog"
assistant: "Spawning git-perfectionist for changelog-only update"
<commentary>
Even for small changes, git-perfectionist ensures consistent changelog format.
</commentary>
</example>
```

---

### 3. shipping-methodology/SKILL.md

```yaml
---
name: shipping-methodology
description: |
  GRFP-style methodology for shipping code. Use when running /ship, preparing PRs,
  writing changelogs, or deciding release strategy. Iterative, section-by-section approval.
version: "1.0.0"
status: stable
triggers:
  keywords:
    - "ship"
    - "release"
    - "deploy"
    - "merge"
    - "PR"
    - "changelog"
---

# Shipping Methodology

## Core Principle

> "Ship with confidence, not hope."

Apply GRFP-style iterative workflow to every shipping stage.

## The GRFP Pattern for Shipping

GRFP = iterative, section-by-section, human-checkpoints

Apply to each shipping stage:

### Stage 1: Pre-Ship Review
- Show what's being shipped
- Verify evidence from /verify
- Human confirms ready
- **Checkpoint:** [Continue] [Back] [Abort]

### Stage 2: Commit Strategy
- Draft commit message(s)
- Show diff summary
- Human approves message
- **Checkpoint:** [Accept] [Revise]

### Stage 3: Documentation (via GRFP plugin)
- git-perfectionist uses github-readme GRFP
- README, CHANGELOG, version updates
- Section-by-section approval
- **Checkpoint:** [Accept] [Revise] [Skip]

### Stage 4: PR Creation
- Draft PR title
- Draft PR body section-by-section
- Human approves each section
- **Checkpoint:** [Create] [Revise]

### Stage 5: Merge Decision
- CI status check
- Final human approval
- Merge and cleanup
- **Checkpoint:** [Merge] [Wait] [Cancel]

## Commit Message Patterns

### Feature
```
feat(scope): Short description

- Bullet point of what changed
- Another change

Closes #123
```

### Fix
```
fix(scope): Short description

Root cause: What was wrong
Fix: What we did

Fixes #456
```

### Breaking Change
```
feat(scope)!: Short description

BREAKING CHANGE: What breaks and migration path

- Change 1
- Change 2
```

## References

See references/ for:
- commit-message-patterns.md - Full commit message guide
- grfp-checklist.md - GRFP integration checklist
- pr-creation-strategy.md - PR body templates
- deployment-checklist.md - Pre-deploy checks
- gate-failure-recovery.md (S-19) - Recovering from gate check failures
- ci-failure-handling.md (S-20) - Handling CI pipeline failures
- message-generation-fallback.md (S-21) - When commit message generation fails
- changelog-merge-strategy.md (S-22) - Merging CHANGELOG entries
- force-push-protection.md (S-23) - Preventing accidental force pushes
- breaking-change-detection.md (S-24) - Detecting breaking changes
```

---

### 4. hooks/hooks.json (Ship Section)

```json
{
  "hooks": {
    "SessionStart": [
      {
        "sequence": 1,
        "matcher": "/ship",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/ship-init.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
      {
        "sequence": 1,
        "matcher": "git-perfectionist",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/capture-perfectionist.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "sequence": 1,
        "matcher": "/ship",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/ship-complete.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Gate Check Pattern (CRITICAL)

The ship-init.sh hook enforces the /verify gate with **code integrity validation**:

```bash
#!/bin/bash
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
VERIFY_STATE="$PROJECT_DIR/.claude/verify-state.json"
MANIFEST_FILE="$PROJECT_DIR/.claude/verify-manifest.txt"

# === Dependency Check (H-3) ===
for cmd in jq git sha256sum; do
  if ! command -v "$cmd" &> /dev/null; then
    echo "ERROR: $cmd not installed" >&2
    exit 127
  fi
done

# === Error handling (H-1) ===
trap 'echo "Hook crashed: $?" >&2; exit 1' ERR

# === ENV validation (H-2) ===
if [ "$PROJECT_DIR" = "." ]; then
  echo "WARNING: Using current directory (CLAUDE_PROJECT_DIR unset)" >&2
fi

# === File Locking (C-8) ===
LOCK_FILE="$VERIFY_STATE.lock"
exec 200>"$LOCK_FILE"
flock -x 200
trap 'flock -u 200; rm -f "$LOCK_FILE"' EXIT

# === State File Corruption Check (H-4) ===
if [ -f "$VERIFY_STATE" ] && ! jq empty "$VERIFY_STATE" 2>/dev/null; then
  echo "ERROR: verify-state.json corrupted. Re-run /verify" >&2
  exit 2
fi

# Check verification was run
if [ ! -f "$VERIFY_STATE" ]; then
  echo "ERROR: /verify has not been run" >&2
  echo "Run /verify before /ship" >&2
  exit 2
fi

# Check unlock flag
UNLOCK=$(jq -r '.unlock_ship // false' "$VERIFY_STATE")

if [ "$UNLOCK" != "true" ]; then
  echo "ERROR: /verify did not pass or was not approved" >&2
  echo "Human must approve verification before shipping" >&2
  exit 2
fi

# === Code Integrity Check: Commit Hash (C-5) ===
VERIFY_COMMIT=$(jq -r '.verified_commit_sha // ""' "$VERIFY_STATE")
CURRENT_COMMIT=$(git rev-parse HEAD)
if [ -n "$VERIFY_COMMIT" ] && [ "$VERIFY_COMMIT" != "$CURRENT_COMMIT" ]; then
  echo "WARNING: Code changed since verification" >&2
  echo "  Verified commit: $VERIFY_COMMIT" >&2
  echo "  Current commit:  $CURRENT_COMMIT" >&2
  echo "Re-run /verify to verify current code" >&2
  exit 2
fi

# === Code Integrity Check: File Manifest (C-7) ===
if [ -f "$MANIFEST_FILE" ]; then
  VERIFIED_MANIFEST=$(jq -r '.verified_manifest // ""' "$VERIFY_STATE")
  CURRENT_MANIFEST=$(sha256sum "$MANIFEST_FILE" | cut -d' ' -f1)
  if [ -n "$VERIFIED_MANIFEST" ] && [ "$VERIFIED_MANIFEST" != "$CURRENT_MANIFEST" ]; then
    echo "ERROR: Source files changed after verification" >&2
    echo "  Verified manifest: $VERIFIED_MANIFEST" >&2
    echo "  Current manifest:  $CURRENT_MANIFEST" >&2
    echo "Re-run /verify before shipping" >&2
    exit 2
  fi
fi

echo "Gate check passed. Proceeding with /ship."
exit 0
```

This ensures /ship cannot run until /verify completes with human approval, AND validates that code hasn't changed since verification.

---

## State Tracking

### ship-state.json

```json
{
  "session_id": "ship-2026-01-16-1130",
  "verify_session_id": "verify-2026-01-16-1100",
  "started_at": "2026-01-16T11:30:00Z",
  "target": "main",
  "branches_to_merge": [
    "execute/task-1-auth-middleware",
    "execute/task-2-user-routes"
  ],
  "phases": {
    "pre_ship_review": {
      "status": "APPROVED",
      "approved_at": "2026-01-16T11:32:00Z"
    },
    "commit_strategy": {
      "status": "APPROVED",
      "strategy": "squash",
      "message": "feat(auth): Add authentication middleware\n\n..."
    },
    "documentation": {
      "status": "APPROVED",
      "agent": "git-perfectionist",
      "files_updated": ["README.md", "CHANGELOG.md"],
      "version_bumped": "1.1.0 -> 1.2.0"
    },
    "pr_creation": {
      "status": "CREATED",
      "pr_number": 42,
      "pr_url": "https://github.com/owner/repo/pull/42"
    },
    "merge": {
      "status": "MERGED",
      "merged_at": "2026-01-16T11:45:00Z",
      "sha": "abc123"
    }
  },
  "cleanup": {
    "branches_deleted": [
      "execute/task-1-auth-middleware",
      "execute/task-2-user-routes"
    ]
  },
  "shipped_at": "2026-01-16T11:46:00Z"
}
```

---

## Plugin Integrations

| Plugin | Role | Integration Point |
|--------|------|-------------------|
| **tool-executor** | MCP access | gh CLI, git operations |
| **ACM** | Context monitoring | Checkpoint if approaching 60% |
| **github-readme** | GRFP for docs | git-perfectionist uses GRFP skills |
| **Klaus** | Final review | Optional pre-merge review |

---

## GRFP Integration Detail

git-perfectionist invokes github-readme plugin's GRFP workflow:

```
git-perfectionist spawns
    │
    ├── Reads execute-state.json to understand changes
    │
    ├── Invokes GRFP deep-dive (github-readme)
    │     └── Analyses current docs
    │     └── Identifies gaps
    │
    ├── Invokes GRFP pen-wielding (github-readme)
    │     └── Writes README updates
    │     └── Writes CHANGELOG entry
    │     └── Section-by-section approval
    │
    └── Returns summary to /ship command
```

---

## The Complete 4-Command Workflow

```
/plan [brief]
  └─ Iterative planning with human checkpoints
  └─ Output: plan.md with task table
      ↓
/execute [plan.md]
  └─ Subagent per task, git branches
  └─ Two-stage review (spec + quality)
  └─ Output: implemented code on branches
      ↓
/verify
  └─ Tests, lint, type-check
  └─ catastrophiser SEES code working
  └─ Output: verify-state.json (unlock_ship: true)
      ↓
/ship
  └─ Pre-ship gate enforces /verify
  └─ GRFP for documentation
  └─ Commit, PR, merge
  └─ Output: Production code on main
```

**Zero flags needed. Just follow the suggestions.**

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Agents | 1 (git-perfectionist) |
| Human checkpoints | 5 (each stage) |
| Gate enforcement | Exit code 2 blocks without /verify |
| GRFP integration | Uses github-readme plugin |
| Cleanup | Branches deleted after merge |

---

## What We're NOT Building

| Killed | Why |
|--------|-----|
| pipeline-purist agent | Merged into command logic (CI checks) |
| no-commitment-issues agent | Merged into command logic (commit strategy) |
| Auto-merge on CI pass | Human must approve final merge |
| Complex deployment | Out of scope - just merge to target |
| Multiple targets | One target per /ship invocation |

---

## Next Step Suggestion

At the end of `/ship`, Claude says:

```
Done! Shipped to main.

PR #42 merged ✓
Branches cleaned up ✓
Version: 1.1.0 → 1.2.0

🎉 Nice work!
```

---

## Build Checklist

- [ ] Create shipping-methodology/SKILL.md
- [ ] Create shipping-methodology/references/*.md (4 files)
- [ ] Create git-perfectionist.md agent
- [ ] Update hooks.json with ship hooks
- [ ] Create ship-init.sh hook (gate check)
- [ ] Create capture-perfectionist.sh hook
- [ ] Create ship-complete.sh hook
- [ ] Create ship.md command
- [ ] Test gate check (must fail without /verify)
- [ ] Test GRFP integration with github-readme
- [ ] Test with real shipping task
