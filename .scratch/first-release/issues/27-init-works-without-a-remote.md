# 27: `init` works in a project repo with no remote

**What to build:** Running `init` in a project repo with no remote creates a shadow repo that every later command can find. Covers issue 12. See `.scratch/first-release/spec.md` (init naming).

**Blocked by:** 22

**Status:** done

- [x] For a project repo with no remote, the default shadow repo name is the checkout's folder name.
- [x] `sync` after such an `init` finds the shadow repo.
- [x] `init` refuses a shadow repo name that starts with a dot.
- [x] Tests cover both.
