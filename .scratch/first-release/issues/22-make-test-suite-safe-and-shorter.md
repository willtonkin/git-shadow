# 22: Make the test suite safe and shorter to extend

**What to build:** Running the test suite can never change the developer's real git config, on any git version from 2.31. Repeated test setup lives in shared fixtures, so the tests in later tickets are short. Covers issues 10 and 20 (the bash 5 check moves to 32). See `.scratch/first-release/spec.md`.

**Blocked by:** None (can start immediately)

**Status:** ready-for-agent

- [ ] Each test's home directory is its own temp directory, so global git config writes land there, not in the developer's real config.
- [ ] A "branch with a proposal" fixture replaces the repeated worktree-plus-proposal setup.
- [ ] The project name is defined once and shared by the test remote and the manifest helper.
- [ ] Each run writes its log to its own location, so two runs at once don't mix output.
- [ ] Every existing test still passes, with the same behaviour.
