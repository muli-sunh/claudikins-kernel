# MARKETPLACE INTEGRATION - FINAL CONSENSUS

**Date:** 2026-01-15
**Panel:** 8 Claudikins Gurus (Opus 4.5) - 5 Rounds Complete
**Status:** FINAL CONSENSUS - Ready for Implementation
**Scope:** How 5 marketplace plugins integrate with claudikins-kernel

---

## REPOS INTEGRATED

| # | Repository | Purpose | Priority |
|---|------------|---------|----------|
| 1 | claudikins-kernel | Core framework (4 commands) | P0 |
| 2 | claudikins-tool-executor | MCP tool discovery (96 tools) | P0 |
| 3 | claudikins-automatic-context-manager | Context monitoring (60% threshold) | P1 |
| 4 | claudikins-klaus | Devil's advocate escalation | P2 |
| 5 | claudikins-marketplace | Plugin registry | P2 |
| 6 | claudikins-github-readme | README generation (GRFP) | P2 |

---

## CONSENSUS POINTS (12 UNANIMOUS)

### Architecture (5 points)

**1. brain-jam stays in kernel (unanimous)**
- Foundational planning skill, referenced by all commands
- github-readme renames theirs to `github-readme-planning-checklist`
- Marketplace skills reference kernel skills via `requires` field

**2. Klaus as separate plugin (claudikins-klaus)**
- NOT in kernel - proves marketplace architecture works
- Depends on: kernel + tool-executor (clean bottom-up dependency)
- Install pattern: `kernel first → tool-executor → Klaus`

**3. Hook sequencing via `sequence` field**
```json
{
  "hooks": {
    "SessionStart": [
      { "sequence": 1, "command": "kernel-session-init.sh" },
      { "sequence": 2, "command": "tool-executor-init.sh" },
      { "sequence": 3, "command": "acm-init.sh" }
    ]
  }
}
```
- Integer ordering within same event type
- Cross-event ordering is implicit (SessionStart before SubagentStart)

**4. State architecture: shared + plugin-state**
```
.claude/
├── shared/              # All plugins read, commands write
│   ├── plan-state/
│   ├── execute-state/
│   ├── verify-state/
│   └── ship-state/
└── plugin-state/        # Each plugin owns its subdirectory
    ├── claudikins-kernel/
    ├── claudikins-tool-executor/
    └── claudikins-klaus/
```
- Plugins read `.claude/shared/`, write to `.claude/plugin-state/{plugin}/`
- Commands own merge logic (GOSPEL pattern)
- SubagentStop hooks are passive collectors

**5. Exit code 2 validation required (P0 BLOCKER)**
- Must test before implementing gate hooks
- Exit 2 = blocks tool use, feeds stderr to Claude
- If not verified, entire verification model fails

### Patterns (4 points)

**6. `agent_outputs` in command frontmatter**
```yaml
agent_outputs:
  - agent: taxonomy-extremist
    capture_to: .claude/agent-outputs/research
    merge_strategy: jq -s 'add'
```
- Commands declare what agents deliver
- JSON schema enforces structure
- Commands own merge logic (not hooks)

**7. `--fast` flag opt-in, not default**
- Verification is cheap relative to rework cost
- Power users can skip phases explicitly
- Default: all verification phases ON

**8. Cross-plugin activation via `requires` + `triggers`**
```yaml
requires:
  - skill: brain-jam
    version: "^1.0"
  - plugin: tool-executor
    version: "^2.0"
triggers:
  keywords:
    - "brainstorm"
    - "planning"
```
- No auto-resolution - explicit version constraints or fail
- First-installed wins + manifest.json tracks versions

**9. Model inheritance: NO - always explicit**
- Every agent declares model: opus/sonnet/haiku
- No fallback to command model
- Prevents accidental haiku for judgment calls

### Documentation (3 points)

**10. Installation order matters**
```
1. claudikins-kernel (CORE)
2. claudikins-tool-executor (DEPENDENCY)
3. claudikins-automatic-context-manager (OPTIONAL)
4. claudikins-klaus (OPTIONAL)
5. Custom plugins (LAST)
```

**11. ~8.5 hours documentation work needed**
- STATE-MERGE-ARCHITECTURE.md (1h)
- HOOK-LIFECYCLE-REFERENCE.md (1.5h)
- PLUGIN-LOADING-SPEC.md (2h)
- TESTING-GUIDE.md (2.5h)
- FAST-MODE-SPEC.md (45m)
- Klaus plugin spec (1h)

**12. 5 validation tests before P0 implementation**
1. Sequence field ordering (30 min)
2. Exit code 2 blocks tool use (20 min)
3. SubagentStop writes to file (20 min)
4. jq merge works (15 min)
5. context: fork isolation (30 min)

---

## MARKETPLACE P0 BUILD ORDER

**Phase 1: Manifest & Metadata (1-2 hours)**
| # | File | Purpose |
|---|------|---------|
| 1 | .claude/MANIFEST.md | Declares claudikins-kernel structure |
| 2 | plugin.json v2 | Name, version, dependencies, keywords |
| 3 | .claude/settings.json template | Pre-allowed permissions |

**Phase 2: Installation Protocol (2-3 hours)**
| # | File | Purpose |
|---|------|---------|
| 4 | SessionStart:marketplace-init.sh | Detects missing deps |
| 5 | dependencies.json | tool-executor, ACM, optional Klaus |

**Phase 3: Conflict Resolution (2-3 hours)**
| # | File | Purpose |
|---|------|---------|
| 6 | hooks/marketplace-version-gate.sh | Exit 2 on mismatch |
| 7 | .claude/conflict-resolution/version-matrix.json | Compatibility rules |

**Phase 4: Activation Protocol (2-3 hours)**
| # | File | Purpose |
|---|------|---------|
| 8 | hooks.json marketplace section | PermissionRequest for activation |
| 9 | .claude/activation.sh | requires/triggers handshake |
| 10 | README.md "Getting Started" | Install → activate → /plan |

**Total: ~8-10 hours, 10 files**

---

## RENAMED COMPONENTS

| Old Name | New Name | Reason |
|----------|----------|--------|
| github-readme/brain-jam | github-readme-planning-checklist | Kernel owns brain-jam |

---

## BORIS'S PATTERNS APPLIED

| Pattern | Implementation |
|---------|----------------|
| Notifications > Auto-action | PermissionRequest hook blocks until user approves |
| State external > State internal | All state in `.claude/` files, not context |
| Evidence first > Assertions | marketplace-verify.sh shows evidence before proceeding |
| Modular > Monolithic | Klaus as separate plugin, not embedded |
| Exit codes are gates | Exit 2 for version conflicts, user sees stderr |

---

## WHAT WE'RE NOT BUILDING

| Killed | Why |
|--------|-----|
| Auto-install marketplace plugins | Humans decide, notifications prompt |
| Framework for marketplace | Specific agents that USE marketplace |
| brain-jam in github-readme | Duplicate; reference kernel instead |
| --fast as default | Verification is cheap vs rework |
| Klaus in kernel | Separate plugin proves architecture |

---

## KEY TECHNICAL RULES

### Rule 1: Installation Order
kernel → tool-executor → ACM → Klaus → custom

### Rule 2: State Isolation
- Plugins read `.claude/shared/`
- Plugins write to `.claude/plugin-state/{plugin}/`
- Commands own merge logic

### Rule 3: Exit Code 2 Gates
```bash
if [ version_mismatch ]; then
  echo "Conflict: $details" >&2
  exit 2  # Blocks, shows error to Claude
fi
```

### Rule 4: Explicit Dependencies
```yaml
requires:
  - plugin: claudikins-kernel
    version: ">=1.0.0"
  - plugin: tool-executor
    version: ">=2.0.0"
```

### Rule 5: Sequence Within Events
```json
{ "sequence": 1, "command": "first.sh" }
{ "sequence": 2, "command": "second.sh" }
```
Integer ordering. Lower runs first.

---

## NEXT STEPS (IMMEDIATE)

**Pre-P0 Validation (2 hours):**
1. Test sequence field ordering
2. Test exit code 2 behaviour
3. Test SubagentStop file writing
4. Test jq merge
5. Test context: fork isolation

**Marketplace P0 (8-10 hours):**
1. Create MANIFEST.md
2. Create plugin.json v2
3. Create settings.json template
4. Create marketplace-init.sh hook
5. Create dependencies.json
6. Create marketplace-version-gate.sh
7. Create version-matrix.json
8. Add marketplace section to hooks.json
9. Create activation.sh
10. Update README.md

---

## PANEL SIGN-OFF

| Guru | Status | Key Contribution |
|------|--------|------------------|
| boris-guru | NO OBJECTIONS | Build order, patterns, notifications |
| hooks-guru | ACCEPTED | sequence field, state architecture |
| agents-guru | ACCEPTED | Klaus as separate plugin, frontmatter |
| commands-guru | ACCEPTED | agent_outputs, --fast opt-in |
| skills-guru | ACCEPTED | brain-jam ownership, rename |
| claude-code-guru | CONDITIONAL | 5 validation tests required |
| docs-guru | ACCEPTED | 8.5h docs needed, blocking list |

**Document Created:** 2026-01-15
**Status:** READY FOR IMPLEMENTATION

---

## COMPARISON TO KERNEL CONSENSUS

| Aspect | Kernel | Marketplace |
|--------|--------|-------------|
| Files | 41 | 10 |
| Time | Week 1-4 | Week 1-2 |
| Commands | 4 (/plan, /execute, /verify, /ship) | 0 (hooks only) |
| Agents | 8 | 0 (Klaus is separate plugin) |
| Skills | 5 | 0 (reference kernel skills) |
| Hooks | 13 scripts | 4 scripts |
| Priority | P0 foundation | P0 parallel |

**Build kernel + marketplace in parallel. Both are P0.**
