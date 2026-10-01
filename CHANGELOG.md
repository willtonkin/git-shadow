# Changelog

## [Unreleased]

### Added

- `shadow init`, `sync [--all]`, `status` and `decline`: link files from a local shadow repo into every checkout of a repo, hidden through a managed block in `.git/info/exclude`.
- `per-branch` manifest option, with `promote`, `promote --into` and `drop`, for files that should follow branch lifecycles.
- `hook-start` and `hook-end` entry points for agent session hooks, with Claude Code setup documented in the README.
