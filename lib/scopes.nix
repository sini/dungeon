# Custom entity scopes under a host + policy.provide delivery (tutorials/microvm.mdx stages 1-3), grown on gen-scope `nta`.
# explanation/policies.mdx:86-91: resolve.to with entity bindings = child scope whose schema.<kind>.includes fire;
# reference/policies.mdx:142-150: provide = module straight to `class` at `path` (mode nest), bypassing the tree.
# explanation/scope-partitioning.mdx:129-133: a child scope fires once per context key in its parent (nta key-set dedup).
# One gen kind `scope`; the Den kind is seed DATA (the resolve.to record), so no static kind order (gen-scope cascade.nix:636).
dungeon:
let
  gs = dungeon.gen.scope;
  lib = dungeon.genLib;
  lst = x: if builtins.isList x then x else [ x ];
  # user/host children are owned by policy.nix + route.nix; only custom kinds open a scope here
  isKid = e: (e.__effect or null) == "resolve" && e ? kind && !(builtins.elem e.kind [ "user" "host" ]);
  # stand-in for Den's childScopeId (mkScopeId enrichedCtx): kind + bound entity names
  keyOf = e: e.kind + builtins.concatStringsSep "" (lib.mapAttrsToList (n: v: ",${n}=${v.name}") e.bindings);
  # effects = [ [effect] per policy ] -> flat [ { i; j; e; } ] in fire order
  pos = effs: builtins.concatLists (builtins.genList (i: builtins.genList (j: { inherit i j; e = builtins.elemAt (builtins.elemAt effs i) j; }) (builtins.length (builtins.elemAt effs i))) (builtins.length effs));
  # first (i, j) per child key wins (listToAttrs keeps the first)
  kids = effs: builtins.listToAttrs (map (p: { name = keyOf p.e; value = p; }) (builtins.filter (p: isKid p.e) (pos effs)));
  # nta contract (gen-scope eval.nix:634-641): group `child`, key = scope id, seed = address of the resolve effect
  scopeKind = gs.mkKind {
    nta.resolve = self: id: { child = builtins.mapAttrs (_: p: [ { attr = "effects"; def = p.i; at = [ p.j ]; } ]) (kids (self.get id "effects")); };
  } "scope";
  isRoot = self: id: (self.node id).parent == null;
  fire = ctx: p:
    if builtins.all (n: ctx ? ${n}) (builtins.attrNames (lib.filterAttrs (_: opt: !opt) (lib.functionArgs p.fn)))
    then lst (p.fn (builtins.intersectAttrs (lib.functionArgs p.fn) ctx)) else [ ];
  pols = sch: kind: map (x: if x.__isPolicy or false then x else throw "den: schema.${kind}.includes: only policies are supported in custom scope `${kind}`") (sch.${kind}.includes or [ ]);
  provide = host: e:
    if e.class != host.class then throw "den: policy.provide to class `${e.class}` on ${host.class} host `${host.name}` unsupported"
    else if e.path == [ ] then e.module
    else lib.setAttrByPath e.path e.module;
  # pre-order: a child's deliveries sit where its resolve effect fired; inside a custom scope unknown effects throw
  deliver = host: self: id: p:
    if (p.e.__effect or null) == "provide" then [ (provide host p.e) ]
    else if isKid p.e then
      (if (kids (self.get id "effects")).${keyOf p.e}.i == p.i && (kids (self.get id "effects")).${keyOf p.e}.j == p.j
       then self.getNta "resolve" "child" (keyOf p.e) "delivered" else [ ])
    else if !(isRoot self id) then throw "den: effect `${p.e.__effect or "?"}` unsupported in custom scope (host `${host.name}`)"
    else [ ];
  attributes = sch: host: {
    children = _: _: { };
    # the resolve.to record that opened this scope (stamped decls.seed, eval.nix:640)
    seed = self: id: (builtins.head (self.node id).decls.seed).value;
    ctx = self: id: if isRoot self id then (self.node id).decls.ctx else self.get (self.node id).parent "ctx" // (self.get id "seed").bindings;
    pols = self: id: if isRoot self id then (self.node id).decls.pols else pols sch (self.get id "seed").kind;
    effects = self: id: map (fire (self.get id "ctx")) (self.get id "pols");
    delivered = self: id: builtins.concatMap (deliver host self id) (pos (self.get id "effects"));
  };
in
{
  # host: entity; args: host-scope ctx; hostPols: policy records ({ fn }) firing at host scope. -> host-class modules.
  scopes.delivered =
    sch: host: args: hostPols:
    (gs.eval { } (attributes sch host) {
      nodes.${host.name} = { id = host.name; type = "scope"; parent = null; decls = { ctx = args; pols = hostPols; }; };
      kinds = gs.mkKinds [ scopeKind ];
      nodeOrder = [ host.name ];
    }).get host.name "delivered";
}
