# Repository Guidelines

## Project Structure & Module Organization

beacon is a WezTerm plugin that notifies when a git-tracked config has updates on GitHub. The entrypoint `plugin/init.lua` bootstraps `package.path` and returns `beacon.api`. Modules live in `plugin/beacon/`: `api.lua` (public surface, scheduling, cooldown and dedup state), `config.lua` (option validation and defaults), `channels.lua` (`stable` release checks and `unstable` branch checks), `deps.lua` (local-first loader for warp.wz and log.wz), `logger.lua` (log.wz with a `wezterm.log_*` fallback). Specs live in `spec/beacon/`, with a hand-written WezTerm mock in `spec/mocks/wezterm.lua`. User docs are in `.github/readme.md`.

## Build, Test, and Development Commands

- `busted`: runs the suite.
- `luacheck plugin spec`: lint.
- `selene --display-style=quiet plugin`: second lint profile.
- `stylua --check plugin spec`: formatting.

## Coding Style & Naming Conventions

Two-space indentation, `snake_case`, `require "x"` without parentheses, LuaCATS annotations, `---@module`/`---@author`/`---@license` headers. warp.wz is required and log.wz is optional; load them only through `beacon.deps`, never with `wezterm.plugin.require` elsewhere. memo.wz is deliberately unused: its cache is shared and can be cleared by the host config, which would reset beacon's cooldown. Never use a shell or `io.popen`; external programs go through `warp.process.run` with argument lists. Checks must stay non-blocking: `setup` may resolve dependencies, but nothing may spawn processes at require or setup time, and work only starts from a window event. Log through `beacon.logger` instead of raising from callbacks and `setup`.

## Testing Guidelines

Add or update specs for every behavior change. Bug fixes need a regression test. Drive child processes through `wezterm._respond`, events through `wezterm._emit`, and timers through `wezterm._fire`. `wezterm._reset()` clears mock state and cached beacon modules. The mock stubs warp.wz (`wezterm._warp`) and rejects other `plugin.require` calls, so specs run without sibling checkouts; set `wezterm._warp = nil` to simulate a missing dependency.

## Commit & Pull Request Guidelines

Conventional Commits, subject at most 50 characters, e.g. `fix(channels): accept v-prefixed tags`. Keep source, specs, docs and tooling in separate commits where practical.
