# genLib: the `lib` the inner Gen eval sees (Gen only, no nixpkgs). Adapted from ren/lib/gen-lib.nix.
dungeon: {
  genLib =
    builtins
    // dungeon.gen.prelude
    // dungeon.gen.merge
    // {
      # gen-types enum takes a name first (gen-types checkers.nix:1023).
      types = dungeon.gen.merge.types // {
        enum = vs: dungeon.gen.merge.types.enum "enum" vs;
      };
      evalModules =
        { modules }:
        dungeon.gen.merge.evalModuleTree { specialArgs.lib = dungeon.genLib; } modules;
    };
}
