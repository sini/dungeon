# Regression for discussion #620:
# `docs/src/content/docs/guides/custom-classes.mdx`,
# "Example: Platform specific `hm` classes".
#
# The documented `hmPlatforms` forward failed for a host user with
# "spawnNode spawn root equals its parent scope".
{ denTest, ... }:
{
  flake.tests.deadbugs.hm-platform-forward = {

    # Docs example: forward `hmLinux`, guard out `hmDarwin`.
    test-doc-example-forwards-linux-only = denTest (
      {
        den,
        lib,
        tuxHm,
        ...
      }:
      let
        hmPlatforms =
          { class, aspect-chain }:
          den.batteries.forward {
            each = [
              "Linux"
              "Darwin"
              "Aarch64"
              "64bit"
            ];
            fromClass = platform: "hm${platform}";
            intoClass = _: "homeManager";
            intoPath = _: [ ];
            fromAspect = _: lib.head aspect-chain;
            guard = { pkgs, ... }: platform: lib.mkIf pkgs.stdenv."is${platform}";
            adaptArgs =
              { config, ... }:
              {
                osConfig = config;
              };
          };
      in
      {
        den.hosts.x86_64-linux.igloo.users.tux = { };
        den.aspects.tux = {
          includes = [ hmPlatforms ];

          hmLinux.home.sessionVariables.HM_PLATFORM = "linux";

          hmDarwin.home.sessionVariables.HM_PLATFORM_DARWIN = "darwin";
        };

        expr = {
          linux = tuxHm.home.sessionVariables.HM_PLATFORM or null;
          darwin = tuxHm.home.sessionVariables.HM_PLATFORM_DARWIN or null;
        };
        expected = {
          linux = "linux";
          darwin = null;
        };
      }
    );

    # Unknown source class: forwarding an undeclared, unused class into an
    # evaluated class should be inert, not crash during fallback rewalk.
    test-unknown-source-class-to-home-manager-is-inert = denTest (
      {
        den,
        lib,
        igloo,
        ...
      }:
      let
        forwardUnknownSource =
          { aspect-chain, ... }:
          den.batteries.forward {
            each = [ true ];
            fromClass = _: "unusedSource";
            intoClass = _: "homeManager";
            fromAspect = _: lib.head aspect-chain;
          };
      in
      {
        den.hosts.x86_64-linux.igloo.users.tux = { };
        den.aspects.tux.includes = [ forwardUnknownSource ];

        expr = igloo.home-manager.users.tux.home.stateVersion;
        expected = "25.11";
      }
    );
  };
}
