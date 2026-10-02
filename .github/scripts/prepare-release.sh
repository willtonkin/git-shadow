#!/usr/bin/env bash
# prepare-release.sh <major|minor|patch>: move CHANGELOG.md's [Unreleased]
# entries under a heading for the next version after the newest release tag
# (or 0.0.0), and print that version.
set -euo pipefail

latest=$(git tag --list 'v*' --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)
IFS=. read -r major minor patch <<< "${latest:-v0.0.0}"
major=${major#v}
case ${1:-} in
  major) major=$((major + 1)) minor=0 patch=0 ;;
  minor) minor=$((minor + 1)) patch=0 ;;
  patch) patch=$((patch + 1)) ;;
  *) echo "usage: $0 <major|minor|patch>" >&2; exit 2 ;;
esac
version="$major.$minor.$patch"

out=$(mktemp)
V=$version D=$(date -u +%Y-%m-%d) perl -0777 -ne '
  /^## \[Unreleased\][^\n]*\n(.*?)(?=^## \[|\z)/ms or die "CHANGELOG.md has no [Unreleased] section\n";
  $1 =~ /\S/ or die "CHANGELOG.md has nothing under [Unreleased] to release\n";
  s/^## \[Unreleased\][^\n]*\n/## [Unreleased]\n\n## [$ENV{V}] - $ENV{D}\n/m;
  print;
' CHANGELOG.md > "$out"
mv "$out" CHANGELOG.md
echo "$version"
