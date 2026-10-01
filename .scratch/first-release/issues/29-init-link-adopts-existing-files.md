# 29: `init --link` adopts existing files

**What to build:** A user with agent files already in a checkout can run `init --link <path>…` there and have those files adopted on the spot, so the copy in that checkout is the one kept. Covers issue 16. See `.scratch/first-release/spec.md` (init adoption).

**Blocked by:** 22

**Status:** done

- [x] `init` accepts repeated `--link <path>` options, including directories with a trailing `/`, and writes each as a link line.
- [x] Untracked files at those paths in the checkout `init` runs in are adopted and replaced with links.
- [x] The README's quick start uses `init --link`.
- [x] A test covers adoption from the checkout `init` runs in.

## Comments

Done. `init` takes `[name]` and repeated `--link <path>` in any order. Paths are relative to the checkout root; an existing directory gets its trailing `/` even if you leave it off; absolute paths and `..` are refused before anything is created. The link lines go into the new manifest, and the existing sync of the checkout `init` runs in adopts the files there.
