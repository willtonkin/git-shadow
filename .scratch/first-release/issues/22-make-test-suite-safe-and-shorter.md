# 22: Make the test suite safe and shorter to extend

**What to build:** Running the test suite can never change the developer's real git config, on any git version from 2.31. Repeated test setup lives in shared fixtures, so the tests in later tickets are short. Covers issues 10 and 20 (the bash 5 check moves to 32). See `.scratch/first-release/spec.md`.

**Blocked by:** None (can start immediately)

**Status:** done

- [x] Each test's home directory is its own temp directory, so global git config writes land there, not in the developer's real config.
- [x] A "branch with a proposal" fixture replaces the repeated worktree-plus-proposal setup.
- [x] The project name is defined once and shared by the test remote and the manifest helper.
- [x] Each run writes its log to its own location, so two runs at once don't mix output.
- [x] Every existing test still passes, with the same behaviour.

## Comments

Done. `setup` points `HOME` and `XDG_CONFIG_HOME` at the test's temp dir, and `GIT_CONFIG_GLOBAL` at `$HOME/.gitconfig`, so every git version writes to the same isolated file. I checked by hand that with `GIT_CONFIG_GLOBAL` removed, as git 2.31 ignores it, a sentinel outer `HOME` stays untouched. New fixtures: `branch_checkout` and `branch_with_proposal`. `PROJECT` and `SHADOW_REPO` name the shadow repo once. The log is a per-run `mktemp` file.
