# 30: Hook fixes and README gaps

**What to build:** The hooks can be run by hand without hanging. The README's hook setup works even when the command isn't on the hooks' PATH, and the README documents two behaviours it currently leaves out. Covers issues 09, 18 and 19. See `.scratch/first-release/spec.md`.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] `hook-start` and `hook-end` drain stdin only when it isn't a terminal. Run from a terminal, they return straight away (checked by hand, not in the suite).
- [ ] The README's hook snippet shows an absolute path first.
- [ ] The README says `init` removes the project repo from the declined list.
- [ ] The README says `hook-start` passes sync warnings into the agent's context.
- [ ] The test suite passes.
