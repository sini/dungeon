dungeon:
let
  denArgs = [ "host" "user" "home" ];
  # lowered inline includes (entry.nix) are setFunctionArgs functors, not lambdas
  isFn = v: builtins.isFunction v || (builtins.isAttrs v && v ? __functor && v ? __functionArgs);
  # only den ctx args (and quirk pools the caller binds) trigger binding; nixpkgs-style module fns pass through untouched
  isDen = args: f: builtins.any (n: builtins.elem n denArgs || args ? ${n}) (builtins.attrNames (dungeon.genLib.functionArgs f));
  # collision policy (reference/aspects.mdx:178-207): entity level, most specific bound entity first; the kind level is
  # folded into each entity (eval.nix); global default "error". shortcut: aspect meta.collisionPolicy and
  # den.config.classModuleCollisionPolicy are not read, add when a fleet sets them.
  policyOf = args: builtins.foldl' (p: k: if p != null then p else if builtins.isAttrs (args.${k} or null) then args.${k}.collisionPolicy or null else null) null [ "home" "user" "host" ];
  strategy = { error = "error"; den-wins = "bind-wins"; class-wins = "system-wins"; };
  # gen-bind's collision report, in den's vocabulary
  denMsg = builtins.replaceStrings [ "gen-bind: binding" "bind-wins" "system-wins" ] [ "den: class module arg" "den-wins" "class-wins" ];
  # gen-bind's merge validator (gen-bind merge-strategy.nix mkMergeValidator, returned by wrap.nix) defines `warnings`;
  # a target without a `warnings` option gets no data: den-wins/class-wins trace, error still throws when the config is forced.
  validatorModule = validator: margs:
    let
      has = (margs.options or { }) ? warnings;
      # `_module.args` read through its option, not `config`: under a freeformType `config` itself waits on this definition
      ws = map denMsg (validator (margs // { config._module.args = margs.options._module.args.value or { }; })).warnings;
    in
    { config.warnings = { _type = "if"; condition = if has then true else builtins.foldl' (acc: w: builtins.trace "evaluation warning: ${w}" acc) false ws; content = ws; }; };
  bind =
    ms: args: v:
    let
      p = policyOf args;
      w = dungeon.gen.bind.wrap { bindings = args; mergeStrategies = ms; defaultMergeStrategy = strategy.${if p == null then "error" else p}; } v;
      # full application (every arg a den arg) never reaches the module system: no collision (class-modules.mdx:166)
      partial = builtins.any (n: !(args ? ${n})) (builtins.attrNames (dungeon.genLib.functionArgs v));
    in
    if partial && w.validator != null then { imports = [ w.module (validatorModule w.validator) ]; } else w.module;
  walk =
    ms: args: v:
    if isFn v then
      (if isDen args v then bind ms args v else v)
    else if builtins.isAttrs v && v ? imports && builtins.isList v.imports then
      v // { imports = map (walk ms args) v.imports; }
    else
      v;
in
{
  content.classModule = walk { };
  # `keys` are bound over a module-system arg of the same name (bind-wins): pipe.to data shadows the unmodified pool
  content.classModuleOver = keys: walk (builtins.listToAttrs (map (name: { inherit name; value = "bind-wins"; }) keys));
}
