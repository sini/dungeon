# run inside `nix develop ./dev`
tpls := "minimal flake-parts-modules terranix-demo nvf-standalone default example microvm fleet-demo"
base := "templates/ci/baselines"

default:
    @just --list

# tier1 + gate (all templates vs committed Den baselines) + deadbugs summary
ci: gate deadbugs

# tier1, bogus, noflake, then each template drvPath vs baseline
gate:
    bash templates/ci/bin/gate.sh . {{base}} {{tpls}} | tee /dev/stderr | { ! grep -q FAIL; }

# deadbugs suites on dungeon (optional suite names). Report only: Den passes 65/65, dungeon 38/65.
deadbugs *suites:
    bash templates/ci/bin/deadbugs.sh . /tmp/deadbugs.tsv {{suites}}
    @cut -f1,2 /tmp/deadbugs.tsv
    @echo "PASS: $(grep -c 'PASS' /tmp/deadbugs.tsv) / $(wc -l < /tmp/deadbugs.tsv)"

fmt:
    nixfmt $(fd -e nix -E templates -E node_modules .)

# compare a flake's drvPaths: Den vs dungeon (this checkout). usage: just diff <flake-ref> [attr...]
diff flake *attrs:
    drvPathDiff --dungeon {{justfile_directory()}} {{flake}} {{attrs}}
