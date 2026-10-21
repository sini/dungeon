# Contents of the generated files: README.md and .github/workflows/*.yml, from registry.nix and ci/status.json.
{ lib, registry, status }:
let
  names = map (e: e.name) registry;
  stateOf = n: let s = status.entries.${n} or null; in if s == "OK" then "equal" else if s == null then "n/a" else "DIFF";
  short = flake: if lib.hasPrefix "github:denful/den?dir=" flake then "den:" + lib.removePrefix "github:denful/den?dir=" flake else flake;
  row = e: "| ${e.name} | `${short e.flake}` | ${stateOf e.name} | ${lib.concatStringsSep "; " (lib.filter (x: x != "") [ e.notes (lib.optionalString (e.owner != "") "owner: ${e.owner}") ])} |";
  d = status.deadbugs;
  rows = lib.concatStringsSep "\n" (map row registry ++ [ "| deadbugs | Den `templates/ci/modules/deadbugs` | ${toString d.pass}/${toString d.total} | Den passes ${toString d.total}/${toString d.total} |" ]);
  readme = lib.replaceStrings [ "@TABLE@" "@DENREV@" "@PASS@" "@TOTAL@" ] [ rows status.denRev (toString d.pass) (toString d.total) ] (builtins.readFile ./README.tmpl.md);

  setup = [
    { uses = "actions/checkout@v4"; }
    { uses = "cachix/install-nix-action@v31"; "with".nix_path = "nixpkgs=channel:nixos-unstable"; }
  ];
  inDev = cmd: "nix develop path:.?dir=dev -c ${cmd}";
in
{
  files = {
    "README.md".text = readme;
    ".github/workflows/ci.yml".yaml = {
      name = "ci";
      on = [ "push" "pull_request" ];
      jobs.ci = { runs-on = "ubuntu-latest"; steps = setup ++ [ { run = inDev "just ci"; } ]; };
      jobs.generated = {
        runs-on = "ubuntu-latest";
        steps = setup ++ [ { name = "README.md and workflows are in sync (run `just write`)"; run = "nix flake check path:.?dir=dev"; } ];
      };
    };
    # one job per registry entry
    ".github/workflows/den-templates.yml".yaml = {
      name = "den-templates";
      on = [ "push" "pull_request" "workflow_dispatch" ];
      jobs.entry = {
        runs-on = "ubuntu-latest";
        strategy = { fail-fast = false; matrix.entry = names; };
        steps = setup ++ [ {
          name = "gate";
          env.T = "\${{ matrix.entry }}";
          run = "# shellcheck disable=SC2016\n" + inDev ''bash -c 'bash ci/gate.sh . "$(bash ci/den-src.sh)" "$T" | tee /dev/stderr | { ! grep -q FAIL; }' '';
        } ];
      };
    };
    ".github/workflows/deadbugs.yml".yaml = {
      name = "deadbugs";
      on = [ "push" "pull_request" "workflow_dispatch" ];
      # Reporting mode until dungeon reaches 65/65; then delete continue-on-error.
      jobs.deadbugs = {
        runs-on = "ubuntu-latest";
        continue-on-error = true;
        strategy = { fail-fast = false; matrix.shard = [ 0 1 2 3 ]; };
        steps = setup ++ [ {
          name = "run shard on Den and dungeon";
          env.SHARD = "\${{ matrix.shard }}";
          run = "# shellcheck disable=SC2016\n" + inDev ''bash -c '
            set -u
            den=$(bash ci/den-src.sh)
            mapfile -t all < <(rg -oN --no-filename -r "\$1" "flake\.tests\.([A-Za-z0-9_-]+)" "$den"/templates/ci/modules/deadbugs/*.nix | sort -u)
            suites=(); for i in "''${!all[@]}"; do [ $((i % 4)) -eq "$SHARD" ] && suites+=("''${all[$i]}"); done
            bash ci/deadbugs.sh "$den" "$den" "$RUNNER_TEMP/den.tsv" "''${suites[@]}"
            bash ci/deadbugs.sh "$den" "$PWD" "$RUNNER_TEMP/dungeon.tsv" "''${suites[@]}"
            echo "Den PASS: $(grep -c PASS "$RUNNER_TEMP/den.tsv")  dungeon PASS: $(grep -c PASS "$RUNNER_TEMP/dungeon.tsv")  of ''${#suites[@]}"
            join -t "$(printf "\t")" <(cut -f1,2 "$RUNNER_TEMP/den.tsv" | sort) <(cut -f1,2 "$RUNNER_TEMP/dungeon.tsv" | sort) \
              | awk -F"\t" "\$2==\"PASS\" && \$3!=\"PASS\" {print \"FAIL on dungeon: \" \$1; bad=1} END {exit bad}"
          ' '';
        } ];
      };
    };
  };
}
