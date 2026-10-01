# Merge detection for branch areas

Status: done
Blocked by: first-release

See `CONTEXT.md` (merged, open, closed, gone) and `docs/adr/0001-detect-merges-via-gh-with-local-fallback.md`.

## Problem

A branch area is only offered for promotion once its local branch is deleted. Merged work isn't offered until the branch is cleaned up, and a branch deleted while its PR is still open is reported in every session (#05 in `first-release`).

## Behaviour

**What counts:** merges into **trunk** only. Merges into other branches don't count; stacked branches still use `promote --into`.

**Which areas:** every branch area that has files, whether its branch still exists locally, is gone, or is checked out somewhere. Areas with no files are skipped (and removed, as today, if their branch is gone).

**Detection, in order:**

1. `gh`: one `gh pr list --state all --base <trunk> --json headRefName,state,mergedAt --limit 200` call with a short timeout, matched against area branch names locally. When several PRs share a head branch, use the most recent.
2. If `gh` is missing, not authenticated, times out or fails: ancestry (`git merge-base --is-ancestor <branch> origin/<trunk>`), then patch-id (`git cherry origin/<trunk> <branch>`). No fetch.
3. Otherwise: the existing rule (branch deleted = gone).

**Classification and `hook-start` report:**

| Branch | PR state | Report |
|---|---|---|
| merged (exists or gone) | merged | recommend `promote` |
| gone | closed, not merged | recommend `drop` |
| gone | open | silent |
| gone | no PR / no gh | as today: ask promote / `--into` / drop |

The hooks still never run `promote` or `drop`; the agent asks the user.

**`status`:** branch area states gain `merged`, `open` and `closed`. States combine where needed (`current, merged`). Show where the merge answer came from (`gh` or `ancestry`).

**Promoting a merged branch that is still checked out** is allowed. The next `sync` recreates an empty area for it. A file written there after the merge will be offered for promotion again; the user can drop it. A new PR from the same branch reads as open, which clears this.

## Out of scope

- Automatic promote (may become a manifest setting later, once detection is trusted).
- Fetching before detection.
- Forges other than GitHub.

## Done when

- Tests cover each row of the table, the `gh`-unavailable fallback (stub `gh` on PATH), ancestry-only detection, and the still-checked-out promote case.
- README: update the "Per-branch areas" section (the "doesn't depend on detecting merges" paragraph) and remove or narrow the "No 'not yet' answer" limitation; note the optional `gh` dependency under Install.

## Comments

Implemented in `bin/git-shadow` (`pr_states`, `merged_locally`, `branch_area_answers`, `report_branch_areas`, `cmd_status`), with tests in `test/run.sh` (the stub `gh` lives in `setup`). Decisions made along the way:

- **Fresh branches aren't merged by ancestry.** A branch still at the commit it was created on is trivially an ancestor of `origin/<trunk>`, so ancestry only counts once the branch has moved from its reflog's first entry. A branch with no reflog is never counted by ancestry. Patch-id is unaffected.
- **Local fallback is all or nothing.** It runs only when `gh` can't answer at all, as written. While `gh` works, a branch with no pull request falls through to the gone rule.
- **Sources.** Patch-id merges are labelled `ancestry` in `status`, since the spec names two sources.
- **Timeout.** `gh` gets 5 seconds, set by `SHADOW_GH_TIMEOUT` (used by the tests). On timeout its whole process group is killed.
- **Matching.** Pull requests are matched by head branch name only, so a fork's PR with the same branch name counts.
