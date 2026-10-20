# Aspect-policy effect constructors (reference/policies.mdx s include); inert descriptors read by route.nix.
dungeon: {
  # reference/policies.mdx:137-140: guard/adaptArgs/collectSubtree pass through to the edge
  effects.route = { fromClass, intoClass, path ? [ ], ... }@spec: spec // { __effect = "route"; inherit path; };
  effects.exclude = x: { __effect = "exclude"; value = x; };
  effects.include = x: { __effect = "include"; value = x; };
  # reference/policies.mdx:142-150: nest-mode provide, delivered by scopes.nix
  effects.provide = { class, module, path ? [ ] }: { __effect = "provide"; inherit class module path; };
}
