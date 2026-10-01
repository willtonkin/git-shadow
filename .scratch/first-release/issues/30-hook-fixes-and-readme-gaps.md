# 30: Hook fixes and README gaps

**What to build:** The hooks can be run by hand without hanging. The README's hook setup works even when the command isn't on the hooks' PATH, and the README documents two behaviours it currently leaves out. Covers issues 09, 18 and 19. See `.scratch/first-release/spec.md`.

**Blocked by:** None (can start immediately)

**Status:** done

- [x] `hook-start` and `hook-end` drain stdin only when it isn't a terminal. Run from a terminal, they return straight away (checked by hand, not in the suite).
- [x] The README's hook snippet shows an absolute path first.
- [x] The README says `init` removes the project repo from the declined list.
- [x] The README says `hook-start` passes sync warnings into the agent's context.
- [x] The test suite passes.

## Comments

Done. Both hooks skip draining stdin when it is a terminal (`[ -t 0 ]`). Checked by hand with `script` on macOS, feeding a pty that never closes: the old binary hung until a 4s alarm killed it, the new one exits 0 for both hooks. The README hook snippet now shows an absolute path, with a bare `git-shadow` as the fallback. The `decline` row says `init` undoes it, and the `hook-start` list says sync warnings reach the agent.
