# Deployment Checklist

Pre-deploy and post-merge verification for claudikins-kernel:ship.

## Pre-Ship Checklist

### Verification Gate

- [ ] claudikins-kernel:verify has been run
- [ ] `unlock_ship == true` in verify-state.json
- [ ] All automated checks passed (tests, lint, types)
- [ ] Human checkpoint approved
- [ ] Evidence captured (screenshots, curl responses)

### Code Integrity

- [ ] Current commit matches verified commit (C-5)
- [ ] File manifest matches verified manifest (C-7)
- [ ] No uncommitted changes in working directory
- [ ] Feature branches are up to date with main

### Documentation

- [ ] README updated if features changed
- [ ] CHANGELOG entry added
- [ ] Version bumped if applicable
- [ ] API docs updated if endpoints changed
- [ ] Migration guide written if breaking changes

### Dependencies

- [ ] No known security vulnerabilities
- [ ] Lock files committed (package-lock.json, Cargo.lock)
- [ ] Peer dependencies satisfied
- [ ] No deprecated dependencies used

## Pre-Merge Checklist

### CI Status

- [ ] All CI checks pass
- [ ] Coverage threshold met
- [ ] No lint errors
- [ ] No type errors
- [ ] Build succeeds

### Review Status

- [ ] PR approved (if required)
- [ ] No unresolved comments
- [ ] No requested changes pending

### Conflict Status

- [ ] No merge conflicts
- [ ] Base branch is up to date
- [ ] Feature branch rebased if needed

## Merge Decision Matrix

| CI | Review | Conflicts | Action |
|----|--------|-----------|--------|
| Pass | Approved | None | Merge |
| Pass | Pending | None | Wait for review |
| Pass | Approved | Yes | Resolve conflicts first |
| Fail | * | * | Fix CI first |
| * | Changes requested | * | Address feedback first |

## Post-Merge Checklist

### Cleanup

- [ ] Feature branches deleted
- [ ] Local branches pruned
- [ ] Worktrees removed (if used)

### Verification

- [ ] Main branch builds
- [ ] Main branch tests pass
- [ ] Deployment pipeline triggered (if applicable)

### State Update

- [ ] ship-state.json updated with `shipped_at`
- [ ] verify-state.json archived or cleared
- [ ] execute-state.json archived or cleared

## Environment-Specific Checks

### Staging Deployment

- [ ] Staging environment accessible
- [ ] Database migrations run
- [ ] Environment variables set
- [ ] Feature flags configured
- [ ] Smoke tests pass

### Production Deployment

- [ ] Staging deployment verified
- [ ] Rollback plan documented
- [ ] Monitoring dashboards ready
- [ ] On-call notified (if applicable)
- [ ] Deployment window approved

## Breaking Change Checklist

If shipping breaking changes:

- [ ] BREAKING CHANGE noted in commit
- [ ] Major version bump applied
- [ ] Migration guide written
- [ ] Deprecation warnings added (if gradual)
- [ ] Clients notified (if external API)
- [ ] Backwards compatibility period defined

## Security Checklist

- [ ] No secrets in code
- [ ] No sensitive data in logs
- [ ] Auth/authz tested
- [ ] Input validation in place
- [ ] SQL injection prevented
- [ ] XSS prevented (if web)
- [ ] CSRF protection (if web)

## Rollback Plan

Before merging, ensure rollback is possible:

### Git Rollback

```bash
# Identify last good commit
git log --oneline -10

# Revert merge commit
git revert -m 1 <merge-commit-sha>

# Or reset (only if not pushed)
git reset --hard <last-good-commit>
```

### Database Rollback

- [ ] Migration has down/rollback
- [ ] Data changes are reversible
- [ ] Backup taken before migration

### Feature Flag Rollback

If using feature flags:

```
# Disable feature
FLAG_NEW_AUTH=false
```

## Notification Checklist

### Internal

- [ ] Team notified of deployment
- [ ] Changelog shared in team channel
- [ ] On-call aware of changes

### External (if public API)

- [ ] Changelog published
- [ ] API docs updated
- [ ] Status page updated (if applicable)
- [ ] Client notification sent (if breaking)

## Post-Ship Celebration

After successful ship:

```
Done! Shipped to main.

PR #42 merged ✓
Branches cleaned up ✓
Version: 1.1.0 → 1.2.0

Nice work!
```

Take a moment to acknowledge the work completed:
- Feature shipped successfully
- All checks passed
- Documentation updated
- Clean merge

Then move on to the next task.
