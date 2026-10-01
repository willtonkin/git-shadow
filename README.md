# shadow

Keep personal, untracked files for a repo (agent instructions, specs, decision records, notes) in a separate **local** git repo, and symlink them into every checkout and worktree of that repo.

Your team never sees them. Every worktree sees the same copy. They have their own history.

```
~/shadow/my-app/                 ← the shadow repo (plain git, no remote needed)
├── .shadow                      ← manifest
├── AGENTS.md
├── docs/agents/
└── .scratch/

~/code/my-app/                   ← any checkout or worktree
├── AGENTS.md   → ~/shadow/my-app/AGENTS.md
├── docs/agents → ~/shadow/my-app/docs/agents
└── .scratch    → ~/shadow/my-app/.scratch
```

The links are hidden from `git status` through a managed block in `.git/info/exclude`, which git shares across all worktrees. Nothing in the repo's tracked files changes.

## Why

Tools that keep their working state in the repo, like agent skills, spec-driven workflows or personal ADRs, assume everyone on the team uses them. If you're the only one:

- **committing the files** pushes your workflow onto the team;
- **leaving them untracked** means each worktree has its own copy, and they vanish when the worktree is removed;
- **a global location** breaks tools that expect the files at fixed paths inside the repo.

shadow keeps the files at the paths the tools expect, while storing them somewhere only you use.

## Install

Requires bash, git 2.31+ and perl. Tested on macOS; it should run anywhere those are available.

```sh
git clone <this repo> ~/code/shadow
ln -s ~/code/shadow/bin/shadow ~/.local/bin/shadow   # anywhere on your PATH
```

Shadow repos live in `~/shadow/` by default. Set `SHADOW_HOME` to change that.

## Quick start

```sh
cd ~/code/my-app
shadow init                       # creates ~/shadow/my-app/ with a manifest
$EDITOR ~/shadow/my-app/.shadow   # add link lines
shadow sync --all                 # link into every worktree of this repo
```

Any untracked files already at a linked path are moved into the shadow repo and replaced with a link. Run `init` in the checkout where you already have them.

## The manifest

`<shadow>/.shadow`, one directive per line, `#` for comments:

```
match      github.com/acme/my-app       # repo identity (filled in by `init`)
link       AGENTS.md                    # symlink a file
link       .scratch/                    # trailing / = directory
per-branch docs/adr/ numbered           # per-branch area for new files (see below)
trunk      main                         # default: origin/HEAD
context    AGENTS.md                    # print into agent context at session start
autocommit on                           # commit the shadow repo when a session ends
```

**`match`** is the normalised `origin` URL, so every clone and worktree of the repo is recognised, wherever it lives. A repo with no remote is matched by path instead, as `path:/abs/path/to/.git`.

**`link`** is the only list. The same entries drive the symlinks and the exclude block, so the two can't drift apart. Remove a line and the next `sync` removes that link, and any folders the link leaves empty.

## Commands

| Command | What it does |
|---|---|
| `shadow init [name]` | Create a shadow repo for the current repo and attach this checkout. By default it's named after the remote's repo, or the main checkout's folder if there's no remote. |
| `shadow sync [--all]` | Bring this checkout, or every worktree, in line with the manifest. Repeat runs are harmless. |
| `shadow status` | Show each link's state here, and every per-branch area. |
| `shadow promote <branch> [--into <new>]` | Move a branch's per-branch files into the accepted paths, or over to a renamed branch. |
| `shadow drop <branch>` | Drop a branch's branch area. Its proposals are committed first, so they stay recoverable from the shadow repo's history. |
| `shadow decline` | Never offer a shadow repo for the current repo. |
| `shadow hook-start` / `hook-end` | Entry points for agent session hooks (see below). |

## Safety

`sync` never overwrites or deletes anything it didn't create:

- **A tracked file** at a linked path is left alone, with a warning. If your team later commits its own `CONTEXT.md`, theirs wins.
- **An untracked file at a linked path, when the shadow repo already has its own copy**, is left alone, with a "merge by hand" warning.
- **A symlink pointing somewhere else** is left alone.
- **Pruning** only removes links that point into the shadow repo.

## Per-branch areas

Every checkout shares one copy of each linked path, which is usually what you want: a spec should be visible from every worktree that implements it. Some files, decision records especially, behave better with branch semantics: a proposal written on a spike shouldn't become "accepted" just by existing, and should go away if the spike does.

`per-branch <path>` gives each branch its own area for new files under that path:

```
~/shadow/my-app/
├── docs/adr/0001-….md                 ← accepted, shared by every checkout
└── branches/
    └── feat~new-auth/                 ← branch name, with / encoded as ~
        ├── .branch
        └── docs/adr/session-tokens.md ← proposed on feat/new-auth

checkout on feat/new-auth/
├── docs/adr       → ~/shadow/my-app/docs/adr
└── .branch-shadow → ~/shadow/my-app/branches/feat~new-auth
```

- **Each checkout sees only its own branch's area.**
- **The trunk branch gets no area**: new files there go straight to the accepted path.
- **A detached HEAD gets no area either.**
- **When a branch no longer exists locally**, its area is reported at session start, so you can decide what to do with it:
  - `shadow promote <branch>` moves the files into the accepted paths. With `numbered`, files get the next `NNNN-` prefix, and references to them are rewritten to match in every text file in the shadow repo. Only whole file names match, so promoting `tokens.md` leaves `session-tokens.md` alone.
  - `shadow promote <branch> --into <new>` moves the branch area to a renamed branch. If `<new>` has no branch area yet, or one with no proposals (as a session on the renamed branch creates), the old branch area takes its place. If `<new>` already has proposals, the old ones join them, unless a path appears in both: then it refuses and changes nothing, and you resolve it by hand.
  - `shadow drop <branch>` commits the branch area as it stands, then drops it, so its proposals stay in the shadow repo's history.
- **Areas with no files are removed** without asking.

`promote` and `drop` always commit to the shadow repo, whatever `autocommit` says, so its history records every promotion and drop. Each commit contains only the paths that command touched; any other changes you have pending in the shadow repo stay uncommitted.

"No longer exists" means the local branch was deleted. It doesn't depend on detecting merges, so it works the same with squash merges and needs no network access.

## Agent integration (Claude Code)

Add both hooks to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [{ "hooks": [{ "type": "command", "command": "shadow hook-start" }] }],
    "SessionEnd":   [{ "hooks": [{ "type": "command", "command": "shadow hook-end" }] }]
  }
}
```

Use an absolute path if `shadow` isn't on the PATH your hooks run with.

**At session start, `hook-start`:**

- in a repo with a shadow repo:
  - syncs this checkout, so new worktrees are linked automatically;
  - prints the manifest's `context` files and the per-branch instructions into the session;
  - lists any per-branch areas whose branch is gone;
- in a repo without one, tells the agent to ask you, once, whether to run `shadow init` or `shadow decline`;
- outside git, or in a declined repo, does nothing.

**At session end, `hook-end`** commits all pending changes in the shadow repo if `autocommit on` is set and anything changed. The commit message is always `chore: sync at session end`: several sessions can share one shadow repo, so it doesn't claim the changes came from any one branch or checkout.

Hooks can't stop and wait for an answer, so every question goes through the agent: the hook adds a note to the context, and the agent asks you in conversation. The hooks themselves never run `init`, `promote` or `drop`.

Other agents or editors can use the same entry points. Both read and discard stdin, and `hook-start` writes its context to stdout.

## Limitations

- **Tools that refuse to follow symlinks** won't see the files.
- **A checkout is only linked once something runs `sync` there.** The `SessionStart` hook does this when a session starts; `sync --all` does every worktree at once.
- **A branch switch mid-session** leaves that session's per-branch instructions out of date until the next session.
- **Numbering on promote** only applies to files directly inside a `numbered` path.
- **No "not yet" answer:** a gone branch is reported in every session until you promote or drop it.

## Development

```sh
test/run.sh                 # all tests
test/run.sh test_drop_keeps_branch_area_in_history
```

Each test runs in a fresh temp directory with an isolated git config and `SHADOW_HOME`.

## License

MIT
