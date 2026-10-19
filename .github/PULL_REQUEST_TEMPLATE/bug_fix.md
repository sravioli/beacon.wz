### Summary

Describe the bug fixed in beacon.wz and the user-visible check or
notification behavior that changed.

### Reproduction

Provide the smallest setup that reproduced the issue.

```lua
-- setup that reproduced the bug
```

### Root Cause

Explain why option validation, scheduling, version comparison, git or HTTP
handling, notification deduplication, or dependency loading was wrong.

### Fix

Describe the implementation change and why it fixes the problem.

### Regression Test

Describe the regression test added or updated.

### Compatibility Impact

- [ ] Non-breaking
- [ ] Potentially breaking
- [ ] Breaking

If this changes behavior intentionally, explain why the new behavior is correct.

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

