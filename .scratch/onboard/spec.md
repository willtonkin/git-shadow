# Onboarding (`git shadow onboard`)

Status: ready-for-agent

See `CONTEXT.md` (onboard, record, working file). The decision map is a separate feature: `.scratch/decision-map/`.

## Problem

`init` creates a shadow repo and links paths you already know about. Most people arriving at git-shadow have personal agent files scattered through a project already, some of them tracked, and references to them in tracked code. Moving those in safely takes a dozen steps and several warnings that only show up the hard way. An agent can do it, given the right prompt and the current state.

## Behaviour

`git shadow onboard` prints a state block and then an agent prompt. The user pastes the output to their agent, or the agent runs it itself. It works with any agent harness, so it's a printed prompt rather than a skill.

**State block:**

- The repo key, and which state it's in:
  - **no shadow repo**: say so.
  - **declined**: print only that the repo was declined and how to undo it (remove its line from `$SHADOW_HOME/.declined`), then exit without the prompt.
  - **shadow repo exists**: its path, its manifest, and each link's state in this checkout (linked / missing / conflict), as `status` shows them. Missing links mean this checkout isn't synced.
- The trunk: the manifest's, or detected as `init` would (or "none found").
- Claude Code hooks: `hook-start` and `hook-end`, each `installed` or `not found`, from grepping `~/.claude/settings.json`, `.claude/settings.json` and `.claude/settings.local.json`.
- Candidate files, tracked or untracked, at any depth: `AGENTS.md`, `CLAUDE.md`, `CLAUDE.local.md`, `GEMINI.md`, `CONTEXT.md`, `CONTEXT-MAP.md`, `GLOSSARY.md`, `adr/`, `docs/agents/`, `.scratch/`, `.cursorrules`, `.cursor/rules/`. `.claude/` is excluded on purpose, since teams often commit `.claude/settings.json`. The names are kept in one list in the script. Paths that are already links into the shadow repo aren't listed.

**Prompt** (`prompts/onboard.md`, found by resolving the binary's symlink; a missing file is a clear error):

- Generic: it teaches git-shadow's model (shadow repo, manifest, link, trunk, branch area, proposal, accepted path, promote, hooks) and the record / working file distinction. There's no decision map, no contexts and no prescribed layout.
- Steps: explain the model → inventory (report before changing anything) → recommend a plan → carry it out → before committing → rules.
- Files stay at their current paths. Folders of numbered records get `per-branch <dir> numbered`, and working files stay at plain links.
- Changes to the project repo (untracking files, rewriting tracked references so they stand on their own) are a separately approved phase that ends in a branch or PR, never a commit to trunk.
- Keeps the hard-won warnings: don't `git reset` then `git add -A` over symlinks, check `git ls-files -s | awk '$1=="120000"'` after committing, sync refuses an untracked copy that exists in both places, a folder that still holds tracked files can't be linked, never claim hook behaviour that isn't confirmed, and merge differing copies instead of overwriting.

**`hook-start`**, with no shadow repo: ask the user whether to set one up, and if yes, run `git shadow onboard` and follow it. Declining is still offered.

**Docs:** an `onboard` line in `help`. Quick start in the README leads with `onboard`, with `init` as the manual path. A README section explains records vs working files.

## Tests

End-to-end in `test/run.sh`: each state (none, declined, exists but unsynced, set up), the candidate list, hook detection with a fake `$HOME/.claude/settings.json`, the prompt printing, and `hook-start` mentioning `onboard`. The prompt's wording isn't tested.
