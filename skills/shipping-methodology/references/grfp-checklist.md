# GRFP Integration Checklist

How git-perfectionist integrates with the claudikins-github-readme GRFP workflow.

## What is GRFP?

GRFP (GitHub README Focused Pipeline) is a methodology from the github-readme plugin that provides iterative, section-by-section documentation workflows.

## GRFP Phases

| Phase | Tool | Purpose |
|-------|------|---------|
| deep-dive | Analyse existing docs | Understand current state |
| think-tank | Research patterns | Find best practices |
| brain-jam | Ideate with AI | Generate ideas |
| pen-wielding | Write content | Draft documentation |
| crystal-ball | Future-proof | Consider evolution |

## git-perfectionist Uses

For /ship documentation updates, git-perfectionist uses:

1. **deep-dive** - Analyse current README, CHANGELOG
2. **pen-wielding** - Write updates with section approval

## Pre-Flight Checklist

Before invoking GRFP:

- [ ] execute-state.json exists (know what changed)
- [ ] verify-state.json shows PASS (changes work)
- [ ] README.md exists (something to update)
- [ ] CHANGELOG.md exists or will be created

## Deep-Dive Phase

git-perfectionist reads:

```
1. execute-state.json
   └── What tasks were completed?
   └── What files were changed?

2. README.md
   └── What sections exist?
   └── What's outdated?

3. CHANGELOG.md
   └── What's the current version?
   └── What's in [Unreleased]?
```

**Output:** Gap analysis

```json
{
  "gaps": [
    { "file": "README.md", "section": "Features", "issue": "Missing auth feature" },
    { "file": "CHANGELOG.md", "section": "Unreleased", "issue": "No entry for v1.2.0" }
  ],
  "suggestions": [
    "Add authentication section to README",
    "Create v1.2.0 changelog entry"
  ]
}
```

## Pen-Wielding Phase

For each gap, git-perfectionist:

1. Drafts the content
2. Presents to human
3. Human approves or revises
4. Moves to next section

**Section-by-section flow:**

```
README.md - Features Section
----------------------------
Current:
  ## Features
  - Fast startup
  - Easy configuration

Proposed addition:
  - **Authentication** - JWT-based auth with role support

[Accept] [Revise] [Skip]
```

## CHANGELOG Update Pattern

```markdown
## [Unreleased]
(empty - all changes moved to version)

## [1.2.0] - 2026-01-17
### Added
- Authentication middleware with JWT support (#42)
- Role-based access control

### Changed
- Improved error messages for API responses

### Fixed
- Token refresh race condition (#38)
```

**Version bump decision:**

| Change Type | Version Bump |
|-------------|--------------|
| Breaking change | MAJOR (1.x.x → 2.0.0) |
| New feature | MINOR (1.1.x → 1.2.0) |
| Bug fix only | PATCH (1.1.1 → 1.1.2) |

## README Update Patterns

### New Feature Section

```markdown
## Authentication

This project includes JWT-based authentication.

### Setup

```bash
npm run setup-auth
```

### Usage

```typescript
import { authenticate } from './auth';

app.use(authenticate());
```
```

### Updated Installation

If dependencies changed:

```markdown
## Installation

```bash
npm install
```

### New Dependencies

This version adds:
- `jsonwebtoken` - JWT handling
- `bcrypt` - Password hashing
```

## Version File Updates

git-perfectionist updates version in:

| File | Field |
|------|-------|
| package.json | `version` |
| Cargo.toml | `version` in `[package]` |
| pyproject.toml | `version` in `[project]` |

**Pattern:**

```bash
# package.json
jq '.version = "1.2.0"' package.json > tmp && mv tmp package.json

# Or use npm
npm version minor --no-git-tag-version
```

## Human Approval Points

| Point | What's Shown | Options |
|-------|--------------|---------|
| Gap analysis | List of changes needed | [Continue] [Skip docs] |
| Each section | Draft content | [Accept] [Revise] [Skip] |
| Version bump | From → To | [Accept] [Different version] |
| Final review | All changes | [Commit docs] [Revise] |

## Skipping Documentation

If `--skip-docs` flag:

```
Skipping documentation updates.

Note: README and CHANGELOG will not be updated.
Consider running docs update before next release.

[Continue anyway] [Run docs update]
```

## Error Handling

### github-readme Plugin Unavailable

```
github-readme plugin not available.

Falling back to basic documentation update:
- CHANGELOG entry only
- No GRFP deep-dive

[Continue with basic] [Abort]
```

### Section Revision Loop

If human keeps revising:

```
Section revised 3 times.

[Accept current] [Skip section] [Abort docs phase]
```

Max 5 revisions per section to prevent infinite loops.

## Output Format

git-perfectionist returns:

```json
{
  "docs_updated": [
    {
      "file": "README.md",
      "sections": ["Features", "Installation"],
      "changes": "Added auth docs, updated deps"
    },
    {
      "file": "CHANGELOG.md",
      "sections": ["1.2.0"],
      "changes": "Added version entry"
    }
  ],
  "version_bumped": {
    "from": "1.1.0",
    "to": "1.2.0",
    "type": "minor",
    "files": ["package.json"]
  },
  "grfp_phases_completed": ["deep-dive", "pen-wielding"],
  "skipped_sections": []
}
```
