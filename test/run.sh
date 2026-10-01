#!/usr/bin/env bash
# End-to-end tests for git-shadow. Each test runs in a fresh temp dir with its
# own HOME (so git config can't reach the developer's real one) and
# SHADOW_HOME. Usage: test/run.sh [test-name...]
set -euo pipefail

SHADOW_BIN="$(cd "$(dirname "$0")/.." && pwd)/bin/git-shadow"
PROJECT=thing  # the test remote's repo name, so also the shadow repo's name
PASS=0 FAIL=0
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

shadow() { "$SHADOW_BIN" "$@"; }

fail() { echo "    $*" >&2; return 1; }
assert_link() { [ -L "$1" ] && [ "$(readlink "$1")" = "$2" ] || fail "expected $1 -> $2, got $(readlink "$1" 2>/dev/null || echo 'no link')"; }
assert_file() { [ -f "$1" ] || fail "expected file $1"; }
assert_missing() { [ ! -e "$1" ] && [ ! -L "$1" ] || fail "expected $1 to be absent"; }
assert_contains() { grep -qF -- "$2" <<< "$1" || fail "expected output to contain: $2"$'\n'"got: $1"; }
assert_not_contains() { ! grep -qF -- "$2" <<< "$1" || fail "expected output not to contain: $2"; }
# assert_clean [repo]: no uncommitted changes in <repo> (default: the current one)
assert_clean() { [ -z "$(git -C "${1:-.}" status --porcelain)" ] || fail "expected clean git status in ${1:-.}, got: $(git -C "${1:-.}" status --porcelain)"; }
# assert_pending <path>: <path> has uncommitted changes in the shadow repo
assert_pending() { [ -n "$(git -C "$SHADOW_REPO" status --porcelain -- "$1")" ] || fail "expected $1 to stay uncommitted in the shadow repo"; }

# setup: a code repo `r` on main with an origin remote, plus SHADOW_HOME.
# HOME and XDG_CONFIG_HOME isolate global config on every git version;
# GIT_CONFIG_GLOBAL alone is ignored before git 2.32.
setup() {
  T=$(mktemp -d)
  export HOME="$T" XDG_CONFIG_HOME="$T/.config"
  export GIT_CONFIG_GLOBAL="$T/.gitconfig" GIT_CONFIG_NOSYSTEM=1
  export SHADOW_HOME="$T/home"
  SHADOW_REPO="$SHADOW_HOME/$PROJECT"
  git config --global user.name test
  git config --global user.email test@example.com
  git config --global init.defaultBranch main
  # A stub gh that fails until a test gives it pull requests (gh_prs), so the
  # suite never reaches GitHub.
  mkdir "$T/bin"
  cat > "$T/bin/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$T/gh-args"
[ -f "$T/gh-prs.json" ] || exit 1
cat "$T/gh-prs.json"
EOF
  chmod +x "$T/bin/gh"
  export PATH="$T/bin:$PATH"
  git init -q "$T/r"
  cd "$T/r"
  git remote add origin "git@github.com:acme/$PROJECT.git"
  echo x > tracked.md
  git add . && git commit -qm init
}

manifest() { printf '%s\n' "$@" >> "$SHADOW_REPO/.shadow"; }

# gh_prs <branch>:<STATE>...: make the stub gh list one pull request into the
# trunk per argument, newest first, as `gh pr list --json` prints them.
gh_prs() {
  local pr sep="" merged
  for pr; do
    merged=null; [ "${pr#*:}" = MERGED ] && merged='"2026-09-30T12:00:00Z"'
    printf '%s{"headRefName":"%s","mergedAt":%s,"state":"%s"}' "$sep" "${pr%:*}" "$merged" "${pr#*:}"
    sep=,
  done | { printf '['; cat; printf ']\n'; } > "$T/gh-prs.json"
}

# delete_branch <dir> <branch>: remove a worktree and its branch, leaving the branch area gone
delete_branch() { git worktree remove --force "$1" && git branch -qD "$2"; }

# commit_on <dir> <file>: commit a new file in the checkout at <dir>
commit_on() { echo "$2" > "$1/$2" && git -C "$1" add "$2" && git -C "$1" commit -qm "$2"; }

# branch_checkout <dir> <branch>: a new worktree on a new branch, synced so it
# has its branch link.
branch_checkout() {
  git worktree add -q "$1" -b "$2"
  (cd "$1" && shadow sync)
}

# branch_with_proposal <dir> <branch> <proposal>: as branch_checkout, plus one
# proposal at <proposal> (relative to the branch area).
branch_with_proposal() {
  branch_checkout "$1" "$2"
  echo "$3" > "$1/.branch-shadow/$3"
}

test_repo_key_normalises_remote_forms() {
  local url
  for url in "git@github.com:acme/$PROJECT.git" "https://github.com/acme/$PROJECT" "ssh://git@github.com:22/acme/$PROJECT.git"; do
    git remote set-url origin "$url"
    assert_contains "$(shadow init 2>&1; rm -rf "$SHADOW_HOME")" "created $SHADOW_REPO"
  done
}

test_runs_as_a_git_subcommand_when_on_path() {
  local out; out=$(PATH="$(dirname "$SHADOW_BIN"):$PATH" git shadow init)
  assert_contains "$out" "created $SHADOW_REPO"
  assert_contains "$out" "git shadow sync --all"
}

test_init_without_a_remote_names_shadow_repo_after_the_checkout() {
  git remote remove origin
  # With no remote, the shadow repo is named after the checkout's folder.
  SHADOW_REPO="$SHADOW_HOME/$(basename "$PWD")"
  assert_contains "$(shadow init)" "created $SHADOW_REPO"
  manifest 'link notes.md'
  shadow sync
  assert_link notes.md "$SHADOW_REPO/notes.md"
}

test_init_from_another_checkout_still_names_shadow_repo_after_the_first() {
  git remote remove origin
  git worktree add -q ../wt -b feat/one
  cd ../wt
  assert_contains "$(shadow init)" "created $SHADOW_HOME/r"  # setup's first checkout is r
}

test_init_rejects_names_that_lookups_would_skip() {
  local name out
  for name in .hidden a/b; do
    out=$(shadow init "$name" 2>&1) && fail "expected init $name to fail"
    assert_contains "$out" "pass a different name"
    assert_missing "$SHADOW_HOME/$name"
  done
}

test_init_link_adopts_files_from_the_checkout_it_runs_in() {
  git worktree add -q ../wt -b feat/one
  echo theirs > ../wt/AGENTS.md
  echo mine > AGENTS.md
  mkdir -p .scratch docs/agents && echo spec > .scratch/spec.md && echo t > docs/agents/triage.md
  local out; out=$(shadow init --link AGENTS.md --link .scratch/ --link docs/agents 2>&1)
  assert_contains "$out" "adopted AGENTS.md"
  assert_link AGENTS.md "$SHADOW_REPO/AGENTS.md"
  assert_link .scratch "$SHADOW_REPO/.scratch"
  assert_link docs/agents "$SHADOW_REPO/docs/agents"
  [ "$(cat "$SHADOW_REPO/AGENTS.md")" = mine ] || fail "expected this checkout's copy to be kept"
  assert_file "$SHADOW_REPO/.scratch/spec.md"
  local m; m=$(cat "$SHADOW_REPO/.shadow")
  assert_contains "$m" "link    AGENTS.md"
  assert_contains "$m" "link    .scratch/"
  assert_contains "$m" "link    docs/agents/"
  assert_clean
}

test_init_link_refuses_paths_it_cant_link() {
  local p out
  for p in . ./ .git .git/hooks /etc/x ../x a/../../x; do
    out=$(shadow init --link "$p" 2>&1) && fail "expected init --link $p to fail"
    assert_contains "$out" "give a path inside the checkout, outside .git"
    assert_missing "$SHADOW_REPO"
  done
}

test_init_link_takes_a_name_too() {
  echo mine > AGENTS.md
  shadow init mine --link AGENTS.md >/dev/null 2>&1
  assert_link AGENTS.md "$SHADOW_HOME/mine/AGENTS.md"
}

test_init_records_the_trunk_from_origin_head() {
  git branch -q develop
  git update-ref refs/remotes/origin/develop develop
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/develop
  shadow init >/dev/null
  assert_contains "$(cat "$SHADOW_REPO/.shadow")" "trunk   develop"
}

test_init_falls_back_to_the_default_branch_setting_then_main_or_master() {
  shadow init >/dev/null  # setup sets init.defaultBranch to main
  assert_contains "$(cat "$SHADOW_REPO/.shadow")" "trunk   main"
  rm -rf "$SHADOW_HOME"
  git config --global --unset init.defaultBranch
  git branch -qm master
  shadow init >/dev/null
  assert_contains "$(cat "$SHADOW_REPO/.shadow")" "trunk   master"
}

test_init_without_a_trunk_warns_and_branch_areas_stay_off() {
  git config --global --unset init.defaultBranch
  git branch -qm dev
  local out; out=$(shadow init 2>&1)
  assert_contains "$out" "couldn't find the trunk"
  ! grep -q '^trunk' "$SHADOW_REPO/.shadow" || fail "expected no trunk line in the manifest"
  manifest 'per-branch docs/adr/'
  assert_contains "$(shadow sync 2>&1)" "branch areas are off until"
  assert_missing .branch-shadow
  out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "branch areas are off until"
  assert_not_contains "$out" "put NEW files"
  assert_missing "$SHADOW_REPO/branches"
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
  assert_link AGENTS.md "$SHADOW_REPO/AGENTS.md"
  assert_file "$SHADOW_REPO/AGENTS.md"
  assert_link .scratch "$SHADOW_REPO/.scratch"
  assert_clean
}

test_writing_through_dangling_link_lands_in_shadow() {
  shadow init >/dev/null
  manifest 'link CONTEXT.md'
  shadow sync
  echo ctx > CONTEXT.md
  assert_file "$SHADOW_REPO/CONTEXT.md"
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
  sed -i.bak '/docs\/agents/d' "$SHADOW_REPO/.shadow"
  manifest 'link docs/agents/'
  shadow sync
  assert_link docs/agents "$SHADOW_REPO/docs/agents"
}

test_sync_never_overwrites_a_conflicting_untracked_file() {
  shadow init >/dev/null
  manifest 'link notes.md'
  echo theirs > "$SHADOW_REPO/notes.md"
  echo mine > notes.md
  assert_contains "$(shadow sync 2>&1)" "merge by hand"
  [ "$(cat notes.md)" = mine ] || fail "local file was changed"
}

test_autocommit_on_session_end_names_no_branch() {
  shadow init >/dev/null
  manifest 'link .scratch/' 'autocommit on'
  branch_checkout ../wt feat/one
  echo spec > ../wt/.scratch/spec.md
  (cd ../wt && echo '{}' | shadow hook-end)
  [ "$(git -C "$SHADOW_REPO" log --format=%s)" = "chore: sync at session end" ] \
    || fail "expected one commit, 'chore: sync at session end', got: $(git -C "$SHADOW_REPO" log --format=%s)"
  assert_clean "$SHADOW_REPO"
}

test_context_files_are_printed_at_session_start() {
  shadow init >/dev/null
  manifest 'context AGENTS.md'
  echo 'hello agent' > "$SHADOW_REPO/AGENTS.md"
  assert_contains "$(echo '{}' | shadow hook-start)" "hello agent"
}

test_per_branch_areas_are_isolated_and_skip_trunk() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'per-branch docs/adr/ numbered'
  shadow sync
  assert_missing .branch-shadow
  assert_contains "$(echo '{}' | shadow hook-start)" "trunk branch (main)"
  branch_with_proposal ../a feat/a docs/adr/a.md
  branch_checkout ../b feat/b
  assert_link ../a/.branch-shadow "$SHADOW_REPO/branches/feat~a"
  assert_missing ../b/.branch-shadow/docs/adr/a.md
  (cd ../a && assert_clean)
}

test_detached_head_gets_no_area() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/' 'trunk other'
  shadow sync
  assert_link .branch-shadow "$SHADOW_REPO/branches/main"
  git checkout -q --detach
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "detached HEAD"
  assert_missing .branch-shadow
}

test_gone_branches_are_reported_and_empty_ones_removed() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  branch_checkout ../b feat/b
  git worktree remove ../a && git branch -qD feat/a
  git worktree remove ../b && git branch -qD feat/b
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "feat/a (1 files)"
  assert_not_contains "$out" "feat/b"
  assert_missing "$SHADOW_REPO/branches/feat~b"
}

test_session_start_recommends_promoting_a_branch_merged_per_gh() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  delete_branch ../a feat/a
  gh_prs feat/a:MERGED
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "merged into the trunk (main)"
  assert_contains "$out" "feat/a (1 files)"
  assert_contains "$out" "promote <branch>"
  assert_not_contains "$out" "no longer exist"
  assert_contains "$(cat "$T/gh-args")" "pr list --state all --base main --json headRefName,state,mergedAt --limit 200"
}

test_session_start_recommends_promoting_a_merged_branch_that_still_exists() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  gh_prs feat/a:MERGED
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "merged into the trunk (main)"
  assert_contains "$out" "feat/a (1 files)"
}

test_session_start_recommends_dropping_a_gone_branch_whose_pr_was_closed() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  delete_branch ../a feat/a
  gh_prs feat/a:CLOSED
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "closed without merging"
  assert_contains "$out" "feat/a (1 files)"
  assert_contains "$out" "drop <branch>"
  assert_not_contains "$out" "promote <branch>"
}

test_session_start_is_silent_about_a_gone_branch_with_an_open_pr() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  delete_branch ../a feat/a
  gh_prs feat/a:OPEN
  assert_not_contains "$(echo '{}' | shadow hook-start)" "feat/a"
}

test_session_start_goes_by_a_branchs_most_recent_pr() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  branch_with_proposal ../b feat/b docs/adr/b.md
  delete_branch ../b feat/b
  # Newest first: feat/a was reopened after a merge; feat/b merged after a closed attempt.
  gh_prs feat/a:OPEN feat/b:MERGED feat/a:MERGED feat/b:CLOSED
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "feat/b (1 files)"
  assert_not_contains "$out" "feat/a"
  assert_not_contains "$out" "closed without merging"
}

test_session_start_asks_about_a_gone_branch_with_no_pr() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  delete_branch ../a feat/a
  gh_prs feat/other:MERGED
  local out; out=$(echo '{}' | shadow hook-start)
  assert_contains "$out" "no longer exist"
  assert_contains "$out" "feat/a (1 files)"
  assert_not_contains "$out" "merged into the trunk"
}

test_session_start_matches_prs_to_non_ascii_branch_names() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/café docs/adr/a.md
  gh_prs feat/café:MERGED
  assert_contains "$(echo '{}' | shadow hook-start)" "feat/café (1 files)"
}

test_without_gh_a_branch_in_origin_trunk_counts_as_merged() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  commit_on ../a code.txt
  git update-ref refs/remotes/origin/main feat/a  # merged upstream, not fetched into main
  local out; out=$(echo '{}' | shadow hook-start)  # setup's stub gh fails
  assert_contains "$out" "merged into the trunk (main)"
  assert_contains "$out" "feat/a (1 files)"
}

test_without_gh_a_branch_rebased_into_origin_trunk_counts_as_merged() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  commit_on ../a code.txt
  commit_on . other.txt
  git cherry-pick feat/a >/dev/null
  git update-ref refs/remotes/origin/main main
  assert_contains "$(echo '{}' | shadow hook-start)" "merged into the trunk (main)"
}

test_without_gh_a_new_branch_with_no_commits_is_not_merged() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  git update-ref refs/remotes/origin/main main
  branch_with_proposal ../a feat/a docs/adr/a.md
  assert_not_contains "$(echo '{}' | shadow hook-start)" "merged"
}

test_a_gh_that_hangs_falls_back_to_ancestry() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  commit_on ../a code.txt
  git update-ref refs/remotes/origin/main feat/a
  printf '#!/usr/bin/env bash\nsleep 30\n' > "$T/bin/gh"
  local start=$SECONDS out
  out=$(echo '{}' | SHADOW_GH_TIMEOUT=1 shadow hook-start)
  [ $((SECONDS - start)) -lt 10 ] || fail "expected hook-start to give up on gh"
  assert_contains "$out" "merged into the trunk (main)"
}

test_status_shows_pr_states_and_where_they_came_from() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  branch_with_proposal ../b feat/b docs/adr/b.md
  branch_with_proposal ../c feat/c docs/adr/c.md
  branch_checkout ../d feat/d
  delete_branch ../c feat/c
  gh_prs feat/a:MERGED feat/b:OPEN feat/c:CLOSED feat/d:MERGED
  local out; out=$(cd ../a && shadow status)
  assert_contains "$out" "feat/a                                             current, merged (gh)  1 files"
  assert_contains "$out" "feat/b                                             exists, open (gh)     1 files"
  assert_contains "$out" "feat/c                                             gone, closed (gh)     1 files"
  # With no proposals, a branch area isn't checked.
  assert_contains "$out" "feat/d                                             exists                0 files"
}

test_status_shows_merges_found_without_gh() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  commit_on ../a code.txt
  git update-ref refs/remotes/origin/main feat/a
  assert_contains "$(shadow status)" "exists, merged (ancestry)"
}

test_promote_a_merged_branch_that_is_still_checked_out() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'per-branch docs/adr/'
  shadow sync
  branch_with_proposal ../a feat/a docs/adr/a.md
  gh_prs feat/a:MERGED
  shadow promote feat/a >/dev/null
  assert_file docs/adr/a.md
  # The next sync gives the branch a fresh, empty branch area, which isn't reported.
  (cd ../a && shadow sync)
  assert_link ../a/.branch-shadow "$SHADOW_REPO/branches/feat~a"
  assert_not_contains "$(cd ../a && echo '{}' | shadow hook-start)" "merged into the trunk"
  # A file written after the merge is offered again, until a new pull request is opened.
  echo late > ../a/.branch-shadow/docs/adr/late.md
  assert_contains "$(cd ../a && echo '{}' | shadow hook-start)" "merged into the trunk"
  gh_prs feat/a:OPEN feat/a:MERGED
  assert_not_contains "$(cd ../a && echo '{}' | shadow hook-start)" "feat/a ("
}

test_promote_numbers_files_rewrites_links_and_commits() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'per-branch docs/adr/ numbered'
  shadow sync
  echo old > docs/adr/0001-old.md
  branch_checkout ../a feat/a
  echo 'see [b](b.md)' > ../a/.branch-shadow/docs/adr/a.md
  echo b > ../a/.branch-shadow/docs/adr/b.md
  shadow promote feat/a >/dev/null
  assert_file docs/adr/0002-a.md
  assert_file docs/adr/0003-b.md
  assert_contains "$(cat docs/adr/0002-a.md)" "(0003-b.md)"
  assert_missing "$SHADOW_REPO/branches/feat~a"
  assert_contains "$(git -C "$SHADOW_REPO" log --oneline)" "promote branch area feat/a to accepted paths"
}

test_promote_rewrites_references_from_outside_the_promoted_set() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'link .scratch/' 'per-branch docs/adr/ numbered'
  shadow sync
  echo 'see [a](../docs/adr/a.md)' > .scratch/spec.md
  branch_with_proposal ../a feat/a docs/adr/a.md
  branch_checkout ../b feat/b
  echo 'builds on a.md' > ../b/.branch-shadow/docs/adr/b.md
  git -C "$SHADOW_REPO" add -A && git -C "$SHADOW_REPO" commit -qm setup
  shadow promote feat/a >/dev/null
  assert_file docs/adr/0001-a.md
  assert_contains "$(cat .scratch/spec.md)" "(../docs/adr/0001-a.md)"
  assert_contains "$(cat ../b/.branch-shadow/docs/adr/b.md)" "builds on 0001-a.md"
  # The rewrite is part of the promotion, so it's in the promote commit.
  assert_contains "$(git -C "$SHADOW_REPO" show --stat --format= HEAD)" "branches/feat~b/docs/adr/b.md"
}

test_promote_leaves_names_that_only_share_an_ending_alone() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'link notes.md' 'per-branch docs/adr/ numbered'
  shadow sync
  echo 'old-tokens.md, tokens.md, session-tokens.md.' > notes.md
  branch_with_proposal ../a feat/a docs/adr/tokens.md
  echo s > ../a/.branch-shadow/docs/adr/session-tokens.md
  shadow promote feat/a >/dev/null
  # Proposals are numbered in name order: session-tokens.md, then tokens.md.
  [ "$(cat notes.md)" = 'old-tokens.md, 0002-tokens.md, 0001-session-tokens.md.' ] \
    || fail "unexpected rewrite: $(cat notes.md)"
}

test_promote_leaves_a_rewrite_to_a_file_with_pending_changes_uncommitted() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'link notes.md' 'per-branch docs/adr/ numbered'
  shadow sync
  echo notes > notes.md
  git -C "$SHADOW_REPO" add -A && git -C "$SHADOW_REPO" commit -qm setup
  echo 'half-written, see a.md' >> notes.md
  branch_with_proposal ../a feat/a docs/adr/a.md
  local out; out=$(shadow promote feat/a 2>&1)
  assert_contains "$(cat notes.md)" "see 0001-a.md"
  assert_contains "$out" "rewrote references in notes.md but left it uncommitted"
  assert_pending notes.md
}

test_promote_leaves_references_to_a_shared_name_alone() {
  shadow init >/dev/null
  manifest 'link docs/' 'per-branch docs/adr/ numbered' 'per-branch docs/rfc/ numbered'
  shadow sync
  mkdir docs/adr && echo old > docs/adr/0001-old.md
  branch_with_proposal ../a feat/a docs/adr/a.md
  mkdir -p ../a/.branch-shadow/docs/rfc && echo 'see ../adr/a.md' > ../a/.branch-shadow/docs/rfc/a.md
  local out; out=$(shadow promote feat/a 2>&1)
  # The two a.md proposals get different new names, so neither rewrite is safe.
  assert_file docs/adr/0002-a.md
  assert_contains "$(cat docs/rfc/0001-a.md)" "see ../adr/a.md"
  assert_contains "$out" "left references to a.md as they were"
}

test_promote_aborts_on_clash_without_moving_anything() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'per-branch docs/adr/'
  shadow sync
  echo accepted > docs/adr/a.md
  branch_with_proposal ../a feat/a docs/adr/a.md
  ! shadow promote feat/a 2>/dev/null || fail "expected promote to fail"
  [ "$(cat docs/adr/a.md)" = accepted ] || fail "accepted file was overwritten"
  assert_file "$SHADOW_REPO/branches/feat~a/docs/adr/a.md"
}

test_promote_into_moves_area_to_renamed_branch_and_commits() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  shadow promote feat/a --into feat/renamed >/dev/null
  assert_file "$SHADOW_REPO/branches/feat~renamed/docs/adr/a.md"
  assert_contains "$(cat "$SHADOW_REPO/branches/feat~renamed/.branch")" "feat/renamed"
  assert_contains "$(git -C "$SHADOW_REPO" log --oneline)" "promote branch area feat/a into feat/renamed"
}

test_promote_into_succeeds_after_rename_creates_empty_area() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  # The usual rename: the next session's sync makes an empty area for the new name.
  (cd ../a && git branch -m feat/renamed && shadow sync)
  shadow promote feat/a --into feat/renamed >/dev/null
  assert_file ../a/.branch-shadow/docs/adr/a.md
  assert_contains "$(cat "$SHADOW_REPO/branches/feat~renamed/.branch")" "feat/renamed"
  assert_missing "$SHADOW_REPO/branches/feat~a"
}

test_promote_into_adds_proposals_when_no_paths_collide() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  branch_with_proposal ../b feat/b docs/adr/b.md
  shadow promote feat/a --into feat/b >/dev/null
  assert_file ../b/.branch-shadow/docs/adr/a.md
  assert_file ../b/.branch-shadow/docs/adr/b.md
  assert_contains "$(cat "$SHADOW_REPO/branches/feat~b/.branch")" "feat/b"
  assert_missing "$SHADOW_REPO/branches/feat~a"
  assert_contains "$(git -C "$SHADOW_REPO" log --oneline)" "promote branch area feat/a into feat/b"
}

# branch_areas_snapshot: every file under the shadow repo's branches/, with its contents
branch_areas_snapshot() {
  (cd "$SHADOW_REPO/branches" && find . | sort | while read -r f; do
    echo "== $f"; [ -f "$f" ] && cat "$f"; done)
}

test_promote_into_refuses_colliding_paths_and_changes_nothing() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  branch_with_proposal ../b feat/b docs/adr/b.md
  echo theirs > ../b/.branch-shadow/docs/adr/a.md
  local before out
  before=$(branch_areas_snapshot)
  out=$(shadow promote feat/a --into feat/b 2>&1) && fail "expected promote to fail"
  assert_contains "$out" "docs/adr/a.md"
  [ "$(branch_areas_snapshot)" = "$before" ] || fail "branch areas changed"
}

test_promote_into_refuses_when_a_folder_is_a_file_there() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  mkdir ../a/.branch-shadow/docs/adr/x && echo y > ../a/.branch-shadow/docs/adr/x/y.md
  branch_with_proposal ../b feat/b docs/adr/x
  local before; before=$(branch_areas_snapshot)
  shadow promote feat/a --into feat/b 2>/dev/null && fail "expected promote to fail"
  [ "$(branch_areas_snapshot)" = "$before" ] || fail "branch areas changed"
}

test_drop_keeps_branch_area_in_history() {
  shadow init >/dev/null
  manifest 'per-branch docs/adr/'
  branch_with_proposal ../a feat/a docs/adr/a.md
  assert_contains "$(shadow drop feat/a)" "recoverable"
  assert_missing "$SHADOW_REPO/branches/feat~a"
  local path='branches/feat~a/docs/adr/a.md' removed
  removed=$(git -C "$SHADOW_REPO" log -n1 --format=%H -- "$path")
  [ -n "$removed" ] || fail "expected $path in the shadow repo's history"
  # branch_with_proposal writes each proposal's own path as its content.
  assert_contains "$(git -C "$SHADOW_REPO" show "$removed^:$path")" "docs/adr/a.md"
}

# pending_note_and_proposal: autocommit on, a branch feat/a with a proposal, and
# an unrelated note left uncommitted in the shadow repo.
pending_note_and_proposal() {
  shadow init >/dev/null
  manifest 'link docs/adr/' 'link notes.md' 'per-branch docs/adr/' 'autocommit on'
  shadow sync
  branch_with_proposal ../a feat/a docs/adr/a.md
  echo half-written > notes.md
}

test_drop_leaves_unrelated_changes_uncommitted() {
  pending_note_and_proposal
  shadow drop feat/a >/dev/null
  assert_pending notes.md
}

test_promote_leaves_unrelated_changes_uncommitted() {
  pending_note_and_proposal
  shadow promote feat/a >/dev/null
  assert_pending notes.md
}

test_promote_commits_only_the_named_proposal_not_glob_matches() {
  pending_note_and_proposal
  echo '[1]' > '../a/.branch-shadow/docs/adr/b[1].md'
  echo accepted-later > docs/adr/b1.md
  shadow promote feat/a >/dev/null
  assert_pending docs/adr/b1.md
}

test_promote_into_leaves_unrelated_changes_uncommitted() {
  pending_note_and_proposal
  shadow promote feat/a --into feat/renamed >/dev/null
  assert_pending notes.md
}

tests=("$@")
# A read loop, not mapfile: macOS's bash 3.2 doesn't have it.
if [ ${#tests[@]} = 0 ]; then
  while read -r t; do tests+=("$t"); done < <(declare -F | awk '$3 ~ /^test_/ { print $3 }')
fi
for t in "${tests[@]}"; do
  # Not under `if`: errexit is ignored there, and a failed assert must stop the test.
  set +e
  ( set -e; setup; "$t" ) > "$LOG" 2>&1
  rc=$?
  set -e
  if [ "$rc" = 0 ]; then
    PASS=$((PASS + 1)); echo "ok   $t"
  else
    FAIL=$((FAIL + 1)); echo "FAIL $t"; sed 's/^/     /' "$LOG"
  fi
done
echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" = 0 ]
