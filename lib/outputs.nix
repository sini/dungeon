# Per-system output classes (guides/flake-outputs.mdx:25-36, 104-128): `den.schema.flake-system.includes` resolved once per
# den.systems entry (reference/output.mdx:90-98), routed only into declared `flake.<output>` options (flake-outputs.mdx:51-58).
# shortcut: host/user/home scopes are not collected yet; upgrade when a template exports outputs from a host aspect.
dungeon: {
  outputs =
    world: inputs: options:
    let
      lib = inputs.nixpkgs.lib;
      sys = lib.unique (builtins.attrNames world.hosts ++ builtins.attrNames world.homes);
      systems = if world.systems != [ ] then world.systems else if sys != [ ] then sys else lib.systems.flakeExposed;
      root = { includes = world.schema.flake-system.includes; };
      eval =
        cls: system:
        removeAttrs (lib.evalModules {
          modules = [ { config._module.freeformType = lib.types.lazyAttrsOf lib.types.unspecified; config._module.args.pkgs = inputs.nixpkgs.legacyPackages.${system}; } ]
            ++ (dungeon.resolve world cls root).imports;
        }).config [ "_module" ];
      # `flake` is an option (freeform submodule / flake-parts) or a plain set of output option decls
      subs = if options.flake._type or null == "option" then options.flake.type.getSubOptions [ ] else options.flake;
      classes = builtins.filter (n: subs ? ${n}) [ "packages" "apps" "checks" "devShells" "legacyPackages" ];
    in
    lib.optionalAttrs (world.schema ? flake-system && root.includes != [ ]) (lib.genAttrs classes (cls: lib.genAttrs systems (eval cls)));
}
