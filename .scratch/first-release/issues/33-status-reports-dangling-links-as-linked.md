# `status` reports dangling links as "linked"

Category: bug
Status: needs-triage

## Problem

`git shadow status` shows `linked` for a link whose target doesn't exist in the shadow repo. The symlink in the checkout dangles, so opening the file fails, but nothing in the output says so. A broken setup looks healthy, so manifest mistakes go unnoticed, and agents trust `status` and then hit "file not found".

The `onboard` state block shares the same code (`print_link_states`), so it reports these links as `linked` too.

## Steps to reproduce

1. Add `link docs/notes/TODO.md` to the manifest.
2. Run `git shadow sync`. The checkout gets `docs/notes/TODO.md -> $SHADOW_HOME/<repo>/docs/notes/TODO.md`.
3. Leave `$SHADOW_HOME/<repo>/docs/notes/TODO.md` missing. In the original report, the file only existed in a branch area, at `branches/<slug>/docs/notes/TODO.md`.
4. Run `git shadow status`.

**Expected:** the entry is flagged, e.g. `docs/notes/TODO.md   dangling (target missing)`.

**Actual:** `docs/notes/TODO.md   linked`, while `[ -e docs/notes/TODO.md ]` fails.

## Cause

Confirmed in the code: `print_link_states` decides `linked` from `is_our_link`, which only checks `[ -L ]` and compares `readlink` with the expected target. It never checks `[ -e ]`.

## Suggested fix

- Report a separate state when the link is ours but its target is missing, e.g. `dangling (target missing)`, in both `status` and `onboard`.
- If a branch area holds a file at that path, hint at it: "branch area `<slug>` has this file; it reaches this path when that branch is promoted".
- Optionally, have `sync` warn when it creates or keeps a link to a missing file. A folder link is fine, since `sync` creates the folder.
- Optionally, have `status` exit non-zero when anything dangles, so scripts and hooks can catch it.

## Notes

The setup in the original report was also wrong: files declared as plain `link`s only existed in a branch area. `link` paths are the accepted paths, so those files only appear once the branch is promoted. The onboarding prompt already warns about this, but `status` should make it visible.

## Comments

`print_link_states` now reports `dangling (target missing)` when a link is ours but `[ -e ]` fails, in both `status` and `onboard`. Under each dangling link it names any branch area with a proposal (a file, not a folder: `sync` creates empty per-branch folders in every branch area) at that path. If the path sits directly in a `numbered` per-branch path, promoting renames the file, so the hint says it lands elsewhere instead. The numbering rule moved out of `promote_to_accepted` into `numbered_dir` so both places share it. Tests cover the dangling state (file and folder links), the hint, its absence for empty folders, and the numbered wording.

Not done (both optional): a `sync` warning for links to missing files, and a non-zero `status` exit. Linking a file before writing it is a normal workflow, and `hook-start` prints sync output into every session, so the warning would be noise there. Done.
