# 28: `init` records the trunk

**What to build:** The trunk never gets a branch area. `init` detects the trunk and writes it into the manifest. If it can't, it warns, and branch areas stay off (with a visible reason) until a trunk is set. Covers issue 15. See `.scratch/first-release/spec.md` (Trunk).

**Blocked by:** 22

**Status:** ready-for-agent

- [ ] `init` detects the trunk from `origin/HEAD`, then git's default-branch setting, then an existing `main` or `master`, and writes a `trunk` line.
- [ ] When none of those finds a trunk, `init` warns and writes no `trunk` line.
- [ ] At sync time the trunk comes from the manifest only. With no trunk set, no branch areas are created, and sync and session start print a warning saying why.
- [ ] The README describes trunk detection and the warning.
- [ ] Tests cover detection, the warning, and no branch area being created without a trunk.
