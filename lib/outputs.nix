# Per-system output classes (guides/flake-outputs.mdx:25-36, 104-128): `den.schema.flake-system.includes` resolved once per
# den.systems entry (reference/output.mdx:90-98), routed only into declared `flake.<output>` options (flake-outputs.mdx:51-58).
# shortcut: host/user/home scopes are not collected yet; upgrade when a template exports outputs from a host aspect.
dungeon: {
  outputs =
    world: inputs: options:
    let
      lib = inputs.nixpkgs.lib;
      # output leaf (issue-674): attrsets deep-merge per key, lists concat; any other leaf (derivation, scalar) folds like
      # gen-merge `mergeLeaf` (gen-merge lib/modules.nix:5119): equal definitions (`==`; derivations compare by outPath) merge, unequal throw.
      leaf = lib.mkOptionType {
        name = "denOutput";
        merge = loc: defs:
          let vs = map (d: d.value) defs; in
          if builtins.all (v: builtins.isAttrs v && !lib.isDerivation v) vs then (lib.types.lazyAttrsOf leaf).merge loc defs
          else if builtins.all builtins.isList vs then builtins.concatLists vs
          else if builtins.all (v: v == builtins.head vs) vs then builtins.head vs
          else throw "den: conflicting definitions of flake output `${lib.showOption loc}` in ${lib.concatMapStringsSep ", " (d: toString d.file) defs}";
      };
      sys = lib.unique (builtins.attrNames world.hosts ++ builtins.attrNames world.homes);
      systems = if world.systems != [ ] then world.systems else if sys != [ ] then sys else lib.systems.flakeExposed;
      root = { includes = world.schema.flake-system.includes; };
      eval =
        cls: system:
        removeAttrs (lib.evalModules {
          modules = [ { config._module.freeformType = lib.types.lazyAttrsOf leaf; config._module.args.pkgs = inputs.nixpkgs.legacyPackages.${system}; } ]
            ++ (dungeon.resolve world cls root).imports;
        }).config [ "_module" ];
      # `flake` is an option (freeform submodule / flake-parts) or a plain set of output option decls
      subs = if options.flake._type or null == "option" then options.flake.type.getSubOptions [ ] else options.flake;
      classes = builtins.filter (n: subs ? ${n}) [ "packages" "apps" "checks" "devShells" "legacyPackages" ];
    in
    lib.optionalAttrs (world.schema ? flake-system && root.includes != [ ]) (lib.genAttrs classes (cls: lib.genAttrs systems (eval cls)));
}
