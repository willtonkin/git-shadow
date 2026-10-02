# Decision map maintenance (`git shadow ctx`)

Status: needs-triage

Captured during the grilling for `git shadow onboard`, and kept separate from it: onboarding stays generic, and the decision map is an opt-in convention layered on top.

## Idea

A `git shadow ctx` command that maintains a decision map: a YAML file in the shadow repo linking path globs (and optionally symbol names) in tracked code to the ADRs, glossary terms and constraints that apply to them. Tracked code never cites ADR ids or paths; comments state their reason in plain English, and the map is the bridge.

## Prior art

The convention has been used by hand, as rules in an agent prompt.

**Entry schema**, under a top-level `entries:` list:

- `match`: path globs, relative to the repo root
- `symbols`: names within those files that the entry is about (optional)
- `adrs`: ADR file names
- `terms`: glossary terms (optional)
- `see`: other shadow-repo files worth reading, by accepted path (optional)
- `note`: what holds and why, readable without opening the ADR

**Maintenance rules for agents:**

- Before editing or reviewing code, check for entries whose `match` covers the file, read the listed ADRs and terms, and respect each `note`. If a change would contradict an ADR, stop and say so.
- Update the map when an ADR is recorded, superseded or reversed, when referenced files or symbols move, or when a constraint someone could undo by accident is introduced.
- Match by glob and symbol name, never by line number. Keep entries narrow, and keep each `note` to one sentence of what and why.
- Code comments never cite ADR ids or the map, and they explain the why in plain English.
- Flag and fix entries whose glob hits no files or whose symbol no longer exists.

**Validation:** every `match` glob hits a file, every ADR file exists, every listed symbol occurs in the matched files, and every `see` path resolves.

## Open questions

To grill before building. Not yet decided:

- What `ctx` does: validate only, look up which entries cover a path, or edit entries.
- Where maps live, and whether there's one per context.
- Whether a YAML dependency is acceptable, since git-shadow needs only bash, git and perl today.
- How it interacts with branch areas, since a map is a record and so can be a proposal.
