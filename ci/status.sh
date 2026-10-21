#!/usr/bin/env bash
# usage: ci/status.sh <gate.out> <deadbugs.tsv>  -> ci/status.json (results README is generated from)
set -eu
cd "$(dirname "$0")/.."
jq -n --rawfile g "$1" --rawfile d "$2" --arg rev "$(tr -d '\n' < ci/den-rev)" '{
  denRev: $rev,
  entries: ($g | split("\n") | map(select(test("^\\S+ (OK|FAIL)")) | split(" ") | {key: .[0], value: .[1]}) | from_entries),
  deadbugs: { pass: ($d | split("\n") | map(select(test("\tPASS\t"))) | length), total: ($d | split("\n") | map(select(length > 0)) | length) }
}' > ci/status.json
