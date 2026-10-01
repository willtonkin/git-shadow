# 25: Make `promote --into` work after a rename

**What to build:** After `git branch -m old new` and a new session, `promote old --into new` just works. That includes when the new branch already has an empty branch area, or proposals that don't collide. It works on Linux, and a failure never leaves a half-done promotion. Covers issues 01 and 13. See `.scratch/first-release/spec.md` (Promote into another branch).

**Blocked by:** 22, 23

**Status:** ready-for-agent

- [ ] If the destination branch area doesn't exist or holds no proposals, the source takes its place.
- [ ] If the destination holds proposals and no relative path appears in both, the two branch areas are merged.
- [ ] If any path appears in both, the command refuses and both branch areas are left exactly as they were.
- [ ] The branch-area record is rewritten portably, without in-place editing, before anything moves.
- [ ] The README describes the merge and refusal behaviour.
- [ ] Tests cover the empty destination, the non-colliding merge and the collision refusal.
