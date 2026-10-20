# den.lib.parametric: deprecated identity passthroughs (reference/lib-deprecated.mdx); the pipeline binds scope args itself, content.nix does it here.
dungeon: {
  parametric =
    let
      id = a: a;
    in
    {
      __functor = _: id;
      atLeast = id;
      exactly = id;
      # pins ctx values for resolve (lib-deprecated.mdx:41-49)
      fixedTo = ctx: a: a // { __ctx = ctx; };
    };
}
