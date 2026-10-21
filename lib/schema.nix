# den.lib.schema.mkInstanceType options kind -> instance submodule type.
# Docs: reference/lib.mdx "mkInstanceType options kind" (options: extraModules, strict, specialArgs);
# guides/custom-entity-kinds.mdx s2 (strict=false => open instance).
dungeon: {
  # Registry-level `hasAspect`/`resolved` on every instance (entities.mdx resolved); structural: kind includes only.
  # route.nix overrides hasAspect with the scope-projected closure where the scope is known.
  schema.entity = kind: let lib = dungeon.genLib; in {
    options.resolved = lib.mkOption { type = dungeon.genLib.types.raw; default = { }; };
    # instance-own includes/excludes are read for every kind, so they are declared (custom-entity-kinds.mdx:47-49), not freeform.
    options.includes = lib.mkOption { type = dungeon.genLib.types.listOf dungeon.genLib.types.raw; default = [ ]; };
    options.excludes = lib.mkOption { type = dungeon.genLib.types.listOf dungeon.genLib.types.raw; default = [ ]; };
    options.hasAspect = lib.mkOption {
      type = dungeon.genLib.types.raw;
      default = a: builtins.elem (a.name or null) (map (b: if builtins.isAttrs b then b.name or null else null) (kind.includes or [ ]));
    };
  };
  schema.lib =
    let
      t = dungeon.genLib.types;
    in
    {
      mkInstanceType =
        {
          extraModules ? [ ],
          strict ? true,
          # shortcut: specialArgs accepted but ignored, wire when a consumer needs it.
          specialArgs ? { },
        }:
        kind:
        t.submodule (
          {
            # instance `name` defaults to its attr name (gen-schema lib/instance.nix options.name). shortcut: hand-rolled; swap to gen-schema mkInstanceType once den.schema kinds are minted gen-schema kinds.
            imports = (kind.imports or [ ]) ++ extraModules ++ [ (dungeon.schema.entity kind) ({ name, ... }: { options.name = dungeon.genLib.mkOption { type = t.str; default = name; }; }) ];
          }
          // (if strict then { } else { freeformType = t.lazyAttrsOf t.raw; })
        );
    };
}
