#!/usr/bin/env bash
# usage: ci/gate.sh <dungeon-dir> <den-src> [template...]  -> one line per gate: <name> OK|FAIL
# Each gate evaluates Den's template twice (den=<den-src> vs den=<dungeon-dir>) and compares drvPaths.
set -u
W=$(realpath "$1") S=$(realpath "$2"); shift 2
cd "$W"
[ "$(bash ci/run.sh | tr -d '\n' | md5sum | cut -c1-32)" = "$(tr -d '\n' < ci/tier1.expected | md5sum | cut -c1-32)" ] && echo "tier1 OK" || echo "tier1 FAIL"
for t in "$@"; do
  case $t in
    bogus) (ulimit -v 12582912; timeout 300 nix run nixpkgs#nix-unit -- --override-input den "path:$W" --flake "path:$S/templates/bogus#.tests.bogus" 2>&1) | grep -q '1/1 successful' && echo "bogus OK" || echo "bogus FAIL"; continue ;;
    noflake) a=$(bash ci/noflake.sh "$S" "$S"); b=$(bash ci/noflake.sh "$S" "$W")
      [ -n "$a" ] && [ "$a" = "$b" ] && echo "noflake OK" || echo "noflake FAIL"; continue ;;
  esac
  # ci/<T>.ignore (optional): attr names excluded on both sides (den-diagram packages are out of goal).
  ig() { if [ -f "ci/$t.ignore" ]; then grep -vwFf "ci/$t.ignore"; else cat; fi; }
  sel() { grep -E '^\S+ (/nix|ERR|etc:)' | ig; }
  a=$(bash ci/templates.sh "$t" "$S" "$S" | sel); b=$(bash ci/templates.sh "$t" "$S" "$W" | sel)
  [ -n "$a" ] && [ "$a" = "$b" ] && echo "$t OK" || echo "$t FAIL"
done
