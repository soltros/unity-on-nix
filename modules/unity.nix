{ config, lib, pkgs, ... }:
let
  cfg = config.services.desktopManager.unityExperimental;
  session = pkgs.runCommand "unity-experimental-session" {
    passthru.providedSessions = [ "unity-experimental" ];
  } ''
    mkdir -p $out/share/xsessions
    cat > $out/share/xsessions/unity-experimental.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Unity (experimental)
    Comment=Isolated Unity 7 port experiment
    Exec=${cfg.runtimePackage}/bin/unity-session
    TryExec=${cfg.runtimePackage}/bin/unity-session
    DesktopNames=Unity;
    EOF
  '';
in {
  options.services.desktopManager.unityExperimental = {
    enable = lib.mkEnableOption "the experimental Unity 7 desktop session";
    runtimePackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = ''
        A packaged Unity 7 runtime providing bin/unity-session. Its wrapper
        must initialize and supervise Compiz 0.9, Unity services, settings,
        schemas and plugin discovery, and clean up on logout. No working
        runtime is supplied yet; enabling without one fails evaluation.
      '';
    };
    supportPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional Unity D-Bus services, schemas and runtime data packages.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      assertions = [{
        assertion = cfg.runtimePackage != null;
        message = "Unity experimental requires runtimePackage: the Unity 7/Compiz 0.9 runtime is not packaged yet. See the separate unity-nixos README.";
      }];
      services.xserver.enable = true;
      services.dbus.enable = true;
      programs.dconf.enable = true;
      security.polkit.enable = true;
      # Unity's UserAuthenticatorPam.cpp calls pam_start("unity", ...).
      security.pam.services.unity = {};
    }
    (lib.mkIf (cfg.runtimePackage != null) {
      services.displayManager.sessionPackages = [ session ];
      environment.systemPackages = [ cfg.runtimePackage ] ++ cfg.supportPackages;
      services.dbus.packages = [ cfg.runtimePackage ] ++ cfg.supportPackages;
    })
  ]);
}
