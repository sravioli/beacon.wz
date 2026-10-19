# beacon.wz

[![Tests](https://img.shields.io/github/actions/workflow/status/sravioli/beacon.wz/tests.yaml?label=Tests&logo=Lua)](https://github.com/sravioli/beacon.wz/actions?workflow=tests)
[![Lint](https://img.shields.io/github/actions/workflow/status/sravioli/beacon.wz/lint.yaml?label=Lint&logo=Lua)](https://github.com/sravioli/beacon.wz/actions?workflow=lint)
[![Coverage](https://img.shields.io/coverallsCoverage/github/sravioli/beacon.wz?label=Coverage&logo=coveralls)](https://coveralls.io/github/sravioli/beacon.wz)

Update notifications for a [WezTerm](https://wezfurlong.org/wezterm/) config
kept in a git checkout.

beacon compares your local checkout with its GitHub repository and shows a
native WezTerm toast when something new is out. Clicking the toast opens the
release or commit page. It never pulls, merges or touches your files.

## Non-blocking by design

- `setup` validates options, loads its plugin dependencies and registers an
  event handler. It runs no processes, so config evaluation stays fast.
- The first check is scheduled from the first `update-status` event, which
  means a window is already open, plus a short delay (5 seconds by default).
- `git` and `curl` run through warp.wz's `process.run` (a wrapper around
  `wezterm.run_child_process`), which is asynchronous inside event and timer
  callbacks, so the GUI keeps responding while requests are in flight.
- The cooldown lives in `wezterm.GLOBAL`, so config reloads and new windows do
  not trigger extra checks. Failures are throttled the same way and are logged
  instead of raised.

## Installation

```lua
local wezterm = require "wezterm"
local config = wezterm.config_builder()

local beacon = wezterm.plugin.require "https://github.com/sravioli/beacon.wz"

beacon.setup { repository = "you/wezterm-config" }

return config
```

`git` and `curl` are looked up on `PATH` and in common install locations
(WinGet, Scoop, Homebrew, Nix, ...), which helps when WezTerm is started from a
GUI launcher. The checkout defaults to `wezterm.config_dir`.

## Dependencies

- [warp.wz](https://github.com/sravioli/warp.wz) (required): process helpers.
- [log.wz](https://github.com/sravioli/log.wz) (optional): when it is
  available, beacon logs through a `beacon` logger and honours log.wz's
  threshold and sinks. Otherwise it uses `wezterm.log_*` with a `[beacon]`
  prefix.

Both are resolved from `package.path` first, so local checkouts work, then
through `wezterm.plugin.require`. If warp.wz cannot be loaded, `setup` logs the
error and returns `false`.

## Channels

| Channel    | Compares                                                       | Opens               |
| ---------- | -------------------------------------------------------------- | ------------------- |
| `stable`   | Latest GitHub release vs. the nearest local tag (semver)        | The release page    |
| `unstable` | Remote branch tip vs. local `HEAD` (`git merge-base`)           | The branch commits  |

`stable` uses the unauthenticated GitHub API, so it shares the 60 requests per
hour limit for your IP. Tags may carry a `v` prefix. `unstable` uses
`git ls-remote` and needs no API. It stays quiet when local `HEAD` already
contains the remote tip, even if you have unpushed commits.

## Options

```lua
beacon.setup {
  repository = "you/wezterm-config", -- required, "owner/name"
  dir = wezterm.config_dir,          -- local checkout to compare against
  channel = "stable",                -- "stable" or "unstable"
  branch = nil,                      -- unstable only; defaults to the current branch
  interval_hours = 24,               -- time between checks, minimum 1
  delay_seconds = 5,                 -- wait after the first window event
  name = "you/wezterm-config",       -- prefix for notification titles
  timeout_ms = 8000,                 -- how long the toast stays visible
}
```

Invalid options are logged as errors and leave beacon disabled.
Your config keeps loading. Calling `setup` again replaces the options without
registering a second handler.

On a detached `HEAD`, `unstable` needs an explicit `branch`; otherwise the
check is skipped.

## Checking on demand

`check_now` ignores the cooldown, repeats notices already shown and reports
when you are up to date. Call it from an async context such as an action
callback:

```lua
config.keys = {
  {
    key = "u",
    mods = "LEADER",
    action = wezterm.action_callback(function(window)
      beacon.check_now(window)
    end),
  },
}
```

## API

- `beacon.setup(opts) -> boolean`: configure and start watching.
- `beacon.check_now(window) -> notice|nil`: check immediately.
- `beacon.config() -> table|nil`: the resolved configuration.

## Development

```sh
busted                               # specs in spec/beacon, against spec/mocks/wezterm.lua
luacheck plugin spec
selene --display-style=quiet plugin
stylua --check plugin spec
```

## License

Code is licensed under the [GNU GPLv2](../LICENSE). Documentation is licensed
under [CC BY-NC 4.0](../LICENSE-DOCS).
