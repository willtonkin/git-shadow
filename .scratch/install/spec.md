# One-command install and update, and automated releases

Status: ready-for-agent

## Problem

Installing git-shadow means cloning it somewhere and symlinking `bin/git-shadow` onto your PATH by hand, and updating means remembering where that clone is. There are no releases, so there's no stable version to install or report.

## Behaviour

### `install.sh`

```sh
curl -fsSL https://raw.githubusercontent.com/willtonkin/git-shadow/main/install.sh | bash
```

The same command installs and updates. git-shadow finds `prompts/` next to its real file, so an install is a clone plus a symlink, never a copied file.

- **Requirements**, checked before anything else: git 2.31+ and perl. A missing tool or an old git is named and nothing is changed. `gh` stays optional and is mentioned once at the end if it's missing.
- **Where**: the clone goes to `${XDG_DATA_HOME:-$HOME/.local/share}/git-shadow`, and the symlink to `$HOME/.local/bin/git-shadow`. `GIT_SHADOW_DIR` and `GIT_SHADOW_BIN` (a directory) override them. `GIT_SHADOW_REPO` overrides where it clones from.
- **What**: the newest release tag (`vX.Y.Z`, compared as versions), checked out detached. `GIT_SHADOW_REF` checks out a given tag or branch instead (a branch is checked out detached at its remote tip). With no release tags and no `GIT_SHADOW_REF`, it stops and says so.
- **Managed clone**: one that is detached and has no uncommitted changes to tracked files. Only a managed clone is ever moved. A clone on a branch is a development checkout: it's refused with its path and branch, and the user updates it with git. Uncommitted changes are refused too.
- **Existing installs**: if `$GIT_SHADOW_BIN/git-shadow` already resolves into a managed clone somewhere else, that clone is updated in place and the symlink is left alone. If it resolves into a development checkout, or it's anything other than a symlink, it's refused unless `GIT_SHADOW_FORCE=1`, which installs at `GIT_SHADOW_DIR` and repoints the symlink.
- **Hand-off**: after checking out the target, the script hands over to that version's own `install.sh` to finish, so a release can change its own install steps.
- **Output**: `installed v0.1.0`, `updated v0.1.0 -> v0.2.0` or `already at v0.1.0`. If `GIT_SHADOW_BIN` isn't on PATH, or another `git-shadow` comes first on PATH, it says so and prints the line to add. It never edits shell startup files.
- Works on macOS and Linux with bash, git and perl only.

### `git shadow version` and `git shadow update`

- `version` prints `git describe --tags --always --dirty` for the clone the binary resolves into, so a development checkout shows something like `v0.1.0-3-g07c566a-dirty`.
- `update` runs that clone's `install.sh` in update mode: the same fetch, checkout and refusals, without touching the symlink. `GIT_SHADOW_REF` applies.

### Releases

- **Cutting a release**: a manually run workflow (`gh workflow run release-pr.yml -f bump=minor`) works out the next version from the newest tag (or `0.0.0`), moves the CHANGELOG's `[Unreleased]` entries under `## [X.Y.Z] - <date>`, leaves an empty `[Unreleased]` above it, and opens a pull request. An empty `[Unreleased]` stops it.
- **Publishing**: on a push to `main`, after the tests pass, CI reads the CHANGELOG's newest version heading. If it has no tag yet, CI creates the tag and a GitHub Release whose notes are that section. Otherwise it does nothing.
- Pull requests opened by a workflow don't trigger CI, so the release pull request has no checks. The tests still gate the release, because publishing runs only after they pass on `main`.

## Tests

End-to-end in `test/run.sh`, against a local fixture repo with tags (`GIT_SHADOW_REPO` set to a local path), never the network: fresh install, re-run with nothing new, update to a newer tag, `GIT_SHADOW_REF`, no tags, dirty clone, development checkout, adopting a managed clone elsewhere, `GIT_SHADOW_FORCE`, missing perl, old git, PATH warning, `version`, and `update`. The release scripts are tested too: `prepare-release.sh` moves the entries and refuses an empty `[Unreleased]`, and `publish-release.sh` releases a new version once, through the stub `gh`. The workflows themselves aren't tested.
