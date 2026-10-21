# den.batteries.forward (guides/custom-classes.mdx "The forward Battery"): per item, the `fromClass` content of
# `fromAspect item` lands at `intoPath item` of `intoClass item`, read with `adaptArgs` of the target module args.
dungeon: {
  forward =
    world:
    { each, fromClass, intoClass, intoPath, fromAspect, adaptArgs ? (a: a), guard ? null, ... }@spec:
    let
      lib = dungeon.genLib;
      unknown = builtins.attrNames (removeAttrs spec [ "each" "fromClass" "intoClass" "intoPath" "fromAspect" "adaptArgs" "guard" ]);
      # custom-classes.mdx:204 `guard = args: bool or item: mkIf`: a bool gates the item, a fn of the item wraps its content
      guarded =
        args: item: content:
        if guard == null then content
        else
          let g = guard (builtins.intersectAttrs (lib.functionArgs guard) args); in
          if builtins.isBool g then lib.mkIf g content
          else if lib.isFunction g then g item content
          else throw "den.batteries.forward: guard returned neither a bool nor an `item: mkIf` function";
      # shortcut: intoPath is the `item: path` form only; module args requested are the common ones.
      into =
        item:
        {
          __functor = _: args: lib.setAttrByPath (intoPath item) (guarded args item (dungeon.flatten (adaptArgs args) (dungeon.resolve world (fromClass item) (fromAspect item)).imports));
          __functionArgs = { pkgs = true; lib = true; config = true; options = true; } // lib.optionalAttrs (guard != null) (lib.functionArgs guard);
        };
    in
    if unknown != [ ] then
      throw "den.batteries.forward: unsupported keys ${toString unknown}"
    else
      { includes = map (item: { ${intoClass item} = into item; }) each; };
}
