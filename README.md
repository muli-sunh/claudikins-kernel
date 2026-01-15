# Claudikins Kernel

Core planning and workflow infrastructure for the Claudikins ecosystem.

## Philosophy

> "Planning is a conversation, not a production line." — 8 Gurus

This plugin provides iterative planning with human checkpoints, following patterns proven by Boris (50-100 PRs/week) and official Claude Code plugins.

## Features

- **`/plan`** - Iterative planning with 4 human checkpoints
- **ACM integration** - Context longevity for long planning sessions
- **Optional Klaus review** - Opinionated devil's advocate
- **Verification hooks** - Phase gates enforced by exit code 2

## Architecture

```
/plan [brief]
  │
  ├── Phase 1: Brain-jam → STOP (confirm)
  ├── Phase 2: Research → STOP (review findings)
  ├── Phase 3: Draft → STOP (approve sections)
  ├── Phase 4: Review → STOP (iterate or finalise)
  └── Output: Validated plan
```

## Installation

```bash
/plugin marketplace add /path/to/claudikins-kernel
```

## Optional Dependencies

| Plugin | Purpose |
|--------|---------|
| claudikins-automatic-context-manager | Context longevity |
| claudikins-tool-executor | Efficient research |
| claudikins-klaus | Opinionated review |

## Documentation

- [Audit Findings](docs/plan-audit-findings.md) - Full guru analysis
- [Implementation Checklist](docs/plan-audit-findings.md#implementation-checklist) - Build roadmap

## Status

🚧 **In Development** - Architecture validated, implementation pending.
