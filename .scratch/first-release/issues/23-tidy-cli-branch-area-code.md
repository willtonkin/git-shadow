# 23: Tidy the CLI's branch-area code

**What to build:** A prefactor with no behaviour change, so that tickets 24–26 land in simpler code. Covers issue 21. See `.scratch/first-release/spec.md` (Cleanup).

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] One shared way to walk branch areas, and one check for whether a branch exists locally.
- [ ] One helper for a branch's branch-area path, and one for "does the manifest declare per-branch paths".
- [ ] One check for "is this link ours", used everywhere that test is made today.
- [ ] Removing empty branch areas is separate from listing gone ones.
- [ ] The two promote destinations (accepted paths, another branch) are separate functions behind the one `promote` command.
- [ ] The current shadow repo is passed or named consistently instead of being set as a side effect. The unused variable in branch-area creation is removed. Reference rewriting uses readable names.
- [ ] The test suite passes unchanged.
