# apply-function for `nix eval --raw <flake>#. --apply`: one "<attr> <drvPath|ERR>" line per config.
# Same logic as templates/ci/bin/templates.sh (toplevel throws -> compare etc drv).
f: let
  drv = k: v: let r = builtins.tryEval (builtins.unsafeDiscardStringContext v.drvPath); in
    "${k} ${if r.success then r.value else "ERR"}\n";
  out = set: sel: builtins.concatStringsSep "" (map (n: drv n (sel set.${n})) (builtins.attrNames set));
  get = n: f.${n} or { };
  os = c: let t = c.config.system.build.toplevel; in
    if (builtins.tryEval t.drvPath).success then t else { drvPath = "etc:" + c.config.system.build.etc.drvPath; };
in out (get "nixosConfigurations") os
 + out (get "darwinConfigurations") (c: c.config.system.build.toplevel)
 + out (get "homeConfigurations") (c: c.activationPackage)
