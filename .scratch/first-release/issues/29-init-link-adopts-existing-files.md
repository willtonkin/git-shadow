# 29: `init --link` adopts existing files

**What to build:** A user with agent files already in a checkout can run `init --link <path>…` there and have those files adopted on the spot, so the copy in that checkout is the one kept. Covers issue 16. See `.scratch/first-release/spec.md` (init adoption).

**Blocked by:** 22

**Status:** ready-for-agent

- [ ] `init` accepts repeated `--link <path>` options, including directories with a trailing `/`, and writes each as a link line.
- [ ] Untracked files at those paths in the checkout `init` runs in are adopted and replaced with links.
- [ ] The README's quick start uses `init --link`.
- [ ] A test covers adoption from the checkout `init` runs in.
