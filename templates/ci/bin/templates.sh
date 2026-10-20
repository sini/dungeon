#!/usr/bin/env bash
# usage: templates/ci/bin/templates.sh <template> <den-dir>  (from repo root)
# prints one line per system output: <attr> <drvPath|ERR msg>
set -u
t=$1 den=$(realpath "$2")
ulimit -v 12582912
timeout 600 nix eval --no-write-lock-file --override-input den "path:$den" --raw \
  "path:$PWD/templates/$t#." --apply '
  f: let
    drv = k: v: let r = builtins.tryEval (builtins.unsafeDiscardStringContext v.drvPath); in
      "${k} ${if r.success then r.value else "ERR"}\n";
    out = set: sel: builtins.concatStringsSep "" (map (n: drv n (sel set.${n})) (builtins.attrNames set));
    get = n: f.${n} or { };
    # hosts whose toplevel throws on Den too (assertions, unfree): compare etc instead.
    os = c: let t = c.config.system.build.toplevel; in if (builtins.tryEval t.drvPath).success then t else { drvPath = "etc:" + c.config.system.build.etc.drvPath; };
  in out (get "nixosConfigurations") os
   + out (get "darwinConfigurations") (c: c.config.system.build.toplevel)
   + out (get "homeConfigurations") (c: c.activationPackage)
   + out ((get "packages").x86_64-linux or { }) (p: p)' 2>&1
