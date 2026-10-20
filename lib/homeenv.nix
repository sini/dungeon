# hjem / nix-maid batteries: OS module imported once when a host user has the class; each such user's
# class content forwarded (guides/home-manager.mdx:197-248, explanation/context-pipeline.mdx:73-76, custom-classes.mdx:25-26).
# shortcut: no host.<env>.module override nor <env>.enable schema flag; add when a fleet sets them.
dungeon: {
  homeEnv =
    r: inputs: host: envUsers:
    let
      envs = {
        hjem = { module = inputs.hjem.nixosModules.default; at = u: [ "hjem" "users" u ]; };
        maid = { module = inputs.nix-maid.nixosModules.default; at = u: [ "users" "users" u "maid" ]; };
      };
      partsOf = cls: u: builtins.concatMap (a: if a.content ? ${cls} then [ (dungeon.content.classModule (r.argsOf u) a.content.${cls}) ] else [ ]) (r.defaultCl ++ r.userClosure u);
      nest = path: v: inputs.nixpkgs.lib.setAttrByPath path v;
      one =
        cls: e:
        let
          us = envUsers cls;
        in
        if us == [ ] then [ ]
        else if host.class != "nixos" then throw "den: `${cls}` users need a nixos host, `${host.name}` is ${host.class}"
        else [ e.module ] ++ map (u: nest (e.at host.users.${u}.userName) { imports = partsOf cls u; }) us;
    in
    builtins.concatLists (builtins.attrValues (builtins.mapAttrs one envs));
}
