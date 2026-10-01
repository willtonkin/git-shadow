# 32: CI on GitHub

**What to build:** Every change is checked by shellcheck and the test suite on macOS and Linux, so the README can honestly claim both. Covers issue 02, plus the bash 5 check from issue 20. See `.scratch/first-release/spec.md` (CI).

**Blocked by:** 31, and a GitHub remote for the project (to be created by the maintainer)

**Status:** ready-for-agent

- [ ] A GitHub Actions workflow runs shellcheck over the CLI and the test suite.
- [ ] The workflow runs the test suite on Ubuntu (a modern bash) and macOS (bash 3.2).
- [ ] Any shellcheck findings are fixed or explicitly suppressed with a reason.
- [ ] After the first green run, the README says the tool is tested on macOS and Linux.
