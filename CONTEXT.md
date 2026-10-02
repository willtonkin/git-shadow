# shadow

Keeps one person's untracked working files for a project in a private repo of their own, and links them into every checkout of the project.

## Repos and checkouts

**Project repo**:
The repo your team shares, whose checkouts the files are linked into.
_Avoid_: main repo, host repo, upstream

**Shadow repo**:
Your private, local repo that holds the linked files and their history for one project repo.
_Avoid_: personal repo, overlay

**Checkout**:
Any working tree of the project repo, whether it's the main one or one added as a git worktree.
_Avoid_: worktree (except when naming git's command), clone

**Trunk**:
The project repo's main line of development, recorded in the manifest.
_Avoid_: default branch, base branch

## Linking

**Manifest**:
The shadow repo's list of what to link and how, and which project repo it belongs to.
_Avoid_: config, settings

**Link**:
A path in a checkout that points at the same path in the shadow repo.
_Avoid_: mount, overlay

**Adopt**:
To move an untracked file already sitting at a linked path into the shadow repo and replace it with a link.
_Avoid_: import, capture

**Decline**:
To record that a project repo should never be offered a shadow repo.

**Onboard**:
To bring a project repo under a shadow repo, moving its existing personal files in and leaving the project repo free of them.
_Avoid_: migrate, set up

## Per-branch files

**Branch area**:
The part of the shadow repo that holds one branch's proposals.
_Avoid_: area (on its own), per-branch files, branch shadow

**Branch link**:
The link in a checkout that points at the current branch's branch area.

**Proposal**:
A file in a branch area that isn't yet shared with every checkout.
_Avoid_: draft, per-branch file

**Accepted path**:
The shared location, visible from every checkout, that a proposal is promoted to when it stops being a proposal.
_Avoid_: shared path, main path

**Record**:
A file meant to outlive the branch that wrote it, such as an ADR, a glossary or a runbook. On a branch, a new record is a proposal in the branch area, and it reaches its accepted path when the branch is promoted.
_Avoid_: promotable file, durable state

**Working file**:
A file that belongs to a piece of work rather than a branch, such as a spec, an issue or scratch notes. It lives at a link, never in a branch area, and is closed out by hand when the work is done.
_Avoid_: working state, scratch file

**Promote**:
To move a branch area's proposals onward: to their accepted paths, or into another branch's branch area, usually after a rename.
_Avoid_: accept, merge, publish, move, rename

**Drop**:
To discard a branch area and its proposals.
_Avoid_: delete, discard

**Gone**:
Describes a branch area whose recorded branch no longer exists locally. A renamed branch leaves its old branch area gone.
_Avoid_: stale, orphaned

**Merged**:
Describes a branch area whose branch's work has reached the trunk, whether or not the branch still exists locally.
_Avoid_: landed, shipped, done

**Open**:
Describes a branch area whose branch has an open pull request into the trunk.
_Avoid_: in review, pr-open, pending

**Closed**:
Describes a branch area whose branch's pull request into the trunk was closed without merging.
_Avoid_: abandoned, rejected
