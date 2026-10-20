# evalDen: Gen-side eval of the captured `den` leaf modules -> world (design-gen.md §3 steps 2-4). No routing yet (R2+).
dungeon: {
  evalDen =
    denModules:
    let
      inner = dungeon.genLib.evalModules {
        modules = [
          dungeon.view.module
          dungeon.batteries.module
          { _module.args.withSystem = dungeon.genLib.mkDefault (_: throw "den: inputs'/self' need flake-parts withSystem"); }
          { _module.args.den = world; }
        ] ++ denModules;
      };
      cfg = inner.config;
      aspects = builtins.mapAttrs (n: a: if cfg.policyRecs ? ${n} then a // { policies = cfg.policyRecs.${n}; } else a) (dungeon.view.mkAspects cfg);
      # callable aspects: `den.aspects.f arg` = the raw fn applied, as an inline aspect (rawFns are the inner, unwrapped eval)
      wrapped = builtins.mapAttrs (n: a: a // { __functor = _: arg: cfg.rawFns.${n} arg; }) aspects;
      world = {
        aspects = wrapped;
        rawAspects = aspects;
        inherit (cfg) schema policies quirks classes homes unregistered systems rawFns;
        # entity `aspect` = den.aspects.<name> (reference/schema.mdx:139,141); lazy: throws only when read
        # user aspect (reference/schema.mdx:185) applies where it exists; none = empty aspect. shortcut: `<user>@<host>` qualified aspect not merged yet.
        hosts = builtins.mapAttrs (_: builtins.mapAttrs (n: h: h // { aspect = aspects.${n} or (throw "den: host `${n}` has no aspect"); users = builtins.mapAttrs (u: v: v // { aspect = aspects.${u} or { name = u; provides = { }; includes = [ ]; }; }) (h.users or { }); })) cfg.hosts;
        batteries.primary-user = aspects.primary-user;
        batteries.define-user = aspects.define-user;
        batteries.hostname = aspects.hostname;
        batteries.host-aspects = aspects.host-aspects;
        batteries."inputs'" = aspects."inputs'";
        batteries."self'" = aspects."self'";
        batteries.user-shell = dungeon.batteryFns.user-shell;
        batteries.tty-autologin = dungeon.batteryFns.tty-autologin;
        batteries.unfree = dungeon.batteries.unfree;
        provides = world.batteries;
        _ = world.provides;
        lib.parametric = dungeon.parametric;
        # reference/lib-deprecated.mdx:101-104: plain helper `_unused: used: used`.
        lib.take.unused = _unused: used: used;
        lib.__findFile = dungeon.angle world;
        lib.nh = dungeon.nh cfg.hosts cfg.homes;
        lib.policy = dungeon.channels.lib.policy;
        lib.aspects.resolve = dungeon.resolve world;
        # reference/lib.mdx:62-83: only "host" entities resolve (route.nix host pipeline, resolve.nix); other kinds throw.
        lib.resolveEntity = kind: ctx: if kind == "host" then { __entityKind = "host"; inherit ctx; } else throw "den.lib.resolveEntity: kind `${kind}` unsupported";
        batteries.forward = dungeon.forward world;
        lib.schema = dungeon.schema.lib;
        # den-diagram capture (reference/diag.mdx:321-332) is out of scope (vic 2026-10-20): explicit throw, catchable by tryEval.
        lib.capture.captureFleet = _: throw "dungeon: den.lib.capture.captureFleet not implemented (den-diagram out of scope)";
        lib.closure = dungeon.closure aspects;
        # host entity by name (system = its attr-path key)
        host = name: builtins.head (builtins.concatLists (builtins.attrValues (builtins.mapAttrs (system: hs: if hs ? ${name} then [ (hs.${name} // { inherit system; }) ] else [ ]) cfg.hosts)));
        lib.userModules = h: u: (dungeon.route cfg.schema aspects (world.host h) [ ]).userModules u;
      };
    in
    world;
}
