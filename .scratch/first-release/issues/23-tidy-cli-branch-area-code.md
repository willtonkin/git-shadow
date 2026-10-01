# 23: Tidy the CLI's branch-area code

**What to build:** A prefactor with no behaviour change, so that tickets 24–26 land in simpler code. Covers issue 21. See `.scratch/first-release/spec.md` (Cleanup).

**Blocked by:** None (can start immediately)

**Status:** done

- [x] One shared way to walk branch areas, and one check for whether a branch exists locally.
- [x] One helper for a branch's branch-area path, and one for "does the manifest declare per-branch paths".
- [x] One check for "is this link ours", used everywhere that test is made today.
- [x] Removing empty branch areas is separate from listing gone ones.
- [x] The two promote destinations (accepted paths, another branch) are separate functions behind the one `promote` command.
- [x] The current shadow repo is passed or named consistently instead of being set as a side effect. The unused variable in branch-area creation is removed. Reference rewriting uses readable names.
- [x] The test suite passes unchanged.

## Comments

Done. New helpers in `bin/shadow`: `has_per_branch`, `branch_area`, `branch_areas`, `branch_exists` and `is_our_link`. `gone_branches` is split into `gone_branch_areas` (lists) and `prune_empty_gone_branch_areas` (removes, best effort, as before). `promote` dispatches to `promote_into_branch` and `promote_to_accepted`. `require_shadow` prints the shadow dir instead of setting a global, and `commit_shadow` takes it as an argument; every command, `init` included, calls it `shadow`. The unused `numbered` became `_`, and reference rewriting uses `OLD_NAME`/`NEW_NAME`. The suite passes unchanged, 17/17.

Left alone on purpose:
- `sync_branch_link` still has its own `readlink` test. It asks "does this point anywhere under `branches/`?", not "is this exactly our link", so `is_our_link` doesn't fit it.
- The `git rev-parse --show-toplevel` guard is still repeated 5 times. Issue 21 lists it, but this ticket's checklist and the spec's Cleanup list don't.
- `hook-start` now walks gone branch areas twice (prune, then list). That's the price of the split; the cost is one `git show-ref` per area.
