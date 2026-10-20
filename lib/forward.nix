# den.batteries.forward (guides/custom-classes.mdx "The forward Battery"): per item, the `fromClass` content of
# `fromAspect item` lands at `intoPath item` of `intoClass item`, read with `adaptArgs` of the target module args.
dungeon: {
  forward =
    world:
    { each, fromClass, intoClass, intoPath, fromAspect, adaptArgs ? (a: a), ... }@spec:
    let
      lib = dungeon.genLib;
      unknown = builtins.attrNames (removeAttrs spec [ "each" "fromClass" "intoClass" "intoPath" "fromAspect" "adaptArgs" ]);
      # shortcut: intoPath is the `item: path` form only; module args requested are the common ones.
      into =
        item:
        {
          __functor = _: args: lib.setAttrByPath (intoPath item) (dungeon.flatten (adaptArgs args) (dungeon.resolve world (fromClass item) (fromAspect item)).imports);
          __functionArgs = { pkgs = true; lib = true; config = true; options = true; };
        };
    in
    if unknown != [ ] then
      throw "den.batteries.forward: unsupported keys ${toString unknown}"
    else
      { includes = map (item: { ${intoClass item} = into item; }) each; };
}
