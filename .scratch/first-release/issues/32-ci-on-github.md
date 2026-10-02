# 32: CI on GitHub

**What to build:** Every change is checked by shellcheck and the test suite on macOS and Linux, so the README can honestly claim both. Covers issue 02, plus the bash 5 check from issue 20. See `.scratch/first-release/spec.md` (CI).

**Blocked by:** 31, and a GitHub remote for the project (to be created by the maintainer)

**Status:** done

- [x] A GitHub Actions workflow runs shellcheck over the CLI and the test suite.
- [x] The workflow runs the test suite on Ubuntu (a modern bash) and macOS (bash 3.2).
- [x] Any shellcheck findings are fixed or explicitly suppressed with a reason.
- [x] After the first green run, the README says the tool is tested on macOS and Linux.

## Comments

Workflow written at `.github/workflows/ci.yml`: shellcheck first, then the suite on `ubuntu-latest` and on `macos-latest` with `/bin` first on PATH, so the `env bash` shebang gets bash 3.2. Checked locally: shellcheck (Docker `koalaman/shellcheck:stable`) is clean; the suite passes on macOS bash 3.2 and in Docker `bash:5` (5.3). bash 5 found a real bug: `${1//\//~}` in `branch_slug` tilde-expands the `~` to `$HOME` from bash 5.2, so branch areas got the wrong path. Fixed.

First GitHub run (36919783549) failed shellcheck: two SC2015 infos in `test/run.sh`'s `assert_link` and `assert_missing` (shellcheck 0.9.0 on the runner; the local Docker image was clean). Fixed by grouping the compound tests in braces. Run 36919980942 is green on shellcheck, Ubuntu (bash 5.2.21) and macOS (bash 3.2.57). README now says tested on macOS and Linux. Done.
