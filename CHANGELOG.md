# Changelog

## [Unreleased]

### Added

- `git-shadow` (also run as `git shadow`), with `init`, `sync [--all]`, `status` and `decline`: link files from a local shadow repo into every checkout of a repo, hidden through a managed block in `.git/info/exclude`.
- `per-branch` manifest option, with `promote`, `promote --into` and `drop`, for files that should follow branch lifecycles.
- `hook-start` and `hook-end` entry points for agent session hooks, with Claude Code setup documented in the README.
- Merge detection for branch areas: session start recommends promoting branches merged into the trunk and dropping gone branches whose pull request was closed, and stays quiet about gone branches with an open one. Uses `gh` when available, otherwise local ancestry against `origin/<trunk>`; `status` shows the result and its source.
- `onboard`: prints the repo's state (shadow repo, trunk, Claude Code hooks, candidate files) and a prompt that has an agent move your personal files into a shadow repo. Session start in a repo with no shadow repo now points the agent at it.
