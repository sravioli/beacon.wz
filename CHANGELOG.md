# Changelog

All notable changes to this project are documented here. The format follows
[Conventional Commits](https://www.conventionalcommits.org/) and versions are
managed with [Cocogitto](https://docs.cocogitto.io/).

## Unreleased

### Features

- Non-blocking update checks that start after the first window event.
- `stable` channel: latest GitHub release vs. the nearest local tag.
- `unstable` channel: remote branch tip vs. local `HEAD`.
- Configurable repository, checkout, branch, interval, delay and titles.
- Cooldown and notification dedup that survive config reloads.
- `check_now` for on-demand checks.
- Runs `git` and `curl` through warp.wz, which also finds them outside `PATH`.
- Logs through log.wz when available.
