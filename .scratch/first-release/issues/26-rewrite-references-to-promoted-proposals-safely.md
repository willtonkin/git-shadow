# 26: Rewrite references to promoted proposals safely

**What to build:** When `promote` renumbers proposals, every reference to them anywhere in the shadow repo follows. A name that merely shares an ending is never touched. Covers issues 07 and 14. See `.scratch/first-release/spec.md` (Reference rewriting on promote).

**Blocked by:** 22, 23

**Status:** ready-for-agent

- [ ] References to a renumbered proposal are rewritten in every text file in the shadow repo, including other branch areas and shared files, not only among the promoted proposals.
- [ ] The shadow repo's git directory is never searched.
- [ ] Only whole file names match: promoting `tokens.md` leaves a reference to `session-tokens.md` alone.
- [ ] The README's Limitations section no longer lists the numbering-reach limitation.
- [ ] Tests cover a reference from outside the promoted set and a name that shares an ending.
