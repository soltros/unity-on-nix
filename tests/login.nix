{ pkgs }:
pkgs.testers.runNixOSTest {
  name = "unity-lightdm-login";
  node.pkgsReadOnly = false;
  nodes.machine = { lib, pkgs, ... }: {
    imports = [ ../modules/unity.nix ];
    services.desktopManager.unity.enable = true;
    services.displayManager.autoLogin = { enable = true; user = "tester"; };
    users.users.tester = { isNormalUser = true; uid = 1000; extraGroups = [ "networkmanager" ]; };
    # CI has no internet; catalogue setup is covered by module evaluation.
    systemd.services.unity-flathub.wantedBy = lib.mkForce [];
    virtualisation.memorySize = 4096;
    virtualisation.cores = 2;
    environment.systemPackages = [ pkgs.xdotool pkgs.xterm ];
    system.stateVersion = "26.05";
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("display-manager.service")
    machine.wait_for_x()
    machine.wait_until_succeeds("test -S /run/user/1000/bus")
    user = "su - tester -c 'env XDG_RUNTIME_DIR=/run/user/1000 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus "
    machine.wait_until_succeeds(user + "systemctl --user is-active unity-shell unity-panel unity-bamf'")
    machine.wait_until_succeeds("DISPLAY=:0 XAUTHORITY=/home/tester/.Xauthority xdotool search --name unity-launcher")
    machine.wait_until_succeeds("DISPLAY=:0 XAUTHORITY=/home/tester/.Xauthority xdotool search --name unity-panel")
    machine.succeed(user + "systemctl --user show-environment' > /tmp/unity-environment")
    machine.succeed("grep '^XDG_DATA_DIRS=' /tmp/unity-environment")
    machine.succeed("grep '^GSETTINGS_SCHEMA_DIR=' /tmp/unity-environment")
    machine.succeed(user + "env DISPLAY=:0 XAUTHORITY=/home/tester/.Xauthority gnome-terminal --title=unity-login-terminal'")
    machine.wait_until_succeeds("DISPLAY=:0 XAUTHORITY=/home/tester/.Xauthority xdotool search --name unity-login-terminal")
    machine.screenshot("unity-login")
  '';
}
