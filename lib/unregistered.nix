# Unregistered class keys (reference/aspects.mdx "Reserved keys": a key that is not a registered class, quirk or
# nested-aspect shape is a class key of an unregistered class). Shape: every key structural, registered, a function, or nested shape.
# cnf must not contain these classes (they are derived from it).
dungeon: {
  unregistered =
    cnf: raw:
    let
      structural = [ "provides" "_" "includes" "excludes" "policies" "meta" "name" "description" "classes" ];
      known = k: builtins.elem k structural || dungeon.gen.aspects.keyCategory cnf k != null;
      shaped = v: builtins.all (k: known k || builtins.isFunction v.${k} || (builtins.isAttrs v.${k} && shaped v.${k})) (builtins.attrNames v);
      # class names found in one aspect value (and its nested / provided aspects)
      inAspect =
        a:
        if !builtins.isAttrs a then
          [ ]
        else
          builtins.concatMap (
            k:
            let v = a.${k}; in
            if builtins.elem k [ "provides" "_" ] && builtins.isAttrs v then builtins.concatMap inAspect (builtins.attrValues v)
            else if known k then [ ]
            # a function-valued non-class key is a nested parametric aspect (explanation/aspects.mdx:97-104, configure-aspects.mdx:163)
            else if (builtins.isAttrs v && !(v ? _type) && !shaped v) then [ k ]
            else inAspect v
          ) (builtins.attrNames a);
    in
    dungeon.genLib.unique (builtins.concatMap inAspect (builtins.attrValues raw));
}
