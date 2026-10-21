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
        # gen-merge submodules take base args on the type (gen-merge types.nix:938-943), so `{ lib, ... }:` works inside them.
        submodule = m: (dungeon.gen.merge.types.submodule m).withArgs { lib = dungeon.genLib; };
      };
      evalModules =
        { modules }:
        dungeon.gen.merge.evalModuleTree { specialArgs.lib = dungeon.genLib; } modules;
    };
}
