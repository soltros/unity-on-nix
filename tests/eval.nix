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
assert enabled.pkgs.gtk3.drvPath == pkgs.gtk3.drvPath;
assert enabled.config.services.flatpak.enable;
assert enabled.config.systemd.services.unity-flathub.serviceConfig.Type == "oneshot";
assert enabled.config.xdg.portal.enable;
assert builtins.elem enabled.pkgs.xdg-desktop-portal-gtk enabled.config.xdg.portal.extraPortals;
assert builtins.elem "unity-session.target" enabled.config.systemd.user.services.unity-shell.partOf;
assert enabled.config.services.xserver.displayManager.lightdm.enable;
assert enabled.config.services.xserver.displayManager.lightdm.greeter.name == "unity-greeter";
assert builtins.hasAttr "unity-bamf" enabled.config.systemd.user.services;
assert enabled.config.systemd.user.services.unity-bamf.serviceConfig.Type == "dbus";
assert builtins.hasAttr "unity-applications-scope" enabled.config.systemd.user.services;
assert enabled.config.systemd.user.services.unity-applications-scope.serviceConfig.Type == "dbus";
assert enabled.config.systemd.user.services.unity-applications-scope.environment.PATH == null;
assert enabled.config.systemd.user.services.unity-shell.environment.PATH == null;
assert enabled.config.systemd.user.services.unity-applications-scope.serviceConfig.BusName == "com.canonical.Unity.Scope.Applications";
assert !enabled.config.services.xserver.desktopManager.cinnamon.enable;
assert !(builtins.elem enabled.pkgs.cinnamon-settings-daemon enabled.config.environment.systemPackages);
pkgs.runCommand "unity-module-evaluation-check" {} "touch $out"
