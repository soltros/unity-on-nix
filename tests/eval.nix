{ nixpkgs, pkgs }:
let
  mk = extra: nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [ ../modules/unity.nix {
      system.stateVersion = "26.05";
      boot.isContainer = true;
    } extra ];
  };
  disabled = mk {};
  enabled = mk { services.desktopManager.unity.enable = true; };
in
assert !disabled.config.services.xserver.enable;
assert disabled.config.services.displayManager.sessionPackages == [];
assert !(builtins.hasAttr "unity" disabled.config.security.pam.services);
assert enabled.config.services.xserver.enable;
assert builtins.hasAttr "unity" enabled.config.security.pam.services;
assert builtins.any (p: builtins.elem "unity" p.providedSessions) enabled.config.services.displayManager.sessionPackages;
assert enabled.pkgs.accountsservice.unityPatched;
assert enabled.config.xdg.portal.enable;
assert builtins.elem enabled.pkgs.xdg-desktop-portal-gtk enabled.config.xdg.portal.extraPortals;
assert builtins.elem "unity-session.target" enabled.config.systemd.user.services.unity-shell.partOf;
assert enabled.config.services.xserver.displayManager.lightdm.enable;
assert enabled.config.services.xserver.displayManager.lightdm.greeter.name == "unity-greeter";
assert !enabled.config.services.xserver.desktopManager.cinnamon.enable;
assert !(builtins.elem enabled.pkgs.cinnamon-settings-daemon enabled.config.environment.systemPackages);
pkgs.runCommand "unity-module-evaluation-check" {} "touch $out"
