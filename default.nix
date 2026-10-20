let
  # nest pattern: each lib/*.nix is `dungeon: { <name> = …; }` and sees the merged set.
  # file arg stays plain `dungeon:` — destructuring it would force the fixpoint.
  build =
    { gen }:
    let
      files = builtins.filter (f: builtins.match ".*\\.nix" f != null) (
        builtins.attrNames (builtins.readDir ./lib)
      );
      dungeon = builtins.foldl' (acc: f: acc // import (./lib + "/${f}") dungeon) { inherit gen; } files;
    in
    dungeon;
  # `import den` with no flake: gen from the locked rev (as flake.nix does for non-flake callers).
  locked = (builtins.fromJSON (builtins.readFile ./flake.lock)).nodes.gen.locked;
  genSrc = builtins.fetchTarball {
    url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
    sha256 = locked.narHash;
  };
in
{
  # flake.nix: `import ./default.nix { gen = …; }`
  __functor = _: build;
  # `(import inputs.den).nixModule inputs`: den as a plain lib.evalModules module (deadbugs dup-functors-issue-216.nix).
  nixModule = (build { gen = import genSrc { }; }).nixModule;
}
