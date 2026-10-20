dungeon:
let
  # Only these leaves are captured; `den.users` etc. stay free for user-declared outer options.
  leaves = [ "hosts" "aspects" "schema" "policies" "quirks" "classes" "homes" "default" "systems" ];
  # Each outer definition becomes one Gen module rooted at the leaf (design-den-option.md option A).
  capture =
    lib: leaf:
    lib.mkOption {
      type = lib.mkOptionType {
        name = "dungeonLeaf";
        emptyValue = { value = [ ]; };
        merge = _loc: defs: map (d: if leaf == "aspects" || leaf == "default" then lower lib leaf d else { _file = d.file; ${leaf} = if leaf == "policies" && builtins.isAttrs d.value then builtins.mapAttrs (name: v: if v.__isPolicy or false then v else { __isPolicy = true; inherit name; fn = v; }) d.value else d.value; }) defs;
      };
    };
  # Lowering lives in normalize.nix; this only shapes the Gen module (inline includes -> anon aspects, design-fleet G3 arm a).
  lower =
    lib: leaf: d:
    if leaf != "default" && !builtins.isAttrs d.value then
      { _file = d.file; ${leaf} = d.value; }
    else
      { den, ... }:
      let
        n = dungeon.normalize lib leaf (dungeon.view.cnfOf den) (if leaf == "default" then { default = d.value; } else d.value);
        fixed = n.fixed den;
      in
      {
        _file = d.file;
        aspects = n.anons // lib.optionalAttrs (leaf == "aspects") fixed;
        default = lib.optionalAttrs (leaf == "default") fixed.default;
        policyRecs = lib.optionalAttrs (leaf == "aspects") n.recs;
        rawFns = lib.optionalAttrs (leaf == "aspects") (lib.filterAttrs (_: builtins.isFunction) d.value);
        aspectPolicies = lib.optionalAttrs (leaf == "aspects" || leaf == "default") n.polIncs;
        unregistered = dungeon.unregistered (dungeon.view.cnf0Of den) (if leaf == "default" then { default = d.value; } else d.value);
      };
  # built hosts whose intoAttr head is `o`
  hostsAt = den: inputs: o: dungeon.genLib.filterAttrs (n: _: builtins.head (den.host n).intoAttr == o) (dungeon.hosts den inputs);
  # flake-parts already declares `flake`, so only the plain-evalModules host adds it.
  mk =
    declareFlake:
    { lib, config, options, inputs, ... }@margs:
    {
      # freeform `flake` (keyed: dedups with a user flakeOutputs.flake import) + typed outputs dungeon writes.
      # docs reference/output.mdx:61: own `flake` outputs only when `inputs.flake-parts` is absent.
      imports = (if declareFlake && !(inputs ? flake-parts) then (
        map (n: dungeon.ciSurface.flakeOutputs.${n}) [ "flake" "nixosConfigurations" "darwinConfigurations" "homeConfigurations" ]) else [ ]
      # flake-parts-lib: specialArg of a running mkFlake (perSystem/systems exist only there)
      ) ++ lib.optional (margs ? flake-parts-lib) ({ den, ... }: dungeon.flakeParts den lib)
      ++ [ ({ den, ... }: { flake = dungeon.instantiates den lib; }) ({ options, ... }: { config.flake = dungeon.outputs config._module.args.den inputs options; }) ];
      # den.lib is user-extensible (templates/nvf-standalone/modules/nvf-integration.nix): definitions deep-merge over the builtin lib.
      options.den = lib.genAttrs leaves (capture lib) // { lib = lib.mkOption { default = { }; type = lib.mkOptionType { name = "denLib"; merge = _: defs: builtins.foldl' lib.recursiveUpdate { } (map (d: d.value) defs); }; }; };
      config._module.args.den = let w = dungeon.evalDen (lib.concatMap (l: lib.optionals options.den.${l}.isDefined config.den.${l}) leaves ++ lib.optional (margs ? withSystem) { _module.args.withSystem = margs.withSystem; }); in w // { lib = lib.recursiveUpdate w.lib config.den.lib; };
      # schema.mdx:166-171: each host lands at its intoAttr (nixosConfigurations / darwinConfigurations)
      config.flake.nixosConfigurations = hostsAt config._module.args.den inputs "nixosConfigurations";
      config.flake.darwinConfigurations = hostsAt config._module.args.den inputs "darwinConfigurations";
      # standalone homes: aspect named by the home (guides/standalone-home-manager.mdx), its homeManager parts
      config.flake.homeConfigurations =
        let
          den = config._module.args.den;
          cl = dungeon.closure den.aspects;
        in
        lib.concatMapAttrs (
          system: hs:
          lib.mapAttrs (
            name: h:
            inputs.home-manager.lib.homeManagerConfiguration {
              pkgs = inputs.nixpkgs.legacyPackages.${system};
              modules =
                let
                  base = lib.head (lib.splitString "@" name);
                  args = { home = h // { inherit name system; }; user = h // { inherit system; name = base; userName = base; }; };
                  dcl = cl den.aspects.default;
                  scope = dungeon.schemaCl den.schema den.aspects true "home" ++ lib.concatMap (n: lib.optionals (den.aspects ? ${n}) (cl den.aspects.${n})) (lib.unique [ name base ]);
                in
                lib.concatMap (a: lib.optional (a.content ? homeManager) (dungeon.content.classModule args a.content.homeManager)) (
                  dcl ++ scope ++ dungeon.routes dcl [ ] args (dcl ++ scope)
                );
            }
          ) hs
        ) den.homes;
    };
in
{
  lowerDef = lower;
  # key: a test importing den.flakeModule again must dedupe, not redeclare `flake`
  flakeModule = { key = "dungeon:flakeModule"; imports = [ (mk true) ]; };
  # docs tutorials/default.mdx:184-192: dendritic.nix imports den.flakeModules.dendritic as the den wiring.
  flakeModules = rec { default = { key = "dungeon:flakeModules.default"; imports = [ (mk false) ]; }; dendritic = default; };
}
