# beacon.wz [![Release](https://img.shields.io/github/v/release/sravioli/beacon.wz?style=flat&label=Release&logo=github)](https://github.com/sravioli/beacon.wz/releases/latest)

<!-- [![Awesome](https://awesome.re/mentioned-badge.svg)](https://github.com/michaelbrusegard/awesome-wezterm) -->

[![Tests](https://img.shields.io/github/actions/workflow/status/sravioli/beacon.wz/tests.yaml?style=flat&label=Tests&logo=githubactions)](https://github.com/sravioli/beacon.wz/actions/workflows/tests.yaml)
[![Lint](https://img.shields.io/github/actions/workflow/status/sravioli/beacon.wz/lint.yaml?style=flat&label=Lint&logo=githubactions)](https://github.com/sravioli/beacon.wz/actions/workflows/lint.yaml)
[![Coverage](https://img.shields.io/coverallsCoverage/github/sravioli/beacon.wz?style=flat&label=Coverage&logo=coveralls)](https://coveralls.io/github/sravioli/beacon.wz)
[![Code license](https://img.shields.io/badge/Code-GPL--2.0-blue?style=flat&logo=gnu)](../LICENSE)
[![Docs license](https://img.shields.io/badge/Docs-CC_BY--NC_4.0-blue?style=flat&logo=creativecommons)](../LICENSE-DOCS)

Update notifications for Git-tracked [WezTerm](https://wezterm.org/) configurations.

Beacon checks your local checkout against a GitHub release or branch.
Click its native toast to open the release or commit page. It never pulls,
merges, or changes your files.

[Quick start](#quick-start) · [Usage](#usage) · [Configuration](#configuration) · [API reference](#api-reference) · [Troubleshooting](#troubleshooting) · [Development](#development) · [License](#license)

## Quick start

### Requirements

Requires **WezTerm [`20230320-124340-559cb7b0`](https://wezterm.org/config/lua/wezterm.plugin/require.html)
or newer** and Git. The stable channel also needs curl, a reachable local
version tag, and a published GitHub release. Monitor a local checkout of
the configured repository.

Automatically loads [warp.wz](https://github.com/sravioli/warp.wz),
[warden.wz](https://github.com/sravioli/warden.wz) and tries
optional [log.wz](https://github.com/sravioli/log.wz), with native logging
as the fallback. Local API modules take precedence over remote plugins.

### Install and run

For a checkout of `sravioli/wezterm` in `wezterm.config_dir`, put this in
`wezterm.lua`:

```lua
local wezterm = require "wezterm"
local beacon = wezterm.plugin.require "https://github.com/sravioli/beacon.wz"
local config = wezterm.config_builder()

beacon.setup { repository = "sravioli/wezterm" }

return config
```

Replace `repository` with your config's actual `owner/name` if different.
In an existing config, keep its builder and return. Add the import and setup.
Open a GUI window and wait for the first status event plus five seconds.
A newer release produces a toast. An up-to-date checkout stays quiet.
Clicking a toast opens the release page. Check **Ctrl+Shift+L** for failures.

## Usage

### Follow a branch instead of releases

Replace the setup call with:

```lua
beacon.setup {
  repository = "sravioli/wezterm",
  channel = "unstable",
  branch = "main",
}
```

Unstable compares the remote branch tip with local `HEAD` using
`git merge-base --is-ancestor`. It stays quiet if local history already
contains that tip, including when you have unpushed commits. It does not
fetch objects or compare your uncommitted files. A missing local tip object
is treated as an available update.

Omit `branch` to follow the currently checked-out branch. A detached `HEAD`
without an explicit branch skips the check.

### Check on demand

After setup, add this binding to your existing keys:

```lua
config.keys = {
  {
    key = "u",
    mods = "CTRL|SHIFT",
    action = wezterm.action_callback(function(window)
      beacon.check_now(window)
    end),
  },
}
```

Press **Ctrl+Shift+U**. A manual check ignores the cooldown and repeats update
notices. If the channel returns no notice, Beacon says `Already up to date.`
even when it skipped a detached-HEAD check. Set an explicit branch when you
need a conclusive result.

Run checks from event, action, or timer callbacks, not during config evaluation.
WezTerm can yield while child processes run in those callback contexts.
Merge the example binding into an existing key list rather than replacing it.

## Configuration

### Example

Call setup after importing Beacon. Apart from the required repository,
configuration is optional. This example changes the channel and check timing:

```lua
beacon.setup {
  repository = "sravioli/wezterm",
  channel = "unstable",
  interval_hours = 6,
  delay_seconds = 10,
}
```

### Options

| Option           | Type                   | Default              | Description                                                                                                              |
| ---------------- | ---------------------- | -------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `repository`     | `string`               | Required             | GitHub `owner/name`. Each part accepts only letters, digits, `_`, `-`, and `.`.                                          |
| `dir`            | `string`               | `wezterm.config_dir` | Local Git checkout. Must be non-empty when supplied.                                                                     |
| `channel`        | `"stable"\|"unstable"` | `"stable"`           | Latest published release or remote branch tip.                                                                           |
| `branch`         | `string?`              | `nil`                | Unstable only. If omitted, Beacon resolves the checked-out branch at check time.                                         |
| `interval_hours` | `number`               | `24`                 | Hours between automatic attempts. Non-negative values below 1 become 1 hour.                                             |
| `delay_seconds`  | `number`               | `5`                  | Non-negative delay after a qualifying status event.                                                                      |
| `name`           | `string`               | `repository`         | Computed notification label. Must be non-empty when supplied.                                                            |
| `timeout_ms`     | `integer`              | `8000`               | How long the toast stays visible, in milliseconds. Must be non-negative. Beacon rounds fractions down.                   |
| `notify`         | `boolean`              | `true`               | `false` skips toasts and only records updates for `available()`, for a status bar to show. `check_now` still toasts.     |
| `validate`       | `boolean`              | `true`               | Check options with [warden.wz](https://github.com/sravioli/warden.wz). Set `false` to skip checks and never load warden. |

#### Option validation

Options are checked against a schema when you call setup. Invalid options make `setup` log an error and return `false`. Unknown keys log a warning.
Set `validate = false` once your configuration is stable. Beacon then never
downloads or loads warden, and uses the options exactly as written. Typos and
wrong types then go unnoticed.

```lua
beacon.setup { repository = "owner/repo", validate = false }
```

### Behavior and precedence

Setup checks options and resolves dependencies, but starts no update-check
processes or timers. Dependency installation may itself download plugins.
The first eligible live `update-status` event schedules the delayed check.
Automatic checks need a visible window.

Each successful setup replaces the previous resolved options rather than
merging them, and registers at most one handler in that Lua context.
Unknown fields are logged as warnings and ignored. Invalid options or a missing dependency log
an error and return `false`. Before the first successful setup, Beacon is
inactive. A failed reconfiguration leaves an earlier successful config active.

Automatic checks record the next eligible time before attempting work, so
failures are throttled too. Cooldown and last-notified keys live in
`wezterm.GLOBAL`, shared across windows and config reloads, but not full
process restarts. Their scope is **repository plus channel**, not directory
or branch. Changing branches within the same channel retains that cooldown.
Manual checks do not reschedule the automatic cooldown.

Stable compares three numeric version components from tags, accepting a
leading `v`. It does not implement full SemVer prerelease ordering.
Stable uses unauthenticated GitHub API requests and shares their rate limit.
You cannot configure a token. Unstable uses `git ls-remote`, not that API.

## API reference

The [API reference](../docs/api.md) lists every function, method, and value
with its parameters and return values. It is generated from the LuaLS
annotations in `plugin/`, so it matches the code. It has these sections:

- [beacon](../docs/api.md#beacon)
- [Types](../docs/api.md#types)

`?` marks a nullable result. All module calls use `.`, not `:`.

A notice is `{ key, title, message, url, version?, name? }`, all strings.
`version` is the release tag (stable channel only), and `name` is the watch's
name on notices from `available()`. `nil` can indicate
no update, a skipped check, missing setup, or an error. Read the logs instead
of using it as a success flag. `config()` exposes `interval_seconds`,
computed from hours, rather than retaining an `interval_hours` field.
Treat the returned config as read-only.

See the [API annotations](../plugin/beacon/api.lua),
[option definitions](../plugin/beacon/config.lua), and
[notice definition](../plugin/beacon/channels.lua) for full types.

## mosaic integration

beacon ships `beacon.update` for the
[mosaic.wz](https://github.com/sravioli/mosaic.wz) status bar. While
`beacon.available()` reports updates it shows an icon and how many
repositories can be updated; each check logs which ones. It hides otherwise. mosaic reads the module only when a layout names it.

```lua
mosaic.setup {
  layout = { right = { { "beacon.update", "cwd", "clock" } } },
  options = {
    ["beacon.update"] = {
      icon = false,  -- optional: hide the glyph (default: oct_package)
    },
  },
}
```

## Troubleshooting

### No toast appears

Up-to-date results and duplicate notices are silent during automatic checks.
Check setup's return value, the debug overlay, the cooldown, and your system's
notification settings. Use a manual check from a callback to diagnose it.

### Stable cannot find a version

The nearest reachable local tag must start with three numeric components
such as `1.2.3` or `v1.2.3`. The remote needs a published release.
A tag alone is not a GitHub release. Choose unstable for branch-only projects.

### Git or curl cannot be found

Warp searches `PATH` and common GUI-launcher install locations. Check that the
program is installed and visible to the WezTerm process. Checks log process,
network, JSON, and unexpected release-response failures without changing files.

Update plugins with `wezterm.plugin.update_all()` from the debug overlay,
then reload. Report problems in [issues](https://github.com/sravioli/beacon.wz/issues)
with WezTerm/plugin versions, channel, and sanitized command errors.

## Development

### Local checkout

Load the working tree directly, so edits take effect on the next config
reload without a commit or a plugin update. Adjust the path to your clone:

```lua
local wezterm = require "wezterm"
local root = wezterm.home_dir .. "/path/to/beacon.wz/plugin/"
package.path = root .. "?.lua;" .. root .. "?/init.lua;" .. package.path
local beacon = require "beacon.api"
```

For offline dependency loading, put the sibling API modules on `package.path`.
The test mock supplies Warp, but specs load warden from a sibling `../warden.wz` checkout.

### Editor support

There is no Beacon entry in the
[wezterm-types collection](https://github.com/DrKJeff16/wezterm-types).
Add this checkout's `plugin` directory to your
[LuaLS library settings](https://luals.github.io/wiki/settings/#workspacelibrary)
to use the source annotations:

```lua
---@type Beacon
local beacon = wezterm.plugin.require "https://github.com/sravioli/beacon.wz"
```

This annotation requires those local definitions. Installing wezterm-types
alone does not supply them.

### Checks and contributions

From the repository root, with Lua 5.4 and the named tools installed:

```sh
busted --verbose
luacheck plugin spec
selene --display-style=quiet plugin
stylua --check plugin spec
```

Specs mock processes, events, and timers without making network checks.
See the [contribution guide](contributing.md).
Use Conventional Commits and keep documentation changes separate from code.

## License

Code: [GNU GPL v2](../LICENSE). Documentation:
[CC BY-NC 4.0](../LICENSE-DOCS). Preserve existing attribution.
