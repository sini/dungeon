# policy.instantiate custom spec: `instantiate { modules }` of the spec's class bucket lands at flake.<intoAttr> (reference/policies.mdx:162-172).
dungeon: {
  instantiates =
    world: lib:
    let
      pol = dungeon.policy world;
      hosts = builtins.concatMap builtins.attrValues (builtins.attrValues world.hosts);
      one =
        h0:
        let
          us = pol.usersOf h0;
          r = dungeon.route world.schema world.aspects (h0 // { users = us; }) (builtins.attrNames us);
        in
        map (e: lib.setAttrByPath e.value.intoAttr (e.value.instantiate { modules = r.classModules e.value.class; })) r.instantiates;
    in
    # one value per path: flake freeform leaves are `raw` (single definition)
    builtins.foldl' lib.recursiveUpdate { } (builtins.concatMap one hosts);
}
