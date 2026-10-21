#!/usr/bin/env bash
# usage: ci/status.sh <gate.out> <deadbugs.tsv>  -> ci/status.json (results README is generated from)
set -eu
cd "$(dirname "$0")/.."
jq -n --rawfile g "$1" --rawfile d "$2" --arg rev "$(tr -d '\n' < ci/den-rev)" '{
  denRev: $rev,
  entries: ($g | split("\n") | map(select(test("^\\S+ (OK|FAIL)")) | split(" ") | {key: .[0], value: .[1]}) | from_entries),
  deadbugs: { pass: ($d | split("\n") | map(select(test("\tPASS\t"))) | length), total: ($d | split("\n") | map(select(length > 0)) | length),
    # test cells summed over all suites (N/M column of the TSV)
    tests: ($d | split("\n") | map(select(length > 0) | split("\t")[2] | select(test("^[0-9]+/[0-9]+$")) | split("/") | map(tonumber)) | { pass: (map(.[0]) | add), total: (map(.[1]) | add) }) }
}' > ci/status.json
