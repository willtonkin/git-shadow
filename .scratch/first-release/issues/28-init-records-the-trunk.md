# 28: `init` records the trunk

**What to build:** The trunk never gets a branch area. `init` detects the trunk and writes it into the manifest. If it can't, it warns, and branch areas stay off (with a visible reason) until a trunk is set. Covers issue 15. See `.scratch/first-release/spec.md` (Trunk).

**Blocked by:** 22

**Status:** done

- [x] `init` detects the trunk from `origin/HEAD`, then git's default-branch setting, then an existing `main` or `master`, and writes a `trunk` line.
- [x] When none of those finds a trunk, `init` warns and writes no `trunk` line.
- [x] At sync time the trunk comes from the manifest only. With no trunk set, no branch areas are created, and sync and session start print a warning saying why.
- [x] The README describes trunk detection and the warning.
- [x] Tests cover detection, the warning, and no branch area being created without a trunk.

## Comments

Done. `init` writes `trunk <branch>` from `origin/HEAD`, then `init.defaultBranch`, then `main`, then `master`. Apart from `origin/HEAD`, the branch must exist locally to count, so an unrelated global `init.defaultBranch` can't make a wrong guess. With none found, `init` warns and writes no line. `trunk_branch` now reads the manifest only (the last `trunk` line wins). With per-branch paths but no trunk, `sync` warns and makes no branch link, and `hook-start` passes that warning on and skips the per-branch instructions. The tests' `'trunk main'` manifest lines are gone, since `init` now writes it.
