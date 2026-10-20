# Inner surface: hosts + aspects at ROOT. includes elems must be refs to declared aspects.
dungeon: {
  view =
    let
      inherit (dungeon) gen;
      t = dungeon.genLib.types;
      cat = category: builtins.mapAttrs (_: _: { inherit category; });
      # schema.host.imports fns take the entity itself as `host` (tutorials/microvm.mdx extendHostSchema `{ host, ... }`).
      # bound to the lazy `config` arg, not _module.args: Gen folds declarations before args exist.
      selfArg = m:
        if builtins.isFunction m && (builtins.functionArgs m) ? host then
          { __functor = _: a: m (a // { host = a.config; }); __functionArgs = builtins.removeAttrs (builtins.functionArgs m) [ "host" ] // { config = false; }; }
        else m;
      # quirk names are channel keys (quirks never depend on aspects: no cycle); output classes: guides/flake-outputs.mdx:25-36.
      cnf0Of = c: {
        keySemantics =
          cat "class" { nixos = null; darwin = null; user = null; homeManager = null; os = null; hjem = null; maid = null; }
          # guides/flake-outputs.mdx:26-35: output classes
          // cat "class" { packages = null; apps = null; checks = null; devShells = null; legacyPackages = null; flake = null; }
          // cat "class" c.classes
          // cat "channel" c.quirks;
      };
      # + unregistered class keys found in aspect values (unregistered.nix, derived from cnf0Of)
      cnfOf = c: { keySemantics = (cnf0Of c).keySemantics // cat "class" (builtins.listToAttrs (map (name: { inherit name; value = null; }) c.unregistered)); };
      mkAspects =
        decl:
        let
          cnf = cnfOf decl;
          # nested aspects (Den aspects.mdx:19; gen-aspects "A key with no entry is a nested aspect") are
          # addressed by name `<parent>/<key>`; resolved by path so the world's key set never forces aspect bodies.
          kids = e: builtins.filter (k: gen.aspects.keyCategory cnf k == null && builtins.isAttrs e.${k}) (builtins.attrNames e);
          at = n: builtins.foldl' (e: s: e.${s} or { }) decl.aspects (if decl.aspects ? ${n} then [ n ] else builtins.filter builtins.isString (builtins.split "/" n));
          isRef = b: (at b.name).key or null == b.key;
          authored =
            name: e: k: _:
            let
              c = gen.aspects.keyCategory cnf k;
            in
            if k == "excludes" then
              false
            else if c == null then
              # nested aspect: own entry, its content lands only if included
              if builtins.isAttrs e.${k} then false else throw "den: aspect `${name}`: key `${k}` is not a declared class and not a nested aspect"
            else
              c == "class" && gen.aspects.hasClassContent e.${k};
          norm =
            name: e:
            e
            // builtins.listToAttrs (map (k: { name = k; value = norm "${name}/${k}" e.${k}; }) (kids e))
            # `<aspect>.provides.<n>` is also reachable as `<aspect>.<n>` (reference/aspects.mdx:69); a same-named own key wins.
            // builtins.mapAttrs (c: v: norm "${name}/provides/${c}" v) (removeAttrs (if builtins.isAttrs (e.provides or null) then e.provides else { }) (builtins.attrNames e))
            // dungeon.genLib.optionalAttrs (builtins.isAttrs (e.provides or null)) { _ = norm "${name}/provides" e.provides; }
            // {
              inherit name;
              policyIncs = builtins.filter (p: !builtins.any (x: builtins.isAttrs x && (x.__isPolicy or false) && x.name == p.name) (e.excludes or [ ])) (decl.aspectPolicies.${name} or [ ]);
              includes = gen.prelude.imap0 (
                i: b:
                if isRef b then
                  b
                else
                  throw "den: aspect `${name}`: includes[${toString i}] is not a ref to a declared aspect"
              ) e.includes;
              # policy elements (attrs/functions without an aspect name) are not aspect refs: not closure-excluded here
              excludes = builtins.filter (b: builtins.isAttrs b && b ? name && b ? key && isRef b) (
                gen.prelude.imap0 (
                  i: b:
                  if builtins.isString b then
                    throw "den: aspect `${name}`: excludes[${toString i}] is not of type aspect or function returning aspect (is not of type `aspect or function returning aspect')"
                  else
                    b
                ) (e.excludes or [ ])
              );
              # forces key validation (N2)
              content = gen.prelude.filterAttrs (authored name e) e;
              # unset channel keys surface as null; only authored emissions count
              quirks = gen.prelude.filterAttrs (k: v: v != null && gen.aspects.keyCategory cnf k == "channel") e;
            };
          normed = builtins.mapAttrs norm decl.aspects;
        in
        normed;
    in
    {
      inherit mkAspects cnfOf cnf0Of;
      module =
        { lib, config, ... }:
        {
          options.hosts = lib.mkOption {
            # system-level submodule so each host sees its parent key (class/intoAttr defaults, schema.mdx:139-171).
            type = t.lazyAttrsOf (t.submodule ({ name, ... }: let system = name; in {
              freeformType =
              t.lazyAttrsOf (
                t.submodule (
                  { name, ... }@hargs:
                  {
                    # schema.host.imports (e.g. fleet addr/environment options) extend the entity.
                    # open by default (entities.mdx:183-192); schema.host.isStrict closes it
                    # strict: gen-schema's closed freeform refuses undeclared keys by name (reference/lib.mdx:238-242)
                    imports = map selfArg config.schema.host.imports ++ [ (dungeon.schema.entity config.schema.host) (if config.schema.host.isStrict then gen.schema.mkStrictModule "host" else { freeformType = t.lazyAttrsOf t.raw; }) ];
                    options.name = lib.mkOption { type = t.str; default = name; };
                    options.hostName = lib.mkOption { type = t.str; default = name; };
                    options.system = lib.mkOption { type = t.str; default = system; };
                    # schema.mdx:141 `"nixos"` or `"darwin"` based on system; :166-171 intoAttr by class.
                    options.class = lib.mkOption { type = t.str; default = if builtins.match ".*-darwin" system != null then "darwin" else "nixos"; };
                    options.intoAttr = lib.mkOption { type = t.listOf t.str; default = [ "${hargs.config.class}Configurations" name ]; };
                    options.users = lib.mkOption {
                      type = t.lazyAttrsOf (
                        t.submodule (
                          { name, ... }:
                          {
                            freeformType = t.lazyAttrsOf t.raw;
                            imports = config.schema.user.imports ++ [ (dungeon.schema.entity config.schema.user) ];
                            options.name = lib.mkOption { type = t.str; default = name; };
                            options.userName = lib.mkOption { type = t.str; default = name; };
                            options.classes = lib.mkOption {
                              type = t.listOf t.str;
                              default = [ ];
                            };
                          }
                        )
                      );
                      default = { };
                    };
                  }
                )
              );
            }));
            default = { };
          };
          options.aspects = lib.mkOption {
            type = gen.aspects.aspectsType (cnfOf config);
            default = { };
          };
          # den.default is an aspect: same type as aspects.<n>, then walked as aspects.default.
          options.default = lib.mkOption {
            type = gen.aspects.aspectType (cnfOf config);
            default = { };
          };
          config.aspects.default = config.default;
          # shortcut: raw, no semantics yet; later rungs type these.
          options.schema = lib.mkOption {
            type = t.lazyAttrsOf (
              t.submodule {
                freeformType = t.lazyAttrsOf t.raw;
                options =
                  let
                    rawList = lib.mkOption { type = t.listOf t.raw; default = [ ]; };
                  in
                  {
                    imports = rawList;
                    includes = rawList;
                    excludes = rawList;
                    classes = lib.mkOption { type = t.listOf t.str; default = [ ]; };
                    isStrict = lib.mkOption { type = t.bool; default = false; };
                    isEntity = lib.mkOption { type = t.bool; default = false; };
                  };
              }
            );
            default = { };
          };
          # consumers read schema.host/user unconditionally
          config.schema.host = { };
          config.schema.user = { };
          options.policies = lib.mkOption { type = t.lazyAttrsOf t.raw; default = { }; };
          # builtins are named atoms so schema.<kind>.excludes can reference them (reference/policies.mdx:293-297)
          config.policies = lib.genAttrs dungeon.builtinPolicies (n: { __builtin = n; });
          options.aspectPolicies = lib.mkOption { type = t.lazyAttrsOf (t.listOf t.raw); default = { }; };
          options.policyRecs = lib.mkOption { type = t.lazyAttrsOf (t.lazyAttrsOf t.raw); default = { }; };
          options.rawFns = lib.mkOption { type = t.lazyAttrsOf t.raw; default = { }; };
          options.quirks = lib.mkOption { type = t.lazyAttrsOf t.raw; default = { }; };
          options.classes = lib.mkOption { type = t.lazyAttrsOf t.raw; default = { }; };
          options.homes = lib.mkOption { type = t.lazyAttrsOf (t.lazyAttrsOf t.raw); default = { }; };
          options.systems = lib.mkOption { type = t.listOf t.str; default = [ ]; };
          options.unregistered = lib.mkOption { type = t.listOf t.str; default = [ ]; };
        };
    };
}
