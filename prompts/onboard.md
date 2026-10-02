<!-- Printed by `git shadow onboard` after the state block, rather than shipped as
     a skill, so it works with any agent and stays versioned with the code it
     describes. Keep it in step with the README. -->

# Onboard this repository onto git-shadow

You are helping the user move their personal files for this project (agent
instructions, glossaries, ADRs, specs, issues, runbooks, scratch notes) out of
the project repo and into a **shadow repo** managed by `git-shadow`. Teach them
the model as you go, take an inventory, recommend a plan, and carry it out only
once they agree to it. The state block above was computed just now: start
from it, and don't take what it doesn't say for granted.

## The model: explain this to the user first, briefly

- **Shadow repo**: a separate, private git repo under `~/shadow/` (or
  `$SHADOW_HOME`), one per project repo. Nothing in it is committed to the
  project, shared with the team or reviewed.
- **Manifest** (`.shadow` in the shadow repo): what to link and how.
- **Link** (`link <path>`): a path in every checkout that points at the same
  path in the shadow repo. `git shadow sync` creates the links and hides them
  through `.git/info/exclude`. A trailing `/` marks a folder. Linking a file in
  a subfolder creates that folder in checkouts that don't have it.
- **Trunk** (`trunk <branch>`): the project's main line. With no trunk line,
  branch areas are off.
- **Branch area** (`per-branch <dir> [numbered]`): on any branch but the
  trunk, new files for `<dir>` go in `.branch-shadow/<dir>/`, which points at
  that branch's own area in the shadow repo. Files there are **proposals**.
  `numbered` gives each one the next `NNNN-` prefix, counted per folder, when
  it's promoted. Write proposals without a prefix.
- **Accepted path**: where a proposal ends up, visible from every checkout.
  It's the same path without `.branch-shadow/`, and it must be a link,
  or checkouts won't see what's promoted there.
- **Promote** (`git shadow promote <branch>`) moves **everything** in a branch
  area to its accepted paths. **Drop** (`git shadow drop <branch>`) discards a
  branch area, keeping it in the shadow repo's history.
- **Two kinds of file.** This distinction decides what goes under `per-branch`:
  - **Records** should outlive the branch that wrote them: ADRs, glossaries,
    runbooks, deferred-work lists. On a branch, a new record is a proposal in
    the branch area, **at exactly the path it will have once accepted**.
    Promoting then just moves it to where every checkout already looks.
  - **Working files** belong to a piece of work, not a branch: specs, issues,
    scratch notes. They live at a plain link, keyed by the work, because work
    outlives branch renames and merging a branch doesn't make its spec
    "accepted". They never go in a branch area, since promote would sweep
    them in with the records. When the work is done, its files are closed out
    by hand.
- **Session hooks** (Claude Code): `git-shadow hook-start` (SessionStart) syncs
  the checkout and prints the context and per-branch instructions;
  `git-shadow hook-end` (SessionEnd) commits the shadow repo if the manifest
  says `autocommit on`. The state block says whether they're installed. Never
  claim either behaviour unless they are.

## Step 1: Inventory

Report what you find before changing anything.

1. If there's a shadow repo, run `git shadow status` and look at its
   `git status` and `git log`. Note links that conflict, are missing, or point
   at nothing.
2. Start from the candidate files in the state block, then look for anything
   it missed: other agent configuration, personal docs, notes folders. For
   each item, note whether it's tracked, whether the trunk has it
   (`git ls-tree -r <trunk>`) or only this branch adds it, and whether the
   shadow repo already has a copy. If it does, diff the two.
3. For tracked items, find **every reference** to them in tracked content:
   code comments, configuration, CI messages, generated files and their
   sources, READMEs, the CHANGELOG. Search for the file names, their paths
   and identifiers like ADR numbers. Don't rely on `\b` in `git grep`: it's
   unreliable there.
4. Classify each item:
   - a **record** or a **working file**;
   - **personal** (only the user's tools read it) or **team-facing**:
     contribution rules, runbooks for shared systems and anything CI output
     points people to are team-facing.

## Step 2: Recommend a plan

Propose the manifest lines and where each item goes, then ask about anything
that needs a decision, recommending an answer for each.

- Keep files at the paths they have now. Moving them breaks references for
  no gain, and the user can reorganise later.
- Link each personal item, or the folder that holds several.
- Give each folder of records `per-branch <dir>`, with `numbered` if its files
  carry `NNNN-` prefixes, and make sure the folder itself is linked.
- Put working files at plain links, never under `per-branch`.
- Decisions to put to the user:
  - whether team-facing items should stay in the project repo (recommended:
    yes);
  - whether to set `trunk`, if the state block found none;
  - whether to give the shadow repo a remote (recommended: yes, since it may
    become the only copy of these files);
  - whether to turn on `autocommit` and install the hooks.
- If tracked items are moving, say that untracking them and rewriting their
  references is a separate phase (Step 4) that needs its own approval and
  ends in a branch or pull request on the project repo.

## Step 3: Set up the shadow repo

1. With no shadow repo, run `git shadow init`. `--link <path>` adopts an
   untracked file or folder there: it moves it into the shadow repo and
   leaves a link in its place.
2. Add the `trunk`, `link` and `per-branch` lines to the manifest, then run
   `git shadow sync`.
   - Sync refuses an untracked copy that exists both here and in the shadow
     repo. Merge the two by hand: never overwrite one with the other.
   - Sync skips a path the project repo still tracks, and a folder that still
     holds tracked files. Link a folder's untracked paths one by one, or add
     those lines in Step 4.
   - A link to a file that only exists in a branch area points at nothing
     until that branch is promoted. Warn the user.
3. Update the moved agent docs (such as `AGENTS.md`) to describe the model
   above. Wherever they say where a record goes, name its accepted path and
   add "under `.branch-shadow/` while on a branch".
4. Commit the shadow repo with a clear message.

## Step 4: Untrack files from the project repo (only with separate approval)

Skip this step if nothing tracked is moving. Otherwise, confirm with the user
first. Work on a branch, never directly on the trunk.

1. Untrack each item with `git rm --cached -r <path>`, which leaves it on
   disk. If the shadow repo already has a copy, merge this one into it and
   delete this one.
2. Run `git shadow sync`. It adopts each now-untracked item into the shadow
   repo and leaves a link in its place.
   **Don't `git reset` and then `git add -A`.** Once a path is a link, `add`
   records the symlink itself as a tracked file pointing into the user's home
   directory.
3. Remove `.gitignore` entries that the shadow exclude block now covers.
4. Rewrite each tracked reference to a moved file so it stands on its own:
   say the reason in plain English instead of pointing at a file the team
   can't see. Regenerate any generated files from their sources. Remove
   CHANGELOG entries that announce files the project no longer ships.
5. Run the project's checks (type-check, lint, tests and so on) and report
   any that fail.
6. Commit following the project's conventions, then check that nothing
   points into the shadow repo:
   `git ls-files -s | awk '$1=="120000"'` must list no links into it.
7. Offer to open a pull request, and draft a note for it saying the files
   moved to a personal shadow repo.

## Step 5: Wrap up

Say plainly what's left for the user to do, such as:

- installing the hooks (an agent usually can't edit its own harness settings);
- adding a remote to the shadow repo;
- running `git shadow sync --all` to link every other worktree.

## Rules

- Don't create, move or delete anything before the user has seen the
  inventory and agreed to the plan.
- Never overwrite a file you haven't read. Merge differing copies.
- Report outcomes faithfully: if a step was skipped, blocked or failed, say
  so.
