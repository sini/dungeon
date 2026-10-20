# Dev tooling for dungeon. Kept out of the top-level flake so users of dungeon pull only `gen`.
{
  inputs.nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.xz";
  outputs = { self, nixpkgs }: let
    forAll = f: nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (s: f nixpkgs.legacyPackages.${s});
  in {
    packages = forAll (pkgs: rec {
      drvPathDiff = pkgs.writeShellApplication {
        name = "drvPathDiff";
        runtimeInputs = [ pkgs.nix pkgs.jq pkgs.gnused pkgs.gnugrep pkgs.coreutils ];
        text = ''
          export DRVPATHS_NIX=${./drvpaths.nix}
          ${builtins.readFile ./drvPathDiff.sh}
        '';
        # script handles its own failures; shellcheck noise on dynamic arrays
        checkPhase = "";
      };
      default = drvPathDiff;
    });
    apps = forAll (pkgs: rec {
      drvPathDiff = { type = "app"; program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.drvPathDiff}/bin/drvPathDiff"; };
      default = drvPathDiff;
    });
    devShells = forAll (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [ just nix-unit nixfmt gh jq ripgrep fd actionlint shellcheck self.packages.${pkgs.stdenv.hostPlatform.system}.drvPathDiff ];
      };
    });
  };
}
