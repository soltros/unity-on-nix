{ nixpkgs, pkgs }:
let
  mk = extra: nixpkgs.lib.nixosSystem {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [ ../modules/unity.nix ({ ... }: {
      system.stateVersion = "26.05";
      boot.isContainer = true;
    }) extra ];
  };
  disabled = mk {};
  missing = mk { services.desktopManager.unityExperimental.enable = true; };
  fixture = pkgs.writeShellScriptBin "unity-session" "exit 0";
  enabled = mk {
    services.desktopManager.unityExperimental = { enable = true; runtimePackage = fixture; };
  };
in
assert !disabled.config.services.xserver.enable;
assert disabled.config.services.displayManager.sessionPackages == [];
assert !(builtins.hasAttr "unity" disabled.config.security.pam.services);
assert builtins.any (a: !a.assertion && nixpkgs.lib.hasPrefix "Unity experimental" a.message) missing.config.assertions;
assert enabled.config.services.xserver.enable;
assert builtins.hasAttr "unity" enabled.config.security.pam.services;
assert builtins.any (p: builtins.elem "unity-experimental" p.providedSessions) enabled.config.services.displayManager.sessionPackages;
pkgs.runCommand "unity-module-evaluation-check" {} "touch $out"
