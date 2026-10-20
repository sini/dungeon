#!/usr/bin/env bash
# usage: cd dungeon && ci/run.sh
ulimit -v 8388608; timeout 180 nix eval --impure --json --expr 'let d = (builtins.getFlake "path:'"$PWD"'").lib; in import ./ci/tier1.nix { dungeon = d; nixpkgsLib = (builtins.getFlake "nixpkgs").lib; }'
