#!/usr/bin/env bash
# usage: (repo root) templates/ci/bin/run.sh
ulimit -v 8388608; timeout 180 nix eval --impure --json --expr 'let d = (builtins.getFlake "path:'"$PWD"'").lib; in import ./templates/ci/bin/tier1.nix { dungeon = d; nixpkgsLib = (builtins.getFlake "nixpkgs").lib; }'
