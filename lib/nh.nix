# den.lib.nh (reference/lib.mdx:145-198): one nh wrapper per host and home; args fromFlake (true), fromPath ("."), outPrefix.
# fromFlake=false: `--file <path> <outPrefix.attr>` (tutorials/noflake.mdx:153); host attr = host.intoAttr.
dungeon: {
  nh =
    hosts: homes:
    let
      app =
        pkgs: name: cmd: target:
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = [ pkgs.nh ];
          text = ''
            action="''${1:-build}"
            shift || true
            exec nh ${cmd} "$action" ${target} "$@"
          '';
        };
      norm = { fromFlake ? true, fromPath ? ".", outPrefix ? [ ] }: { inherit fromFlake fromPath outPrefix; };
      ref = a: attr: if a.fromFlake then "${a.fromPath}#${attr}" else "--file ${a.fromPath} ${builtins.concatStringsSep "." (a.outPrefix ++ [ attr ])}";
      osCmd = h: { nixos = "os"; darwin = "darwin"; }.${h.class} or (throw "den.lib.nh: host `${h.name}` class `${h.class}` has no nh command");
      allHosts = builtins.concatMap builtins.attrValues (builtins.attrValues hosts);
      homeNames = builtins.concatMap builtins.attrNames (builtins.attrValues homes);
      hostApps = args: pkgs: map (h: app pkgs h.name (osCmd h) (ref (norm args) (builtins.concatStringsSep "." h.intoAttr))) allHosts;
      # package names cannot hold `@` (guides/standalone-home-manager.mdx:149-153)
      homeApp =
        a: pkgs: n:
        if a.fromFlake then app pkgs (builtins.replaceStrings [ "@" ] [ "-" ] n) "home" "${a.fromPath}# -c ${n}"
        else throw "den.lib.nh: non-flake home apps unmeasured (home `${n}`)";
      homeApps = args: pkgs: map (homeApp (norm args) pkgs) homeNames;
      denApps = args: pkgs: hostApps args pkgs ++ homeApps args pkgs;
    in
    {
      inherit hostApps homeApps denApps;
      denPackages = args: pkgs: builtins.listToAttrs (map (d: { name = d.name; value = d; }) (denApps args pkgs));
      denShell = args: pkgs: pkgs.mkShell { buildInputs = [ pkgs.nh ] ++ denApps args pkgs; };
    };
}
