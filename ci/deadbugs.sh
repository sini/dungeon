#!/usr/bin/env bash
# usage: ci/deadbugs.sh <den-src> <den-impl-dir> <out.tsv> [suite...]
# Runs Den's own templates/ci flake (all of its modules) with input den = <den-impl-dir>.
# PASS iff rc==0 and "N/M successful" with M>0, N==M (0/0 is a false green).
set -u
src=$(realpath -e "$1") den=$(realpath -e "$2") out=$3; shift 3
den="path:$den"
if [ $# -gt 0 ]; then suites=("$@"); else
  mapfile -t suites < <(rg -oN --no-filename -r '$1' 'flake\.tests\.([A-Za-z0-9_-]+)' "$src"/templates/ci/modules/deadbugs/*.nix | sort -u)
fi
[ ${#suites[@]} -gt 0 ] || { echo "no suites" >&2; exit 2; }
scratch=$(mktemp -d); export den scratch src
one() {
  s=$1; log=$scratch/$s.log
  (ulimit -v 8388608; timeout 300 nix run nixpkgs#nix-unit -- --override-input den "$den" --flake "path:$src/templates/ci#.tests.$s" > "$log" 2>&1); rc=$?
  nm=$(grep -oE '[0-9]+/[0-9]+ successful' "$log" | tail -1 | grep -oE '^[0-9]+/[0-9]+')
  err=$(sed 's/\x1b\[[0-9;]*m//g' "$log" | grep -E 'error:.*[^ ]' | tail -1 | cut -c1-160 | tr '\t' ' ')
  st=ERROR
  if [ -n "$nm" ]; then
    n=${nm%/*}; m=${nm#*/}
    if [ "$rc" -eq 0 ] && [ "$m" -gt 0 ] && [ "$n" -eq "$m" ]; then st=PASS; else st=FAIL; fi
  fi
  printf '%s\t%s\t%s\t%s\n' "$s" "$st" "${nm:--}" "$err" > "$scratch/$s.row"
}
export -f one
printf '%s\n' "${suites[@]}" | xargs -P4 -I{} bash -c 'one {}'
: > "$out"
for s in "${suites[@]}"; do cat "$scratch/$s.row" >> "$out"; done
