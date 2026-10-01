# Name the command `git-shadow`

`shadow` is also the name of Linux's shadow-utils package (`/etc/shadow`, `passwd`, `useradd`), so it clashes in Homebrew, apt and the AUR and is hard to search for. We named the command `git-shadow` before the first release, which also lets git run it as `git shadow`. The concept is still called the **shadow repo**, and `SHADOW_HOME`, the `.shadow` manifest and `.branch-shadow` keep their names, so only the binary, the package and the README change, and no user has anything to migrate.
