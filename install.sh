#!/usr/bin/env bash
# Install or update git-shadow:
#
#   curl -fsSL https://raw.githubusercontent.com/willtonkin/git-shadow/main/install.sh | bash
#
# Clones git-shadow, checks out its newest release, and symlinks bin/git-shadow
# onto your PATH. Running it again updates. Settings, from the environment:
#   GIT_SHADOW_DIR    the clone (default ${XDG_DATA_HOME:-$HOME/.local/share}/git-shadow)
#   GIT_SHADOW_BIN    the directory for the symlink (default $HOME/.local/bin)
#   GIT_SHADOW_REF    a tag or branch to check out instead of the newest release
#   GIT_SHADOW_REPO   where to clone from
#   GIT_SHADOW_FORCE  1 replaces a git-shadow in GIT_SHADOW_BIN that isn't a managed install
#
# A managed clone is detached with no uncommitted changes to tracked files; it's
# the only kind this ever moves. A clone on a branch is a development checkout.
#
# `git shadow update` runs the clone's copy with --update, which leaves the
# symlink alone. Once the target is checked out, this hands over to the
# target's own copy with --finish <install|update> <old version>, so a release
# can change its own install steps: keep that interface working across versions.
set -euo pipefail

REPO=${GIT_SHADOW_REPO:-https://github.com/willtonkin/git-shadow.git}
DIR=${GIT_SHADOW_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/git-shadow}
BIN=${GIT_SHADOW_BIN:-$HOME/.local/bin}
REF=${GIT_SHADOW_REF:-}
FORCE=${GIT_SHADOW_FORCE:-}

say() { echo "git-shadow: $*"; }
die() { echo "git-shadow: $*" >&2; exit 1; }

real_path() { perl -MCwd=abs_path -e 'my $p = abs_path(shift); print $p if defined $p' "$1"; }

check_requirements() {
  command -v git >/dev/null || die "git 2.31 or newer is required"
  command -v perl >/dev/null || die "perl is required"
  local v
  v=$(git --version | awk '{ print $3 }')
  awk -F. -v v="$v" 'BEGIN { split(v, n, "."); exit !(n[1] > 2 || (n[1] == 2 && n[2] >= 31)) }' \
    || die "git 2.31 or newer is required; found $v"
}

# is_clone <dir>: is <dir> the top of a git-shadow clone?
is_clone() { [ -f "$1/bin/git-shadow" ] && [ -e "$1/.git" ]; }

# unmanaged_reason <dir>: why the clone at <dir> isn't managed, if it isn't
unmanaged_reason() {
  local branch
  if branch=$(git -C "$1" symbolic-ref -q --short HEAD); then
    echo "a development checkout (on $branch)"
  elif [ -n "$(git -C "$1" status --porcelain --untracked-files=no)" ]; then
    echo "a clone with uncommitted changes"
  fi
}

# adopt_existing: if $BIN/git-shadow already runs a managed clone other than
# $DIR, update that one instead; refuse to replace anything else without FORCE
adopt_existing() {
  local link="$BIN/git-shadow" real clone reason what
  [ -e "$link" ] || [ -L "$link" ] || return 0
  what="isn't a git-shadow install"
  if [ -L "$link" ]; then
    real=$(real_path "$link")
    clone=$(dirname "$(dirname "${real:-/}")")
    if [ -n "$real" ] && is_clone "$clone"; then
      [ "$clone" = "$(real_path "$DIR")" ] && return 0
      reason=$(unmanaged_reason "$clone")
      if [ -z "$reason" ]; then DIR=$clone; return 0; fi
      what="runs $clone, which is $reason"
    fi
  fi
  [ "$FORCE" = 1 ] && return 0
  die "$link $what. Set GIT_SHADOW_FORCE=1 to replace it with a managed install in $DIR."
}

# pick_target <dir>: the ref to check out, GIT_SHADOW_REF's or the newest release
pick_target() {
  local tag
  if [ -n "$REF" ]; then
    if git -C "$1" rev-parse -q --verify "refs/tags/$REF^{commit}" >/dev/null; then
      echo "refs/tags/$REF"
    elif git -C "$1" rev-parse -q --verify "refs/remotes/origin/$REF^{commit}" >/dev/null; then
      echo "refs/remotes/origin/$REF"
    else
      die "there's no tag or branch called $REF"
    fi
    return
  fi
  tag=$(git -C "$1" tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)
  [ -n "$tag" ] || die "there are no releases yet; set GIT_SHADOW_REF=main for the latest development version"
  echo "refs/tags/$tag"
}

version_of() { git -C "$1" describe --tags --always 2>/dev/null || true; }

fetch_and_checkout() {
  local mode=$1 before="" fresh="" reason target
  check_requirements
  [ "$mode" = update ] || adopt_existing
  if [ -e "$DIR" ]; then
    is_clone "$DIR" || die "$DIR isn't a git-shadow clone; move it, or set GIT_SHADOW_DIR to install somewhere else"
    reason=$(unmanaged_reason "$DIR")
    [ -z "$reason" ] || die "$DIR is $reason. Update it with git yourself, or set GIT_SHADOW_DIR to install somewhere else."
    before=$(version_of "$DIR")
    git -C "$DIR" fetch -q --tags --force origin
  else
    fresh=1
    mkdir -p "$(dirname "$DIR")"
    git clone -q --no-checkout "$REPO" "$DIR"
  fi
  if ! target=$(pick_target "$DIR"); then
    [ -z "$fresh" ] || rm -rf "$DIR"
    exit 1
  fi
  git -C "$DIR" -c advice.detachedHead=false checkout -q --detach "$target"
  GIT_SHADOW_DIR=$DIR GIT_SHADOW_BIN=$BIN exec bash "$DIR/install.sh" --finish "$mode" "$before"
}

finish() {
  local mode=$1 before=$2 now found
  now=$(version_of "$DIR")
  if [ "$mode" = install ]; then
    mkdir -p "$BIN"
    # An adopted clone's link already works; leave it as the user wrote it.
    [ "$(real_path "$BIN/git-shadow")" = "$(real_path "$DIR/bin/git-shadow")" ] \
      || ln -sfn "$DIR/bin/git-shadow" "$BIN/git-shadow"
  fi
  if [ -z "$before" ]; then say "installed $now in $DIR"
  elif [ "$before" = "$now" ]; then say "already at $now"
  else say "updated $before -> $now"
  fi
  [ "$mode" = install ] || return 0
  case ":$PATH:" in
    *":$BIN:"*)
      found=$(command -v git-shadow || true)
      [ "$found" = "$BIN/git-shadow" ] || say "another git-shadow comes first on your PATH: $found"
      ;;
    *)
      say "$BIN isn't on your PATH. Open a new shell, or add this to your shell's startup file:"
      echo "  export PATH=\"$BIN:\$PATH\""
      ;;
  esac
  command -v gh >/dev/null || say "optional: install gh (https://cli.github.com) so git-shadow can tell which pull requests were merged"
  return 0
}

# Everything runs from here, so a piped script is read in full before it starts.
main() {
  case ${1:-} in
    --finish) finish "$2" "${3:-}" ;;
    --update) fetch_and_checkout update ;;
    "") fetch_and_checkout install ;;
    *) die "usage: install.sh" ;;
  esac
}

main "$@"
