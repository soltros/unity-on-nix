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
assert builtins.elem "unity-session.target" enabled.config.systemd.user.services.unity-shell.partOf;
assert enabled.config.systemd.user.services.unity-session-manager.serviceConfig.Restart == "no";
pkgs.runCommand "unity-module-evaluation-check" {} "touch $out"
