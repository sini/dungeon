{
  inputs.gen.url = "github:sini/gen/bcbc5ca579614643fa3433034fd0248b0d551f65";
  inputs.gen.inputs.nixpkgs.follows = "";
  outputs = inputs: let
    # non-flake callers (with-inputs/npins) have no gen source: fetch the locked rev.
    locked = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.gen.locked;
    genSrc = inputs.gen.outPath or (builtins.fetchTarball {
      url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
      sha256 = locked.narHash;
    });
    dungeon = import ./default.nix { gen = import genSrc { }; };
  in {
    lib = dungeon;
    flakeModule = dungeon.flakeModule;
    flakeModules = { inherit (dungeon.flakeModules) default dendritic; };
    namespace = dungeon.namespace;
    flakeModules.denTest = dungeon.ciSurface.denTestModule;
    flakeOutputs = dungeon.ciSurface.flakeOutputs;
  };
}
