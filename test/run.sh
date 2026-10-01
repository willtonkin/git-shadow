#!/usr/bin/env bash
# End-to-end tests for shadow. Each test runs in a fresh temp dir with an
# isolated git config and SHADOW_HOME. Usage: test/run.sh [test-name...]
set -euo pipefail

SHADOW_BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/shadow"
PASS=0 FAIL=0

shadow() { "$SHADOW_BIN" "$@"; }

fail() { echo "    $*" >&2; return 1; }
assert_link() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] || fail "expected $1 -> $2, got $(readlink "$1" 2>/dev/null || echo 'no link')"; }
assert_file() { [ -f "$1" ] || fail "expected file $1"; }
assert_missing() { [ ! -e "$1" ] && [ ! -L "$1" ] || fail "expected $1 to be absent"; }
assert_contains() { grep -qF -- "$2" <<< "$1" || fail "expected output to contain: $2"$'\n'"got: $1"; }
assert_not_contains() { ! grep -qF -- "$2" <<< "$1" || fail "expected output not to contain: $2"; }
assert_clean() { [ -z "$(git status --porcelain)" ] || fail "expected clean git status, got: $(git status --porcelain)"; }

# setup: a code repo `r` on main with an origin remote, plus SHADOW_HOME
setup() {
  T=$(mktemp -d)
  export SHADOW_HOME="$T/home"
  export GIT_CONFIG_GLOBAL="$T/gitconfig" GIT_CONFIG_NOSYSTEM=1
  git config --global user.name test
  git config --global user.email test@example.com
  git config --global init.defaultBranch main
  git init -q "$T/r"
  cd "$T/r"
  git remote add origin git@github.com:acme/thing.git
  echo x > tracked.md
  git add . && git commit -qm init
}

manifest() { printf '%s\n' "$@" >> "$SHADOW_HOME/thing/.shadow"; }

test_repo_key_normalises_remote_forms() {
  local url
  for url in git@github.com:acme/thing.git https://github.com/acme/thing ssh://git@github.com:22/acme/thing.git; do
    git remote set-url origin "$url"
    assert_contains "$(shadow init 2>&1; rm -rf "$SHADOW_HOME")" "created $SHADOW_HOME/thing"
  done
}

test_unknown_repo_asks_once_then_respects_decline() {
  assert_contains "$(echo '{}' | shadow hook-start)" "has no shadow repo"
  shadow decline >/dev/null
  [ -z "$(echo '{}' | shadow hook-start)" ] || fail "expected no output after decline"
}

test_hooks_are_silent_outside_git() {
  cd "$T"
  [ -z "$(echo '{}' | shadow hook-start)" ] || fail "expected no output outside a repo"
  echo '{}' | shadow hook-end
}

test_sync_adopts_untracked_files_and_skips_tracked_ones() {
  echo mine > AGENTS.md
  shadow init >/dev/null
  manifest 'link AGENTS.md' 'link tracked.md' 'link CONTEXT.md' 'link .scratch/'
  local out; out=$(shadow sync 2>&1)
  assert_contains "$out" "adopted AGENTS.md"
  assert_contains "$out" "skipped tracked.md: tracked"
  assert_link AGENTS.md "$SHADOW_HOME/thing/AGENTS.md"
  assert_file "$SHADOW_HOME/thing/AGENTS.md"
  assert_link .scratch "$SHADOW_HOME/thing/.scratch"
  assert_clean
}

test_writing_through_dangling_link_lands_in_shadow() {
  shadow init >/dev/null
  manifest 'link CONTEXT.md'
  shadow sync
  echo ctx > CONTEXT.md
  assert_file "$SHADOW_HOME/thing/CONTEXT.md"
}

test_worktrees_share_one_copy_and_one_exclude() {
  git worktree add -q ../wt -b feat/one
  shadow init >/dev/null
  manifest 'link .scratch/'
  shadow sync --all 2>/dev/null
  echo spec > .scratch/spec.md
  assert_file ../wt/.scratch/spec.md
  cd ../wt && assert_clean
}

test_removing_a_line_prunes_links_and_empty_parents() {
  shadow init >/dev/null
  manifest 'link docs/agents/a.md' 'link docs/agents/b.md'
  shadow sync
  sed -i.bak '/docs\/agents/d' "$SHADOW_HOME/thing/.shadow"
  manifest 'link docs/agents/'
  shadow sync
  assert_link docs/agents "$SHADOW_HOME/thing/docs/agents"
}

test_sync_never_overwrites_a_conflicting_untracked_file() {
  shadow init >/dev/null
  manifest 'link notes.md'
  echo theirs > "$SHADOW_HOME/thing/notes.md"
  echo mine > notes.md
  assert_contains "$(shadow sync 2>&1)" "merge by hand"
  [ "$(cat notes.md)" = mine ] || fail "local file was changed"
}

test_autocommit_on_session_end() {
  shadow init >/dev/null
  manifest 'link .scratch/' 'autocommit on'
  shadow sync
  echo spec > .scratch/spec.md
  echo '{}' | shadow hook-end
  assert_contains "$(git -C "$SHADOW_HOME/thing" log --oneline)" "chore: sync from main"
}

test_context_files_are_printed_at_session_start() {
  shadow init >/dev/null
  manifest 'context AGENTS.md'
  echo 'hello agent' > "$SHADOW_HOME/thing/AGENTS.md"
  assert_contains "$(echo '{}' | shadow hook-start)" "hello agent"
}

test_per_branch_areas_are_isolated_and_skip_trunk() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'per-branch docs/adr/ numbered' 'trunk main'
  shadow sync
  assert_missing .branch-shadow
  assert_contains "$(echo '{}' | shadow hook-start)" "trunk branch (main)"
  git worktree add -q ../a -b feat/a && git worktree add -q ../b -b feat/b
  (cd ../a && shadow sync && echo a > .branch-shadow/docs/adr/a.md)
  (cd ../b && shadow sync)
  assert_link ../a/.branch-shadow "$SHADOW_HOME/thing/branches/feat~a"
  assert_missing ../b/.branch-shadow/docs/adr/a.md
  (cd ../a && assert_clean)
}

test_detached_head_gets_no_area() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/' 'trunk other'
  shadow sync
  assert_link .branch-shadow "$SHADOW_HOME/thing/branches/main"
  git checkout -q --detach
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "detached HEAD"
  assert_missing .branch-shadow
}

test_gone_branches_are_reported_and_empty_ones_removed() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/' 'trunk main'
  git worktree add -q ../a -b feat/a && git worktree add -q ../b -b feat/b
  (cd ../a && shadow sync && echo a > .branch-shadow/docs/adr/a.md)
  (cd ../b && shadow sync)
  git worktree remove ../a && git branch -qD feat/a
  git worktree remove ../b && git branch -qD feat/b
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "feat/a (1 files)"
  assert_not_contains "$out" "feat/b"
  assert_missing "$SHADOW_HOME/thing/branches/feat~b"
}

test_promote_numbers_files_and_rewrites_links() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'per-branch docs/adr/ numbered' 'trunk main' 'autocommit on'
  shadow sync
  echo old > docs/adr/0001-old.md
  git worktree add -q ../a -b feat/a
  (cd ../a && shadow sync \
    && echo 'see [b](b.md)' > .branch-shadow/docs/adr/a.md \
    && echo b > .branch-shadow/docs/adr/b.md)
  shadow promote feat/a >/dev/null
  assert_file docs/adr/0002-a.md
  assert_file docs/adr/0003-b.md
  assert_contains "$(cat docs/adr/0002-a.md)" "(0003-b.md)"
  assert_missing "$SHADOW_HOME/thing/branches/feat~a"
  assert_contains "$(git -C "$SHADOW_HOME/thing" log --oneline)" "promote per-branch files from feat/a"
}

test_promote_aborts_on_clash_without_moving_anything() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'per-branch docs/adr/' 'trunk main'
  shadow sync
  echo accepted > docs/adr/a.md
  git worktree add -q ../a -b feat/a
  (cd ../a && shadow sync && echo proposed > .branch-shadow/docs/adr/a.md)
  ! shadow promote feat/a 2>/dev/null || fail "expected promote to fail"
  [ "$(cat docs/adr/a.md)" = accepted ] || fail "accepted file was overwritten"
  assert_file "$SHADOW_HOME/thing/branches/feat~a/docs/adr/a.md"
}

test_promote_into_moves_area_to_renamed_branch() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/' 'trunk main'
  git worktree add -q ../a -b feat/a
  (cd ../a && shadow sync && echo a > .branch-shadow/docs/adr/a.md)
  shadow promote feat/a --into feat/renamed >/dev/null
  assert_file "$SHADOW_HOME/thing/branches/feat~renamed/docs/adr/a.md"
  assert_contains "$(cat "$SHADOW_HOME/thing/branches/feat~renamed/.branch")" "feat/renamed"
}

test_drop_deletes_area() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/' 'trunk main'
  git worktree add -q ../a -b feat/a
  (cd ../a && shadow sync && echo a > .branch-shadow/docs/adr/a.md)
  shadow drop feat/a >/dev/null
  assert_missing "$SHADOW_HOME/thing/branches/feat~a"
}

tests=("$@")
[ ${#tests[@]} -gt 0 ] || tests=($(declare -F | awk '$3 ~ /^test_/ { print $3 }'))
for t in "${tests[@]}"; do
  # Not under `if`: errexit is ignored there, and a failed assert must stop the test.
  set +e
  ( set -e; setup; "$t" ) > "${TMPDIR:-/tmp}/shadow-test.log" 2>&1
  rc=$?
  set -e
  if [ "$rc" = 0 ]; then
    PASS=$((PASS + 1)); echo "ok   $t"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $t"; sed 's/^/     /' "${TMPDIR:-/tmp}/shadow-test.log"
  fi
done
echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
