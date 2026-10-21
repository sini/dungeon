# run inside `nix develop ./dev`
tpls := "minimal bogus noflake flake-parts-modules terranix-demo nvf-standalone default example microvm fleet-demo"

default:
    @just --list

# tier1 + gate (Den templates from the pinned Den rev, Den vs dungeon) + deadbugs summary
ci: gate deadbugs

# tier1 + each template evaluated with den=Den vs den=this checkout. Den source: ci/den-rev (override: DEN_SRC=<dir|rev>)
gate:
    bash ci/gate.sh . "$(bash ci/den-src.sh ${DEN_SRC:-})" {{tpls}} | tee /dev/stderr | { ! grep -q FAIL; }

# Den's deadbugs suites on dungeon (optional suite names). Report only: Den passes 65/65.
deadbugs *suites:
    bash ci/deadbugs.sh "$(bash ci/den-src.sh ${DEN_SRC:-})" . /tmp/deadbugs.tsv {{suites}}
    @cut -f1,2 /tmp/deadbugs.tsv
    @echo "PASS: $(grep -c 'PASS' /tmp/deadbugs.tsv) / $(wc -l < /tmp/deadbugs.tsv)"

fmt:
    nixfmt $(fd -e nix -E ci -E node_modules .)

# compare a flake's drvPaths: Den vs dungeon (this checkout). usage: just diff <flake-ref> [attr...]
diff flake *attrs:
    drvPathDiff --dungeon {{justfile_directory()}} {{flake}} {{attrs}}
