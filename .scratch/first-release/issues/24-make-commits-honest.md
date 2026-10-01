# 24: Make commits honest

**What to build:** Every commit in the shadow repo contains only the changes it describes. `drop`'s promise that dropped proposals are recoverable is always true. Covers issues 06, 11 and 17. See `.scratch/first-release/spec.md` (Scoped commits, Session-end commit).

**Blocked by:** 22, 23

**Status:** ready-for-agent

- [ ] `drop` commits the branch area's current contents, including proposals created since the last commit, before removing it. The dropped proposals can be recovered from history even with `autocommit` off.
- [ ] `promote` (both destinations) and `drop` stage only the paths they touched, and always commit, whatever `autocommit` says.
- [ ] Unrelated pending changes in the shadow repo stay uncommitted after `promote` or `drop`.
- [ ] With `autocommit on`, the session-end commit's message names no branch or checkout.
- [ ] The README says `promote` and `drop` always commit, and describes `drop`'s snapshot and the neutral session-end message.
- [ ] Each of these behaviours has a test.
