# Complete Additions List

**Date:** 2026-01-15
**Source:** 8 Claudikins Gurus (Opus 4.5)
**Status:** Ready for implementation

This document captures ALL missing features identified by the gurus that should be added to claudikins-kernel.

---

## Philosophy Additions

### All Opus, All The Time
Every agent uses `model: opus`. No compromises on quality.

### Tool-Executor Integration is Mandatory
Claude doesn't magically find tools. The protocol is:
1. `search_tools` - Find relevant MCP tools
2. `get_tool_schema` - Understand the tool
3. `execute_code` - Use the tool

Without this, 96 MCP tools are invisible.

---

## Commands to Add

### 1. /commit-push-pr (P0 - Boris's Most Used)

```yaml
---
name: commit-push-pr
description: Commit, push, and create PR in one command. Boris uses this dozens of times daily.
argument-hint: [commit message]
allowed-tools:
  - Bash
  - Read
  - Grep
---

# Fast Shipping Workflow

1. Stage all changes: `git add .`
2. Create commit with message (or generate from diff)
3. Push to remote with `-u` if needed
4. Create PR via `gh pr create` with:
   - Summary (1-3 bullet points)
   - Test plan checklist
   - Claude Code attribution

If on main/master, create feature branch first.
```

### 2. /learn (P1 - Capture Learnings)

```yaml
---
name: learn
description: Capture a learning to CLAUDE.md when Claude does something wrong
argument-hint: [what went wrong]
allowed-tools:
  - Read
  - Edit
---

# Learning Capture

Append to CLAUDE.md Learnings section:

### [DATE] - [Title derived from input]
**What happened**: [User's description]
**Why it was wrong**: [Analysis]
**Rule**: [Preventive rule]
```

### 3. /finish (P1 - Branch Completion)

```yaml
---
name: finish
description: Complete a development branch - merge, PR, or cleanup
allowed-tools:
  - Bash
  - Read
  - AskUserQuestion
---

# Branch Completion Workflow

1. Verify tests pass (MUST before proceeding)
2. Determine base branch
3. Present exactly 4 options via AskUserQuestion:
   - Merge locally (squash to main)
   - Create PR (push and open)
   - Keep as-is (leave branch)
   - Discard (delete branch)
4. Execute choice
5. Cleanup worktree if applicable
```

### 4. /verify (P1 - On-Demand Verification)

```yaml
---
name: verify
description: Run verification checks on current work
argument-hint: [optional: specific check]
allowed-tools:
  - Bash
  - Read
  - Grep
  - Task
---

# Verification Protocol

Run project-appropriate checks:
- If package.json: npm test, npm run lint, npm run typecheck
- If Cargo.toml: cargo test, cargo clippy
- If pyproject.toml: pytest, ruff check

Report results with pass/fail status.
Optionally invoke catastrophiser agent for visual verification.
```

### 5. /worktree (P2 - Parallel Setup)

```yaml
---
name: worktree
description: Setup git worktree for parallel execution
argument-hint: [branch-name]
allowed-tools:
  - Bash
---

# Worktree Setup

1. Check .worktrees/ exists (create if not, add to .gitignore)
2. Create worktree: `git worktree add .worktrees/$BRANCH $BRANCH`
3. Run project setup in worktree (npm install, etc.)
4. Report path for use
```

---

## Agents to Add

### 1. catastrophiser (P0 - See Code Output)

```yaml
---
name: catastrophiser
description: Verify application output visually and functionally. The most important agent - gives Claude feedback on its work.
model: opus
color: purple
context: fork
tools:
  - Bash
  - Read
  - WebFetch
  - Grep
---

You verify that code WORKS by SEEING its output.

## Verification Methods

### Web Applications
- Screenshot using browser tools
- Check console for errors
- Verify expected elements render

### APIs
- curl endpoints
- Verify response shape and status
- Check error handling

### CLI Tools
- Run the command
- Capture stdout/stderr
- Verify expected output

### Services
- Check logs
- Verify startup
- Test health endpoints

## Output Format

VERIFIED: [what was checked]
STATUS: PASS | FAIL
EVIDENCE: [screenshot path / response / output]
ISSUES: [any problems found]
```

### 2. cynic (P1 - Post-Implementation Polish)

```yaml
---
name: cynic
description: Refactor code for simplicity without changing behaviour. Run after implementation passes review.
model: opus
color: orange
context: fork
tools:
  - Read
  - Edit
  - Grep
  - Bash
---

You simplify code. This is a POLISH pass, not a rewrite.

## Rules

1. **Preserve exact behaviour** - Tests must still pass
2. **Remove unnecessary abstraction** - If it's only used once, inline it
3. **Prefer fewer files** - Consolidate where sensible
4. **Avoid nested ternaries** - Clarity over cleverness
5. **Run tests after each change** - Verify nothing broke

## Process

1. Read the code
2. Identify simplification opportunities
3. Make ONE change at a time
4. Run tests
5. Repeat until clean

## Do NOT

- Add new features
- Change public APIs
- Refactor unrelated code
- Make "improvements" beyond simplification
```

### 3. conflict-resolver (P2 - Handle Merge Conflicts)

```yaml
---
name: conflict-resolver
description: Resolve git merge conflicts intelligently
model: opus
color: red
context: fork
tools:
  - Read
  - Edit
  - Bash
  - Grep
---

You resolve merge conflicts.

## Process

1. `git status` to identify conflicted files
2. For each file:
   - Read the conflict markers
   - Understand both versions
   - Determine correct resolution
   - Edit to resolve
   - `git add` the file
3. Verify build/tests pass
4. Report resolution summary

## Resolution Strategies

- **Ours**: Keep current branch version
- **Theirs**: Keep incoming version
- **Merge**: Combine both changes
- **Rewrite**: Neither version is correct, write new

## Output

RESOLVED: [file list]
STRATEGY: [what was done per file]
VERIFICATION: [test results]
```

---

## Skills to Add

### 1. strict-enforcement/SKILL.md

```yaml
---
name: strict-enforcement
description: How to verify code works. Use when setting up verification, checking work, or debugging failures.
---

# Strict Enforcement

## Core Principle

> "Give Claude a tool to see the output of its code. If Claude has that feedback loop, it will 2-3x the quality." - Boris

## Project-Specific Verification

| Project Type | Verification Tools |
|--------------|-------------------|
| Web app | Browser screenshot, console logs, network tab |
| API | curl, Postman, integration tests |
| CLI | Run command, capture output |
| Library | Unit tests, example usage |
| Service | Health check, logs, metrics |

## Verification Checklist

- [ ] Code compiles/transpiles without errors
- [ ] Linter passes
- [ ] Type checker passes
- [ ] Unit tests pass
- [ ] Integration tests pass (if applicable)
- [ ] Manual verification of primary use case
- [ ] Edge cases checked

## When to Verify

1. After implementing a feature
2. Before committing
3. Before marking task complete
4. After resolving conflicts
5. Before creating PR

## Verification Tools by Stack

### Node.js/TypeScript
- `npm test` / `npm run test`
- `npm run lint`
- `npm run typecheck` / `tsc --noEmit`
- `npm run build`

### Python
- `pytest`
- `ruff check`
- `mypy`

### Rust
- `cargo test`
- `cargo clippy`
- `cargo build`

### Go
- `go test ./...`
- `go vet ./...`
- `go build`
```

### 2. escalation-patterns/SKILL.md

```yaml
---
name: escalation-patterns
description: When and how to escalate issues. Use when stuck, uncertain, or facing complex decisions.
---

# Escalation Patterns

## When to Escalate

### Escalate to Human
- Requirements are ambiguous
- Multiple valid approaches exist
- Security implications
- Breaking changes to public API
- Decisions that can't be undone

### Escalate to Klaus
- Been stuck for 2+ retry cycles
- Need devil's advocate review
- Want opinionated feedback
- Plan seems too simple/complex

### Escalate to catastrophiser
- Need to see code running
- Visual verification required
- Integration behaviour unclear

## Stuck Detection Signals

| Signal | Threshold | Action |
|--------|-----------|--------|
| Same error 3+ times | Immediate | Try different approach |
| 10+ minutes no progress | Warning | Consider escalation |
| 20+ tool calls no output | Critical | Escalate or abandon |
| Context at 60% | Warning | Checkpoint state |

## Escalation Format

When escalating, provide:
1. What you were trying to do
2. What you tried
3. What failed
4. Your hypothesis
5. What you need

## Klaus Briefing Template

Klaus, I'm stuck on [task].

**Attempts:**
1. [First approach] - [Why it failed]
2. [Second approach] - [Why it failed]

**Current hypothesis:** [What you think is wrong]

**Question:** [Specific thing you need Klaus to weigh in on]
```

### 3. conflict-resolution/SKILL.md

```yaml
---
name: conflict-resolution
description: How to resolve git conflicts. Use when merging branches or rebasing.
---

# Conflict Resolution

## Conflict Markers

```
<<<<<<< HEAD
Current branch version
=======
Incoming branch version
>>>>>>> feature-branch
```

## Resolution Strategies

### 1. Accept Ours
Keep the current branch version. Use when:
- Incoming changes are outdated
- Current version is more correct

### 2. Accept Theirs
Keep the incoming version. Use when:
- Incoming changes are newer/better
- Current version should be replaced

### 3. Merge Both
Combine changes. Use when:
- Both changes are valid additions
- Changes are in different parts of the block

### 4. Rewrite
Neither version is correct. Use when:
- Both versions have issues
- Conflict reveals a design problem

## Process

1. `git status` - See all conflicted files
2. For each file:
   - Open and find conflict markers
   - Understand context of both versions
   - Choose resolution strategy
   - Remove conflict markers
   - `git add <file>`
3. `git status` - Verify no conflicts remain
4. Run tests - Verify nothing broke
5. Complete merge/rebase

## Common Patterns

### Package Lock Conflicts
Always regenerate: `rm package-lock.json && npm install`

### Import Conflicts
Usually merge both - both imports are likely needed

### Function Conflicts
Read both versions carefully - often one is refactored version of other
```

---

## Hooks to Add

### hooks/hooks.json (Complete)

```json
{
  "description": "Claudikins Kernel - Complete hook configuration",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-init.sh",
            "comment": "Load project context, persist env vars"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "matcher": "/plan.*(--verify|verify)",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/plan-verify.sh" }
        ]
      },
      {
        "matcher": "/execute.*(--status|status)",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/execute-status.sh" }
        ]
      },
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/phase-detector.sh" }
        ]
      }
    ],
    "SubagentStart": [
      {
        "matcher": "babyclaude",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/create-task-branch.sh" }
        ]
      },
      {
        "matcher": "taxonomy-extremist",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/inject-tool-context.sh" }
        ]
      }
    ],
    "SubagentStop": [
      {
        "matcher": "babyclaude",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/task-completion-capture.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/git-branch-guard.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/auto-format.sh" }
        ]
      },
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/execute-tracker.sh" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/notify-ready.sh" },
          {
            "type": "prompt",
            "prompt": "Evaluate: Has this agent made meaningful progress? Is it stuck? Should we escalate to Klaus?",
            "model": "opus"
          },
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/batch-checkpoint-gate.sh" }
        ]
      }
    ],
    "PermissionRequest": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/auto-approve-safe.sh" }
        ]
      }
    ],
    "PreCompact": [
      {
        "hooks": [
          { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/preserve-state.sh" }
        ]
      }
    ]
  }
}
```

### Hook Scripts to Create

#### hooks/session-init.sh

```bash
#!/bin/bash
set -euo pipefail

# Persist environment variables for entire session
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  # Detect project type
  if [ -f "$CLAUDE_PROJECT_DIR/package.json" ]; then
    echo "export PROJECT_TYPE=nodejs" >> "$CLAUDE_ENV_FILE"
  elif [ -f "$CLAUDE_PROJECT_DIR/Cargo.toml" ]; then
    echo "export PROJECT_TYPE=rust" >> "$CLAUDE_ENV_FILE"
  elif [ -f "$CLAUDE_PROJECT_DIR/pyproject.toml" ]; then
    echo "export PROJECT_TYPE=python" >> "$CLAUDE_ENV_FILE"
  elif [ -f "$CLAUDE_PROJECT_DIR/go.mod" ]; then
    echo "export PROJECT_TYPE=go" >> "$CLAUDE_ENV_FILE"
  fi

  # Set state file paths
  echo "export PLAN_STATE_FILE=$CLAUDE_PROJECT_DIR/.claude/plan-state.json" >> "$CLAUDE_ENV_FILE"
  echo "export EXECUTE_STATE_FILE=$CLAUDE_PROJECT_DIR/.claude/execute-state.json" >> "$CLAUDE_ENV_FILE"
fi

# Inject system message with project context
cat <<EOF
{
  "continue": true,
  "systemMessage": "Session initialized. Project type: ${PROJECT_TYPE:-unknown}. Tool-executor available for MCP access."
}
EOF
```

#### hooks/auto-format.sh

```bash
#!/bin/bash
set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Format based on file extension
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.md)
    if command -v prettier &> /dev/null; then
      prettier --write "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  *.py)
    if command -v ruff &> /dev/null; then
      ruff format "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  *.rs)
    if command -v rustfmt &> /dev/null; then
      rustfmt "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
  *.go)
    if command -v gofmt &> /dev/null; then
      gofmt -w "$FILE_PATH" 2>/dev/null || true
    fi
    ;;
esac

exit 0
```

#### hooks/notify-ready.sh

```bash
#!/bin/bash
set -euo pipefail

# Desktop notification when agent needs input
TITLE="Claude Code"
MESSAGE="Ready for input"

# Linux
if command -v notify-send &> /dev/null; then
  notify-send "$TITLE" "$MESSAGE" --urgency=normal &
# macOS
elif command -v osascript &> /dev/null; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" &
fi

exit 0
```

#### hooks/auto-approve-safe.sh

```bash
#!/bin/bash
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Auto-approve safe operations
APPROVE=false

case "$TOOL_NAME" in
  Read|Grep|Glob|LS)
    APPROVE=true
    ;;
  Bash)
    # Safe bash patterns
    case "$COMMAND" in
      "npm test"*|"npm run test"*|"pytest"*|"cargo test"*|"go test"*)
        APPROVE=true
        ;;
      "npm run lint"*|"npm run typecheck"*|"ruff check"*|"cargo clippy"*)
        APPROVE=true
        ;;
      "git status"*|"git diff"*|"git log"*|"git branch"*)
        APPROVE=true
        ;;
      "ls "*|"cat "*|"head "*|"tail "*)
        APPROVE=true
        ;;
    esac
    ;;
esac

if [ "$APPROVE" = true ]; then
  echo '{"hookSpecificOutput": {"permissionDecision": "allow"}}'
else
  echo '{"continue": true}'
fi
```

---

## Agent Frontmatter Patterns

### Standard Agent Template

```yaml
---
name: agent-name
description: |
  Clear description of what this agent does.
  Include triggering examples.
model: opus
color: green
context: fork
background: true
permissionMode: default
skills:
  - relevant-methodology
  - tool-executor
hooks:
  PreToolUse:
    - matcher: Bash
      command: ./validate.sh
  Stop:
    - type: prompt
      prompt: "Did you complete all acceptance criteria?"
      once: true
allowed-tools:
  - Read
  - Grep
  - Glob
  - Edit
  - Write
  - Bash
disallowedTools:
  - Task
---
```

### Agent `<example>` Blocks

Every agent should include triggering examples:

```markdown
<example>
Context: User has completed implementation and wants to verify it works
user: "Can you check if this actually works?"
assistant: "I'll use the catastrophiser agent to test the implementation"
<commentary>
User is asking for functional verification, which requires seeing the code run.
catastrophiser agent has tools to screenshot, curl, and check logs.
</commentary>
</example>

<example>
Context: Tests are passing but code feels messy
user: "The code works but it's ugly, can you clean it up?"
assistant: "I'll use the cynic agent to polish the implementation"
<commentary>
User wants refactoring without behaviour changes.
cynic preserves functionality while improving clarity.
</commentary>
</example>
```

---

## Review Patterns

### Confidence Scoring

All reviewers must use confidence scoring:

```markdown
## Scoring

Rate each issue 0-100:
- **0-50**: Low confidence - likely false positive, do not report
- **51-79**: Medium confidence - note internally, report only if pattern repeats
- **80-89**: High confidence - report as Important
- **90-100**: Very high confidence - report as Critical

**Only report issues with confidence >= 80.**

## Output Format

### Critical Issues (confidence >= 90)
- [file:line] Issue description
  Confidence: 95
  Reason: [why this is definitely a problem]
  Fix: [suggested resolution]

### Important Issues (confidence 80-89)
- [file:line] Issue description
  Confidence: 82
  Reason: [why this is likely a problem]
  Fix: [suggested resolution]

### Strengths
- [What's done well]
```

### File Return Lists

Explorer agents must return prioritised file lists:

```markdown
## Output Requirements

Include a list of 5-10 key files to read:

### Essential Files (must read)
1. `/path/to/core-file.ts` - [why it's essential]
2. `/path/to/related.ts` - [why it's essential]

### Supporting Files (helpful context)
3. `/path/to/types.ts` - [what it provides]
4. `/path/to/utils.ts` - [what it provides]

### Tests (for understanding behaviour)
5. `/path/to/test.ts` - [what it tests]
```

---

## Infrastructure to Add

### templates/settings.json

```json
{
  "permissions": {
    "allow": [
      "Read",
      "Grep",
      "Glob",
      "LS",
      "Bash(npm test*)",
      "Bash(npm run test*)",
      "Bash(npm run lint*)",
      "Bash(npm run build*)",
      "Bash(git status*)",
      "Bash(git diff*)",
      "Bash(git log*)",
      "Bash(git add*)",
      "Bash(git commit*)",
      "mcp__tool-executor__*"
    ],
    "deny": [
      "Bash(rm -rf*)",
      "Bash(git push --force*)",
      "Bash(git reset --hard*)"
    ]
  }
}
```

### .claude/rules/ Structure

```
.claude/rules/
├── planning.md           # Planning phase rules
├── execution.md          # Execution phase rules
├── verification.md       # Verification requirements
├── git-workflow.md       # Branch/commit conventions
└── tool-usage.md         # MCP tool protocol
```

---

## State File Patterns

### .claude/plan-state.json

```json
{
  "session_id": "plan-feature-x",
  "started_at": "2026-01-15T10:00:00Z",
  "current_phase": 2,
  "phase_name": "research",
  "completed_phases": ["brainjam"],
  "phase_approved": false,
  "artifacts": {
    "requirements": ".claude/cache/requirements.md",
    "research": ".claude/cache/research.md"
  },
  "context_percentage": 35
}
```

### .claude/execute-state.json

```json
{
  "plan_source": "docs/plans/feature-x.md",
  "session_id": "execute-feature-x",
  "started_at": "2026-01-15T11:00:00Z",
  "current_batch": 1,
  "batches": [
    {
      "batch_id": 1,
      "tasks": ["task-1", "task-2"],
      "status": "in_progress",
      "human_approved": false
    }
  ],
  "tasks": {
    "task-1": {
      "title": "Create auth middleware",
      "branch": "execute/task-1-auth",
      "status": "completed",
      "agent_id": "abc123",
      "transcript_path": "~/.claude/projects/.../subagents/abc123.jsonl",
      "files_changed": ["src/middleware/auth.ts"],
      "review": {
        "confidence": 92,
        "issues": [],
        "strengths": ["Clean implementation", "Good error handling"]
      }
    }
  },
  "parallel_agents": {},
  "escalation_history": []
}
```

---

## Build Order

| Priority | Component | Files |
|----------|-----------|-------|
| P0 | Tool-executor integration | hooks/session-init.sh, hooks/inject-tool-context.sh |
| P0 | /commit-push-pr | commands/commit-push-pr.md |
| P0 | catastrophiser agent | agents/catastrophiser.md |
| P0 | Auto-format hook | hooks/auto-format.sh |
| P1 | cynic agent | agents/cynic.md |
| P1 | /learn command | commands/learn.md |
| P1 | /finish command | commands/finish.md |
| P1 | /verify command | commands/verify.md |
| P1 | Notification hook | hooks/notify-ready.sh |
| P1 | Auto-approve hook | hooks/auto-approve-safe.sh |
| P1 | strict-enforcement skill | skills/strict-enforcement/ |
| P1 | escalation-patterns skill | skills/escalation-patterns/ |
| P2 | conflict-resolver agent | agents/conflict-resolver.md |
| P2 | /worktree command | commands/worktree.md |
| P2 | conflict-resolution skill | skills/conflict-resolution/ |
| P2 | Settings template | templates/settings.json |
| P2 | Rules directory | .claude/rules/*.md |

---

## File Count Summary

| Category | Count |
|----------|-------|
| Commands | 7 (plan, execute, commit-push-pr, learn, finish, verify, worktree) |
| Agents | 6 (taxonomy-extremist, babyclaude, realist, catastrophiser, cynic, conflict-resolver) |
| Skills | 5 (brain-jam, git-workflow, strict-enforcement, escalation-patterns, conflict-resolution) |
| Hooks | 12 scripts |
| Templates | 2 |
| Rules | 5 |
| **Total** | ~40 files |

---

## Integration Points

### Tool-Executor MCP (7 Servers, 96 Tools)

| Server | Tools | Use Case |
|--------|-------|----------|
| Serena | Semantic code search | Find patterns, understand architecture |
| Context7 | Library documentation | Up-to-date API references |
| Gemini | Deep research | External knowledge, alternative perspectives |
| NotebookLM | Document analysis | Parse specs, requirements |
| Sequential Thinking | Structured reasoning | Complex decisions, trade-offs |
| shadcn | UI components | Frontend component selection |
| Apify | Web scraping | External research, competitor analysis |

### ACM (Automatic Context Manager)

- Monitor `context_window.used_percentage` via status line
- Handoff at 60% threshold
- PreCompact hook preserves state before compaction
- Named sessions enable resume after context death

### Klaus (Devil's Advocate)

- Available for plan review (Phase 5)
- Available for stuck escalation (after 2-3 retries)
- Briefing template in escalation-patterns skill
