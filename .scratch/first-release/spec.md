# First release of git-shadow

Status: ready-for-agent

## Problem Statement

shadow is close to its first public release, but it has accumulated bugs and loose ends that a new user would hit early, and some of them lose data or touch things they shouldn't:

- **Dropping can lose work.** `drop` says its proposals stay recoverable from the shadow repo's history, but it deletes them whether or not they were ever committed.
- **Committing lies about its scope.** `promote` and `drop` sweep every pending change in the shadow repo into their own commit, and the session-end commit claims all changes came from the branch that happened to end first.
- **Common setups break.**
  - `init` in a project repo with no remote creates a shadow repo it can never find again.
  - When the trunk can't be found, the trunk gets a branch area.
  - `init` doesn't adopt existing files, even though the README tells you to run it where the files are.
  - Promoting into a renamed branch fails on the empty branch area the session-start hook just created.
  - Promoting into another branch only works on macOS.
- **Promoting corrupts or breaks references.** Renumbering rewrites names that merely end the same way, and leaves references from outside the promoted set broken.
- **Running the tests can damage the developer's machine.** On git 2.31, the stated minimum, the suite overwrites the developer's real global git config.
- **Small rough edges.** The hooks hang when run by hand. The README omits a few behaviours, and its hook snippet assumes a PATH that hooks may not have.
- **Name and support gaps.**
  - The name `shadow` collides with Linux's shadow-utils.
  - Nothing runs lint or tests automatically.
  - Linux support has never been tested.

## Solution

Ship a first release named `git-shadow` (also runnable as `git shadow`) in which:

- every command does what the README says;
- `drop`'s recoverability promise is always true;
- each command's commit contains only that command's changes;
- `init` sets up a working shadow repo in any project repo, records the trunk, and can adopt existing files on the spot;
- promoting handles the rename workflow, and rewrites references to renumbered proposals everywhere in the shadow repo without corrupting other names;
- the test suite can't touch the developer's real config;
- CI checks every change on macOS and Linux.

The vocabulary used here is defined in the repo's domain glossary. The naming decision is recorded in ADR 0002.

## User Stories

### Naming and install

1. As a new user, I want the command to be called `git-shadow`, so that it doesn't clash with shadow-utils in my package manager or in search results.
2. As a git user, I want to run it as `git shadow`, so that it feels like part of git.
3. As a user, I want the shadow repo concept, `SHADOW_HOME`, the manifest file name and the branch link name to keep their names, so that nothing I already have needs migrating.
4. As a Linux user, I want the README to say the tool is tested on Linux, and for that to be true, so that I can rely on it outside macOS.

### init

5. As a user in a project repo with no remote, I want `init` to name the shadow repo after my checkout's folder, so that the shadow repo can be found again afterwards.
6. As a user, I want `init` to refuse a shadow repo name that starts with a dot, so that I can't create a shadow repo that lookups skip.
7. As a user, I want `init` to detect the trunk and write it into the manifest, so that the trunk never gets a branch area.
8. As a user whose trunk can't be detected, I want `init` to warn me and leave the trunk unset, so that I can see the problem and set it myself rather than live with a wrong guess.
9. As a user with no trunk set, I want no branch areas to be created until I set one, so that a missing trunk can't give the trunk a branch area.
10. As a user with no trunk set, I want sync and session start to tell me branch areas are off until a trunk is set, so that I know why proposals aren't being separated.
11. As a user with untracked agent files already in a checkout, I want `init --link <path>…` to write those link lines and adopt the files from that checkout, so that the copy I ran `init` in is the one that's kept.
12. As a user, I want `init --link` to accept several paths, including directories, so that I can set up everything in one command.
13. As a user, I want `init` to still remove the project repo from my declined list, as it does today, and for the README to say so.

### Promote

14. As a user who renamed a branch, I want `promote <old> --into <new>` to succeed when the new branch's branch area is empty, so that the usual rename workflow just works.
15. As a user who already wrote a proposal on the renamed branch, I want `promote --into` to merge the two branch areas when no file paths collide, so that I don't have to merge by hand for no reason.
16. As a user whose two branch areas have a file path in common, I want `promote --into` to refuse and change nothing, so that no proposal is overwritten.
17. As a Linux user, I want `promote --into` to work, so that renaming isn't macOS-only.
18. As a user, I want a failed `promote --into` to leave the old branch area exactly as it was, so that a failure never leaves a half-done promotion behind.
19. As a user promoting numbered proposals, I want every reference to a renumbered proposal anywhere in the shadow repo to be updated, so that links from specs, notes or other branch areas don't break silently.
20. As a user, I want reference rewriting to match whole file names only, so that promoting `tokens.md` never touches a reference to `session-tokens.md`.
21. As a user, I want `promote` to commit only the paths it touched, so that unrelated changes I'm in the middle of aren't swept into a "promote" commit.
22. As a user with `autocommit` off, I want `promote` to commit anyway, so that the shadow repo's history records every promotion.

### Drop

23. As a user, I want `drop` to commit the branch area before deleting it, so that dropped proposals really are recoverable from history.
24. As a user with `autocommit` off, I want `drop`'s snapshot commit to happen anyway, so that recoverability doesn't depend on a setting.
25. As a user with proposals created since the last commit, I want those proposals in the snapshot too, so that nothing in the branch area is lost.
26. As a user, I want `drop` to commit only the paths it touched, so that unrelated pending changes stay pending.
27. As a user, I want `drop`'s message about recoverability to be true every time it's printed.

### Session hooks

28. As a user running several agent sessions in different checkouts, I want the session-end commit to have a neutral message that names no branch, so that history never claims a branch made changes it didn't make.
29. As a user debugging hooks, I want `hook-start` and `hook-end` to return straight away when run from a terminal, so that they don't hang waiting for input.
30. As a user wiring up hooks, I want the README's hook snippet to show an absolute path first, so that hooks don't fail silently when the command isn't on their PATH.
31. As a user, I want the README to say that `hook-start` passes sync warnings into the agent's context, so that I know where those messages come from.
32. As a user, I want the README to say that `promote` and `drop` always commit, so that the commits in my shadow repo aren't a surprise.

### Development

33. As a contributor on any git version from 2.31, I want the test suite to isolate git config completely, so that running it never changes my real config.
34. As a contributor, I want every change checked by shellcheck and the test suite on macOS and Linux in CI, so that portability bugs are caught before release.
35. As a contributor, I want the tests to run on a modern bash as well as macOS's bash 3.2, so that version differences are caught.
36. As a contributor, I want two runs of the test suite at once not to share a log file, so that their output doesn't mix.
37. As a contributor, I want repeated test setup gathered into shared fixtures, so that new tests are short and the suite's assumptions are in one place.
38. As a maintainer, I want the duplicated walks, rebuilt branch-area paths and inconsistent names in the CLI cleaned up, so that the code is easier for agents and people to change.

## Implementation Decisions

- **Name.** The binary and package become `git-shadow`. The shadow repo concept, `SHADOW_HOME`, the `.shadow` manifest, the `.branch-shadow` branch link and the exclude-block markers keep their names (ADR 0002). The README, usage text and messages use the new command name.
- **Licence.** MIT, confirmed. No change.
- **Promote stays one command with two destinations.** `promote <branch>` sends proposals to their accepted paths. `promote <branch> --into <branch>` sends them into another branch's branch area. No separate `move` command. Internally, the two cases are separate functions behind one command, sharing only argument parsing and branch-area lookup.
- **Promote into another branch:**
  - If the destination branch area doesn't exist, or holds no proposals, the source takes its place.
  - If it holds proposals, the two are merged only if no relative path appears in both. Otherwise the command refuses before changing anything.
  - The `.branch` record is rewritten portably, by writing a fresh file rather than editing in place, and the rewrite happens before anything is moved.
- **Reference rewriting on promote:**
  - When numbering renames proposals, every text file in the shadow repo is searched for references to them, not just the promoted files.
  - The git directory is excluded from the search.
  - A match must be the whole file name: it can't be preceded or followed by a character that could be part of a file name.
- **Scoped commits:**
  - `promote` and `drop` stage only the paths they touched (the branch areas involved and any accepted paths written to), and always commit, whatever `autocommit` says.
  - `drop` commits the branch area's current contents first, then commits its removal, so the dropped proposals sit in history.
- **Session-end commit.** With `autocommit on`, `hook-end` still commits all pending changes, but with a fixed neutral message that names no branch or checkout.
- **Trunk:**
  - `init` detects the trunk from `origin/HEAD`, then git's `init.defaultBranch`, then whichever of `main` or `master` exists, and writes a `trunk` line into the manifest.
  - If none of these finds a trunk, `init` warns and writes no `trunk` line.
  - At sync time, the trunk comes from the manifest only. With no trunk set, no branch areas are created, and sync and session start print a warning that says so.
- **init naming.** For a project repo without a remote (`path:` identity), the default shadow repo name is the checkout's folder name. Names starting with `.` are rejected.
- **init adoption.** `init` takes repeated `--link <path>` options. Each one is written as a link line, and the checkout `init` runs in is synced straight away, so its untracked files at those paths are adopted.
- **Hooks and stdin.** The hooks drain stdin only when it isn't a terminal.
- **Tests.** The test harness isolates git config by pointing `HOME` at the test's temp directory, alongside the existing variables. The stated minimum stays git 2.31.
- **CI.** The project is published on GitHub. A GitHub Actions workflow runs shellcheck over the CLI and the test suite, then runs the suite on Ubuntu and macOS. After the first green run, the README says the tool is tested on macOS and Linux.
- **Cleanup** (no behaviour change):
  - one shared branch-area iterator and a branch-exists check;
  - one helper for a branch's branch-area path, and one for "does the manifest declare per-branch paths";
  - one "is this link ours" check;
  - split the empty-area cleanup out of the gone-branch listing;
  - drop the unused variable in branch-area creation;
  - consistent naming of the current shadow repo instead of a global set as a side effect;
  - readable names in reference rewriting;
  - in the test suite: a fixture for "a branch with a proposal", one name shared by the remote and the manifest helper, and a per-run log file.
- **README** gets updated for:
  - the new name;
  - absolute-path hooks;
  - `init --link`;
  - trunk detection and the warning when there's no trunk;
  - `promote --into` merging;
  - `promote` and `drop` always committing;
  - `drop`'s snapshot;
  - the neutral session-end message;
  - `init` clearing a decline;
  - sync warnings reaching the agent's context;
  - and the Limitations section loses the numbering-reach item.

## Testing Decisions

- **One seam: the command line, tested end to end.** Every test builds a fresh project repo and `SHADOW_HOME` in a temp directory, runs real commands, and asserts only what a user can see: links and files in checkouts, files in the shadow repo, command output, exit status, and the shadow repo's git log. No tests of internal functions.
- **A good test** names the behaviour from the user's side, sets up only what that behaviour needs, and would still pass after any refactor that keeps the behaviour.
- **New or changed tests:**
  - `drop` with `autocommit` off leaves the dropped proposals in history.
  - `drop` and `promote` leave unrelated pending changes uncommitted.
  - The session-end commit message names no branch.
  - `promote --into` onto an empty branch area succeeds.
  - `promote --into` merges when no paths collide.
  - `promote --into` refuses on a colliding path and leaves both branch areas unchanged.
  - Promoting rewrites a reference from outside the promoted set.
  - Promoting doesn't touch a name that only shares an ending.
  - `init` without a remote produces a shadow repo that sync then finds.
  - `init` rejects a dot name.
  - `init` writes the detected trunk.
  - `init` warns when no trunk can be found, and then no branch area is created.
  - `init --link` adopts files from the checkout it runs in.
- **Prior art:**
  - the existing drop, autocommit, promote-into, promote-numbering and adoption tests;
  - the harness's assertion helpers for links, files, absence, output contents and a clean git status.
- **Rename in the harness.** The only change is the command its wrapper calls.
- **Not covered by the suite:**
  - the hooks' terminal check, which is verified by hand, because a pseudo-terminal test would need different code on macOS and Linux;
  - CI and shellcheck, which are checks that run over the suite rather than behaviour tested through it.
- **Cleanup items are covered by the existing suite.** It must pass unchanged before and after.

## Out of Scope

- A "not yet" answer for a gone branch area (`keep` / snooze). It stays a documented limitation (issue 05).
- Keeping per-branch instructions current after a branch switch mid-session. It stays a documented limitation, because hooks only run at session start and end (issue 08).
- An `install-hooks` command that writes agent settings. It's a later idea; this release only fixes the README snippet (issue 09).
- Attributing session-end changes to branches, or one commit per branch area.
- A separate `move` command, or a deprecated alias for one.
- Raising the minimum git version.
- Migrating anything for existing users, since there are none before the first release.

## Further Notes

- This spec covers issues 01–03, 06, 07 and 09–21 in this folder. It confirms 04 (licence) and leaves 05 and 08 as limitations. Each issue's own notes can be used as detail, but where they differ, the decisions here win.
- Suggested order, so later work isn't redone:
  1. test isolation (10), since it protects the developer;
  2. drop's snapshot and scoped commits (11, 17, 06);
  3. promote (01, 13, 14, 07);
  4. init (12, 15, 16);
  5. hooks and README (18, 19, 09);
  6. cleanup (20, 21);
  7. the rename (03), last of all, so that every other change lands under the old name first;
  8. CI (02), once there's a GitHub remote.
