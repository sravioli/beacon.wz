### Summary

Describe the new beacon.wz feature and the user-facing update workflow it
enables.

### Motivation

Explain why this belongs in beacon.wz. Focus on update channels, check
scheduling, version comparison, or notifications.

### API Sketch

```lua
-- show intended setup or API usage
```

### Behavior

Describe how the feature behaves, including default options, when checks run,
which commands they execute, the notifications shown, and failure cases.

### Compatibility

- [ ] Non-breaking
- [ ] Potentially breaking
- [ ] Breaking

If this is potentially breaking or breaking, explain the migration path.

### Tests

Describe the tests added or updated for this behavior.

### Documentation

Describe the README, examples, annotation, or template changes made for this
feature.

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

