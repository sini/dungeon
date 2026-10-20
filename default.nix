{ gen }:
let
  # nest pattern: each lib/*.nix is `dungeon: { <name> = …; }` and sees the merged set.
  # file arg stays plain `dungeon:` — destructuring it would force the fixpoint.
  files = builtins.filter (f: builtins.match ".*\\.nix" f != null) (
    builtins.attrNames (builtins.readDir ./lib)
  );
  dungeon = builtins.foldl' (acc: f: acc // import (./lib + "/${f}") dungeon) { inherit gen; } files;
in
dungeon
