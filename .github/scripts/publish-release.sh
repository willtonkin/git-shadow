#!/usr/bin/env bash
# publish-release.sh: if CHANGELOG.md's newest version heading has no tag yet,
# tag the current commit and create a GitHub Release with that section as notes.
set -euo pipefail

version=$(perl -ne 'if (/^## \[(\d+\.\d+\.\d+)\]/) { print $1; exit }' CHANGELOG.md)
if [ -z "$version" ]; then echo "nothing to release: CHANGELOG.md has no version heading"; exit 0; fi
if git rev-parse -q --verify "refs/tags/v$version" >/dev/null; then echo "v$version is already released"; exit 0; fi

notes=$(mktemp)
V=$version perl -0777 -ne 'print $1 if /^## \[\Q$ENV{V}\E\][^\n]*\n(.*?)(?=^## \[|\z)/ms' CHANGELOG.md > "$notes"
gh release create "v$version" --target "$(git rev-parse HEAD)" --title "v$version" --notes-file "$notes"
