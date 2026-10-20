# Opt-in batteries taking an argument (reference/batteries.mdx:100-110, 147-157); each returns an inline aspect.
dungeon: {
  batteryFns = {
    # reference/batteries.mdx:102: login shell at OS + HM level, programs.<shell>.enable + users.users.<name>.shell.
    user-shell =
      shell:
      { user, ... }:
      let
        os = { pkgs, ... }: {
          programs.${shell}.enable = true;
          users.users.${user.userName}.shell = pkgs.${shell};
        };
      in
      {
        nixos = os;
        # darwin: chsh needs the shell listed in /etc/shells (Den apple: environment.shells = [ "/run/current-system/sw/bin/fish" ]).
        darwin = { imports = [ os ]; environment.shells = [ "/run/current-system/sw/bin/${shell}" ]; };
        homeManager.programs.${shell}.enable = true;
      };
    # reference/batteries.mdx:149: TTY1 autologin via a systemd getty drop-in (nixpkgs getty@ ExecStart + --autologin).
    tty-autologin = name: {
      nixos = { pkgs, config, ... }: {
        systemd.services."getty@tty1" = {
          overrideStrategy = "asDropin";
          serviceConfig.ExecStart = [
            ""
            "@${pkgs.util-linux}/sbin/agetty agetty --login-program ${config.services.getty.loginProgram} --autologin ${name} --noclear --keep-baud %I 115200,38400,9600 $TERM"
          ];
        };
      };
    };
  };
}
