# Changelog Merge Strategy (S-22)

Handling CHANGELOG.md updates and merge conflicts.

## Keep a Changelog Format

We follow [Keep a Changelog](https://keepachangelog.com/):

```markdown
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

## [1.2.0] - 2026-01-17
### Added
- New feature X

### Changed
- Modified behaviour Y

### Deprecated
- Old feature Z

### Removed
- Deleted feature W

### Fixed
- Bug fix V

### Security
- Security patch U
```

## Section Order

Sections should appear in this order:

1. Added
2. Changed
3. Deprecated
4. Removed
5. Fixed
6. Security

## Entry Format

Each entry should:

```markdown
### Added
- Brief description of feature (#123)
- Another feature with link to PR (#124)
```

**Include:**
- Clear, user-facing description
- Issue/PR reference in parentheses
- No code details (save for commit messages)

**Don't include:**
- Internal refactoring (unless user-impacting)
- Test additions (unless notable)
- Dependency updates (unless security-related)

## Unreleased Section

Work-in-progress changes go in `[Unreleased]`:

```markdown
## [Unreleased]
### Added
- Authentication middleware (#42)
- Session management (#43)

### Fixed
- Token refresh race condition (#38)
```

When releasing, move to versioned section:

```markdown
## [Unreleased]
(empty)

## [1.2.0] - 2026-01-17
### Added
- Authentication middleware (#42)
- Session management (#43)

### Fixed
- Token refresh race condition (#38)
```

## Version Bump Strategy

| Changes | Bump | Example |
|---------|------|---------|
| Breaking changes | MAJOR | 1.x.x → 2.0.0 |
| New features | MINOR | 1.1.x → 1.2.0 |
| Bug fixes only | PATCH | 1.1.1 → 1.1.2 |

## Merge Conflicts in CHANGELOG

CHANGELOG conflicts are common when multiple PRs add entries.

### Typical Conflict

```markdown
<<<<<<< HEAD
## [Unreleased]
### Added
- Feature A (#100)
=======
## [Unreleased]
### Added
- Feature B (#101)
>>>>>>> feature-branch
```

### Resolution Strategy

**Keep both entries:**

```markdown
## [Unreleased]
### Added
- Feature A (#100)
- Feature B (#101)
```

### Automated Resolution

```bash
# Detect changelog conflict
if git diff --name-only --diff-filter=U | grep -q "CHANGELOG.md"; then
  echo "CHANGELOG conflict detected"

  # Extract both versions
  git show :2:CHANGELOG.md > changelog-ours.md
  git show :3:CHANGELOG.md > changelog-theirs.md

  # Merge entries (custom script)
  merge-changelog changelog-ours.md changelog-theirs.md > CHANGELOG.md

  git add CHANGELOG.md
fi
```

### Manual Resolution Flow

```
CHANGELOG.md has merge conflict.

Ours (main):
### Added
- Feature A (#100)

Theirs (feature-branch):
### Added
- Feature B (#101)

[Keep both] [Keep ours] [Keep theirs] [Edit manually]
```

## Entry Deduplication

If same entry appears in both:

```markdown
<<<<<<< HEAD
### Fixed
- Token refresh bug (#38)
=======
### Fixed
- Token refresh race condition (#38)
>>>>>>> feature-branch
```

**Resolution:**
```
Duplicate entry detected:

Ours: "Token refresh bug (#38)"
Theirs: "Token refresh race condition (#38)"

Both reference #38. Keep which?

[Ours] [Theirs] [Merge descriptions]
```

**Merged:**
```markdown
### Fixed
- Token refresh race condition (#38)
```

## Section Ordering After Merge

After merging entries, ensure correct section order:

```markdown
# Wrong order
### Fixed
- Bug fix

### Added
- New feature

# Correct order
### Added
- New feature

### Fixed
- Bug fix
```

## Date Handling

When creating version:

```markdown
## [1.2.0] - 2026-01-17
```

**Use today's date** for the release, not the date changes were made.

## Link Generation

At bottom of CHANGELOG, add comparison links:

```markdown
[Unreleased]: https://github.com/owner/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/owner/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/owner/repo/compare/v1.0.0...v1.1.0
```

**Auto-generate:**
```bash
# Get previous version
PREV=$(git describe --tags --abbrev=0)
NEW="v1.2.0"
REPO="owner/repo"

echo "[${NEW#v}]: https://github.com/$REPO/compare/$PREV...$NEW"
```

## Multi-PR Changelog Updates

When multiple PRs ship together:

```markdown
## [1.2.0] - 2026-01-17
### Added
- Authentication middleware (#42)
- Session management (#43)
- Role-based access (#44)

### Fixed
- Token refresh race condition (#38)
- Session timeout handling (#39)
```

**Group by type, not by PR.**

## Breaking Change Highlighting

For breaking changes, add clear notice:

```markdown
## [2.0.0] - 2026-01-17

### Breaking Changes
- Authentication endpoint now requires API key (#50)
- Removed deprecated `login_v1` endpoint (#51)

### Added
- New API key authentication (#50)
```

Or inline:

```markdown
### Changed
- **BREAKING**: Authentication endpoint now requires API key (#50)
```

## Empty Sections

Don't include empty sections:

```markdown
# Wrong
## [1.2.0] - 2026-01-17
### Added
- New feature

### Changed

### Fixed

# Correct
## [1.2.0] - 2026-01-17
### Added
- New feature
```

## Changelog Validation

Before committing, validate:

```bash
# Check format
grep -E "^## \[[0-9]+\.[0-9]+\.[0-9]+\]" CHANGELOG.md

# Check date format
grep -E "^## \[.+\] - [0-9]{4}-[0-9]{2}-[0-9]{2}" CHANGELOG.md

# Check section headers
grep -E "^### (Added|Changed|Deprecated|Removed|Fixed|Security)" CHANGELOG.md
```

## git-perfectionist Changelog Flow

1. Read current CHANGELOG.md
2. Read execute-state.json for changes
3. Categorise changes by type
4. Draft entries for each type
5. Present section-by-section
6. Human approves each section
7. Write final CHANGELOG.md
8. Validate format
