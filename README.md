<p align="center"><img src="logo.svg" width="200" alt="dungeon"></p>

# dungeon

Den's public API, built on [Gen](https://github.com/sini/gen) libraries only.
Drop-in replacement for `github:denful/den`.

- Same API as Den.
- Same `drvPath`s as Den for the templates below.
- Core is built on Gen, which is proved and tested.

## Progress

Templates: `drvPath` equal to Den.

| template | status |
|---|---|
| minimal | equal |
| bogus | equal |
| noflake | equal |
| flake-parts-modules | equal |
| terranix-demo | equal |
| nvf-standalone | equal |
| default | equal |
| example | equal |
| microvm | equal |
| fleet-demo | hosts equal; `den-diagram` packages out of scope |

Deadbugs (Den's `templates/ci/modules/deadbugs`, 65 suites): dungeon passes 50/65. Den passes 65/65.

## Try it

Use dungeon in place of Den in your flake:

```
nix eval --override-input den github:vic/dungeon .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
nix build --override-input den github:vic/dungeon .#nixosConfigurations.<host>.config.system.build.toplevel
```

Start from a Den template and override `den`:

```
nix flake init -t github:denful/den#minimal
nix eval --override-input den github:vic/dungeon .#nixosConfigurations.igloo.config.system.build.toplevel.drvPath
```

## Compare with Den and report

`drvPathDiff` evaluates your flake twice: with its own `den` input, and with `den` overridden to dungeon.
It prints `OK`, `DIFF` or `ERR` per `nixosConfigurations`, `darwinConfigurations` and `homeConfigurations` entry.
Pass extra package attrs after the flake ref.

```
nix run github:vic/dungeon?dir=dev#drvPathDiff -- github:you/your-flake
nix run github:vic/dungeon?dir=dev#drvPathDiff -- --dungeon ./path/to/dungeon path:. packages.x86_64-linux.foo
```

Flags: `--dungeon REF|DIR` (default `github:vic/dungeon`), `--input NAME` (default `den`), `--out FILE`.

On any `DIFF` or `ERR`, it writes an issue body (flake, Den rev, dungeon rev, attrs, both drvPaths, first error, nix version) and prints the command:

```
gh issue create -R vic/dungeon --title '...' --body-file <file>
```

Exit code is 1 when something differs.

## Tests

```
nix develop ./dev     # just, nix-unit, nixfmt, gh, jq, ripgrep, fd, actionlint
just --list
just ci               # tier1 + gate on all templates + deadbugs summary
just gate             # Den templates at the pinned rev: den=Den vs den=dungeon, drvPaths equal
just deadbugs [suite] # Den's deadbugs suites on dungeon
just diff <flake>     # drvPathDiff against this checkout
just fmt
```

Den's templates and deadbugs are not copied here. `ci/den-rev` pins the Den rev they are fetched from (`ci/den-src.sh` prints the source path).
Override once with `DEN_SRC=<dir|rev> just gate`. Bump the pin: `nix flake metadata github:denful/den --json | jq -r .locked.rev > ci/den-rev`.
Deadbugs run Den's own `templates/ci` flake (all its modules) with `--override-input den path:<dungeon>`.

## CI

- `ci.yml`: `just ci`.
- `den-templates.yml`: each template, fresh `github:denful/den` vs this repo.
- `deadbugs.yml`: 4 shards, each suite on Den and dungeon. A suite that passes on Den and fails on dungeon fails the job. It runs with `continue-on-error` (reporting mode) until dungeon reaches 65/65. Then remove that line.

Dev tools live in the `dev/` sub-flake. The top-level flake has one input: `gen`.
