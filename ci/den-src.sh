#!/usr/bin/env bash
# usage: ci/den-src.sh [rev|dir]  -> prints a Den source dir (default: rev pinned in ci/den-rev).
# Bump: `nix flake metadata github:denful/den --json | jq -r .locked.rev > ci/den-rev`.
set -eu
a=${1:-$(tr -d '\n' < "$(dirname "$0")/den-rev")}
if [ -d "$a" ]; then realpath "$a"; else nix flake metadata --json "github:denful/den/$a" | jq -r .path; fi
