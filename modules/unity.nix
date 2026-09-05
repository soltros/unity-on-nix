{ config, lib, pkgs, ... }:
let
  cfg = config.services.desktopManager.unity;
  u = import ../pkgs { inherit pkgs; };
  runtime = cfg.package;
  greeter = import ../pkgs/greeter-session.nix { inherit pkgs; unityPackages = u; };
  sessionService = description: command: {
    inherit description;
    wantedBy = [ "unity-session.target" ];
    partOf = [ "unity-session.target" ];
    after = [ "graphical-session-pre.target" ];
    # Inherit the login session's PATH imported into the user manager. The
    # NixOS service default hides profile apps and fails desktop TryExec checks.
    environment.PATH = lib.mkForce null;
    serviceConfig = { ExecStart = command; Restart = "on-failure"; RestartSec = 2; };
  };
  indicatorNames = [ "application" "sound" "power" "session" "datetime" "keyboard" "bluetooth" "messages" ];
in {
  options.services.desktopManager.unity = {
    enable = lib.mkEnableOption "the Unity 7 X11 desktop";
    lightdm.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable LightDM with the Unity greeter. Disable to use another display manager.";
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = u.unity-session;
      defaultText = lib.literalExpression "unity-on-nix.packages.x86_64-linux.unity-session";
      description = "Unity session package, including its runtime components.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional desktop applications and session D-Bus services.";
    };
  };
  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
      message = "The Unity port currently supports x86_64-linux only.";
    }];
    # Retain NixOS account-management safeguards with Ubuntu's extra APIs.
    nixpkgs.overlays = [(final: prev: {
      accountsservice = (import ../pkgs/components.nix { pkgs = prev; }).accountsservice-unity;
    })];
    services.xserver.enable = true;
    services.xserver.displayManager.lightdm = lib.mkIf cfg.lightdm.enable {
      enable = true;
      greeters.gtk.enable = false;
      greeter = { package = greeter; name = "unity-greeter"; };
    };
    services.xserver.updateDbusEnvironment = true;
    services.displayManager.sessionPackages = [ runtime ];
    services.displayManager.defaultSession = lib.mkDefault "unity";
    services.dbus.enable = true;
    services.dbus.packages = runtime.components ++ cfg.extraPackages;
    services.accounts-daemon.enable = true;
    services.gnome.at-spi2-core.enable = true;
    services.gnome.gnome-keyring.enable = true;
    services.gnome.evolution-data-server.enable = true;
    services.gnome.glib-networking.enable = true;
    services.gvfs.enable = true;
    services.udisks2.enable = true;
    services.upower.enable = true;
    services.colord.enable = true;
    services.libinput.enable = true;
    networking.networkmanager.enable = lib.mkDefault true;
    # Share iwd with iwgtk; NetworkManager retains IP and DNS configuration.
    networking.networkmanager.wifi.backend = lib.mkDefault "iwd";
    hardware.graphics.enable = true;
    security.polkit.enable = true;
    security.pam.services.unity = {};
    programs.dconf.enable = true;
    xdg.portal = {
      enable = lib.mkDefault true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.unity.default = [ "gtk" ];
    };
    services.pipewire = {
      enable = lib.mkDefault true;
      alsa.enable = lib.mkDefault true;
      pulse.enable = lib.mkDefault true;
    };
    fonts.packages = [ pkgs.ubuntu-classic pkgs.dejavu_fonts ];
    environment.systemPackages =
      [ runtime pkgs.bubblewrap ]
      ++ runtime.components
      ++ cfg.extraPackages;
    environment.pathsToLink = [ "/share/unity" "/share/accountsservice" ];
    systemd.user.targets.unity-session = {
      description = "Unity desktop session";
      requires = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
    };
    systemd.user.services = {
      unity-shell = (sessionService "Unity shell" "${u.compiz}/bin/compiz --replace ccp") // {
        after = [ "graphical-session-pre.target" "unity-panel.service" "unity-bamf.service" "unity-applications-scope.service" ];
      };
      unity-panel = (sessionService "Unity panel service" "${u.unity}/lib/unity/unity-panel-service") // {
        after = [ "graphical-session-pre.target" "unity-bamf.service" ];
      };
      unity-bamf = (sessionService "Unity application matching" "${u.bamf-session}/libexec/bamf/bamfdaemon") // {
        # Type=dbus keeps dependent services queued until BAMF has actually
        # acquired its name; a running process alone is too early for clicks.
        serviceConfig = {
          ExecStart = "${u.bamf-session}/libexec/bamf/bamfdaemon";
          Restart = "on-failure";
          RestartSec = 2;
          Type = "dbus";
          BusName = "org.ayatana.bamf";
        };
      };
      unity-applications-scope = (sessionService "Unity installed applications search"
        "${u.libunity}/bin/unity-scope-loader applications/applications.scope applications/scopes.scope commands.scope") // {
        serviceConfig = {
          ExecStart = "${u.libunity}/bin/unity-scope-loader applications/applications.scope applications/scopes.scope commands.scope";
          Restart = "on-failure";
          RestartSec = 2;
          Type = "dbus";
          BusName = "com.canonical.Unity.Scope.Applications";
        };
      };
      unity-ibus = sessionService "Unity input methods" "${pkgs.ibus}/bin/ibus-daemon --xim";
      unity-hud = sessionService "Unity HUD" "${u.hud}/libexec/hud/hud-service";
      unity-nemo = sessionService "Unity desktop icons" "${pkgs.nemo}/bin/nemo-desktop";
      unity-network = sessionService "Unity network indicator" "${u.lomiri-indicator-network}/libexec/lomiri-indicator-network/lomiri-indicator-network-service" // {
        serviceConfig = {
          ExecStart = "${u.lomiri-indicator-network}/libexec/lomiri-indicator-network/lomiri-indicator-network-service";
          Restart = "on-failure";
          RestartSec = 2;
        };
        after = [ "unity-panel.service" "unity-indicator-application.service" ];
      };
      unity-polkit = sessionService "Unity authentication agent" "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    } // lib.listToAttrs (map (name: {
      name = "unity-indicator-${name}";
      value = sessionService "Unity ${name} indicator"
        "${u."indicator-${name}"}/libexec/indicator-${name}/indicator-${name}-service";
    }) indicatorNames);
  };
}
