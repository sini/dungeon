# Inner module pre-declaring battery aspects (design-gen.md §4; content ASSUMED from Den docs).
dungeon: {
  # reference/batteries.mdx:349: names -> nixpkgs.config.allowUnfreePredicate in nixos, darwin, homeManager.
  # The predicate builder is a keyed module, so every include imports it once per target eval (stands in for den.default).
  # shortcut: user-included names are not lifted onto the host OS config (batteries.mdx:349); add with user->host routing.
  batteries.unfree =
    names:
    let
      predicate = { config, lib, ... }: {
        key = "dungeon:batteries:unfree";
        options.unfree.packages = lib.mkOption { type = lib.types.listOf lib.types.str; default = [ ]; };
        config.nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) config.unfree.packages;
      };
      m = { imports = [ predicate ]; unfree.packages = names; };
    in
    { nixos = m; darwin = m; homeManager = m; };
  batteries.module = { config, ... }: let withSystem = config._module.args.withSystem; homeOf = sys: n: if builtins.match ".*-darwin" sys != null then "/Users/${n}" else "/home/${n}"; in {
    # reference/batteries.mdx:88: NixOS wheel+networkmanager; Darwin system.primaryUser.
    aspects.primary-user.user =
      { host, ... }:
      if host.class == "nixos" then { isNormalUser = true; extraGroups = [ "wheel" "networkmanager" ]; } else { };
    aspects.primary-user.darwin = { user, ... }: { system.primaryUser = user.userName; };
    # `user` class = users.users.<user> (route.userPart flattens it with {host,user}).
    # reference/batteries.mdx:27: home /Users/<n> on Darwin, /home/<n> elsewhere; isNormalUser on NixOS only.
    aspects.define-user.user =
      { host, user, ... }:
      {
        name = user.userName;
        home = homeOf host.system user.userName;
      } // (if host.class == "nixos" then { isNormalUser = true; } else { });
    aspects.define-user.homeManager =
      { user, ... }:
      let n = user.userName or user.name; in
      {
        home.username = n;
        home.homeDirectory = homeOf (user.system or user.host.system) n;
      };
    # marker: route.hm gives users whose closure holds it the host closure's homeManager content
    aspects.host-aspects.description = "Project the host aspect closure's homeManager content onto the including user";
    # reference/batteries.mdx:41: NixOS and Darwin.
    aspects.hostname.nixos = { host, ... }: { networking.hostName = host.hostName; };
    aspects.hostname.darwin = { host, ... }: { networking.hostName = host.hostName; };
    # inputs'/self' via flake-parts withSystem; system from the bound host/user/home entity.
    aspects."inputs'".homeManager = { user, ... }: { _module.args."inputs'" = withSystem (user.system or user.host.system) (ps: ps."inputs'"); };
    aspects."inputs'".nixos = { host, ... }: { _module.args."inputs'" = withSystem host.system (ps: ps."inputs'"); };
    aspects."self'".homeManager = { user, ... }: { _module.args."self'" = withSystem (user.system or user.host.system) (ps: ps."self'"); };
    aspects."self'".nixos = { host, ... }: { _module.args."self'" = withSystem host.system (ps: ps."self'"); };
  };
}
