### Summary

Describe the beacon.wz documentation change.

### Documentation Changed

List the README, examples, contributing guide, issue templates, pull request
templates, or annotation docs changed by this pull request.

### Reader Impact

Explain who benefits from this documentation change:

- Users setting up update checks.
- Users choosing channels, branches, or check intervals.
- Contributors changing beacon.wz internals.

### Examples Touched

```lua
-- setup example changed by this pull request
```

### Behavior Change

- [ ] Documentation only
- [ ] Documents an existing behavior
- [ ] Documents a new behavior

If this documents a new behavior, link to the implementation pull request or
commit.

### Checklist

- [ ] The change is scoped to beacon.wz.
- [ ] Public API changes are documented, if applicable.
- [ ] Channel, scheduling, or notification behavior is covered by tests, if applicable.
- [ ] Checks remain non-blocking (no I/O during config evaluation or startup).
- [ ] Required checks pass:
  - [ ] `busted --verbose`
  - [ ] `luacheck .`
  - [ ] `stylua --check .`
  - [ ] `selene --display-style=quiet .`

