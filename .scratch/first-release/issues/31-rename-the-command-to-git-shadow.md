# 31: Rename the command to `git-shadow`

**What to build:** The command is `git-shadow` and also runs as `git shadow`. The shadow repo concept, `SHADOW_HOME`, the manifest file name, the branch link name and the exclude-block markers keep their names, so nothing needs migrating. Covers issue 03. See `docs/adr/0002-name-the-command-git-shadow.md`.

**Blocked by:** 22, 23, 24, 25, 26, 27, 28, 29, 30

**Status:** done

- [x] The binary is `git-shadow`, and `git shadow <command>` works when it's on PATH.
- [x] Usage text, messages and suggested commands use the new name.
- [x] README and CHANGELOG use the new name, including the install and hook instructions.
- [x] The test harness calls the new binary, and the suite passes.
- [x] Nothing else is renamed.
