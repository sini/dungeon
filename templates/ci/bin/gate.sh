#!/usr/bin/env bash
# usage: ci/gate.sh <dungeon-dir> <baseline-dir> [template...]  -> one line per gate: <name> OK|FAIL
# baseline-dir holds <T>.den files from `ci/templates.sh <T> <Den>`.
set -u
W=$(realpath "$1") B=$2; shift 2
cd "$W"
[ "$(bash ci/run.sh | tr -d '\n' | md5sum | cut -c1-32)" = "$(tr -d '\n' < "$W/ci/tier1.expected" | md5sum | cut -c1-32)" ] && echo "tier1 OK" || echo "tier1 FAIL"
(ulimit -v 12582912; timeout 300 nix run nixpkgs#nix-unit -- --override-input den "path:$W" --flake "path:$W/templates/bogus#.tests.bogus" 2>&1) | grep -q '1/1 successful' && echo "bogus OK" || echo "bogus FAIL"
nf=$(cd templates/noflake && ulimit -v 12582912 && timeout 600 nix eval --impure --raw --expr "let sources = import ./npins; o = import sources.with-inputs sources { den.outPath = $W; } (inputs: (inputs.nixpkgs.lib.evalModules { modules = [ (inputs.import-tree ./modules) ]; specialArgs = { inherit inputs; inherit (inputs) self; }; }).config); in o.flake.nixosConfigurations.igloo.config.system.build.toplevel.drvPath + \" \" + o.den.sh.drvPath" 2>/dev/null)
[ "$nf" = "/nix/store/jw8q9mb0wffh693piwmjj1jxdms2qd0y-nixos-system-nixos-26.05.19700101.dirty.drv /nix/store/hbqksadj72gjwa4f58mwdiyfrbnbil07-nix-shell.drv" ] && echo "noflake OK" || echo "noflake FAIL"
for t in "$@"; do
  o=$(ci/templates.sh "$t" "$W" | grep -E '^\S+ (/nix|ERR|etc:)')
  [ -n "$o" ] && [ "$o" = "$(grep -E '^\S+ (/nix|ERR|etc:)' "$B/$t.den")" ] && echo "$t OK" || echo "$t FAIL"
done
