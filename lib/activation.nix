# Activation: ONE gen.program model per host tree; atom `<id>@s` = aspect with minted identity <id> is a member of scope s (design-activation.md R1).
# R1 = zero behaviour change: candidates (static closures, delivery, one policy pass) arrive per scope in DFS order; the model decides membership.
# Identity is Gen's mint (dungeon.aspectIdOf, gen-aspects lib/types.nix:1028), never the name: one member per identity per scope.
dungeon: {
  # scopes :: { <scope> = { cands :: [aspect]; ex :: [name]; }; }
  mkActivation =
    scopes:
    let
      id = dungeon.aspectIdOf;
      atom = a: s: "${id a}@${s}";
      # excludes arrive as names (route.nix); they bind to the identities of the candidates carrying that name
      exIds = s: map id (builtins.filter (a: builtins.elem a.name scopes.${s}.ex) scopes.${s}.cands);
      rules = builtins.concatMap (
        s:
        map (a: { head = atom a s; pos = [ ]; neg = [ "x:${atom a s}" ]; relata = [ ]; }) scopes.${s}.cands
        ++ map (i: { head = "x:${i}@${s}"; pos = [ ]; neg = [ ]; relata = [ ]; }) (exIds s)
      ) (builtins.attrNames scopes);
      model = dungeon.gen.program.model {
        program = dungeon.gen.program.program [ ] rules;
        interpretation = [ ];
        prior = null;
        complete = true;
      };
      checked = model.undefinedAtoms == [ ] || throw "den: aspects not stratified: ${toString model.undefinedAtoms}";
      # first candidate per minted identity, candidate (DFS) order kept. Records the aspect type never stamped (route.nix synthetic
      # `<policy>#<i>` / `schema.<kind>#<i>`) carry no id_hash: their name is not an identity (distinct policies share `schema.host`), so they never dedup.
      # shortcut: synthetic records are not deduped; upgrade when route.nix mints them (origin = policy site).
      uniq = builtins.foldl' (acc: a: if !(a ? id_hash) then acc // { out = acc.out ++ [ a ]; } else if acc.seen ? ${a.id_hash} then acc else { seen = acc.seen // { ${a.id_hash} = true; }; out = acc.out ++ [ a ]; }) { seen = { }; out = [ ]; };
    in
    {
      members = s: assert checked; (uniq (builtins.filter (a: (model.resolve (atom a s)).included) scopes.${s}.cands)).out;
    };
}
