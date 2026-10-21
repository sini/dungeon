# den.lib.aspects.resolve class aspect -> { imports } (reference/lib.mdx:24-27): the class content of the aspect's include tree.
# Context: values pinned by parametric.fixedTo (reference/lib-deprecated.mdx:41-49) + `class`/`aspect-chain` for provider fns
# (guides/custom-classes.mdx `{ class, aspect-chain }:`). Provider fns whose required args are not in scope do not fire.
dungeon: {
  resolve =
    world: class: root:
    if root.__entityKind or null == "host" then dungeon.resolveEntityModule world class root.ctx.host else
    let
      lib = dungeon.genLib;
      ctx = root.__ctx or { };
      scope = ctx // { inherit class; aspect-chain = [ root ]; };
      required = f: builtins.attrNames (lib.filterAttrs (_: opt: !opt) (lib.functionArgs f));
      call = s: f: f (builtins.intersectAttrs (lib.functionArgs f) s);
      # world aspects carry normalized content (view.nix norm); inline ones are raw attrsets
      isWorld = a: builtins.isAttrs a && a ? content && a ? policyIncs;
      # class content asking only for pinned ctx is applied here; module args stay for the module system.
      # shortcut: content mixing ctx and module args is passed unbound; upgrade with gen.bind.wrap when a template needs it.
      # Gen class content is `{ imports = [ .. ]; }` (as content.nix walks it)
      bind =
        m:
        if lib.isFunction m && required m != [ ] && builtins.all (k: ctx ? ${k}) (required m) then call ctx m
        else if builtins.isAttrs m && builtins.isList (m.imports or null) then m // { imports = map bind m.imports; }
        else m;
      expand =
        a:
        if isWorld a then
          # fn aspects: their result's includes are live (normalize.nix fnIncs); shortcut: top-level fn aspects only (rawFns)
          builtins.concatMap (m: lib.optional (m.content ? ${class}) (bind m.content.${class}) ++ (if world.rawFns ? ${m.name} then expand { includes = (call scope world.rawFns.${m.name}).includes or [ ]; } else [ ])) (dungeon.closure world.rawAspects a)
        else if lib.isFunction a then
          if builtins.all (k: scope ? ${k}) (required a) then expand (call scope a) else [ ]
        else if builtins.isAttrs a then
          lib.optional (a ? ${class}) (bind a.${class}) ++ builtins.concatMap expand (a.includes or [ ])
        else
          throw "den.lib.aspects.resolve: include is not an aspect or function";
    in
    { imports = expand root; };
  # den.lib.resolveEntity "host" result: the host pipeline's modules (tutorials/microvm.mdx stage 3, reference/lib.mdx:62-83).
  # shortcut: users' hm/homeEnv + quirk channels are not wired for a resolved entity; throws when present.
  resolveEntityModule =
    world: class: h:
    if h.class != class then throw "den.lib.aspects.resolve: host `${h.name}` is ${h.class}, not ${class}"
    else if h.users or { } != { } then throw "den.lib.aspects.resolve: host `${h.name}` with users unsupported"
    else if world.quirks != { } then throw "den.lib.aspects.resolve: quirks unsupported for resolved entity `${h.name}`"
    else { imports = (dungeon.route world.schema world.rawAspects h [ ]).modules; };
}
