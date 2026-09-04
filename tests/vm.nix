{ pkgs, modulesPath, ... }: {
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  system.stateVersion = "26.05";
  networking.hostName = "unity-test";
  virtualisation.memorySize = 4096;
  virtualisation.cores = 4;
  virtualisation.graphics = true;
  services.desktopManager.unity.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.autoLogin.enable = false;
  users.users.tester = {
    isNormalUser = true;
    initialPassword = "test-only";
    extraGroups = [ "networkmanager" "systemd-journal" ];
  };
  environment.systemPackages = [ pkgs.xterm pkgs.xdotool ];
  # Test credentials and automatic login are confined to this VM.
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = true;
  virtualisation.forwardPorts = [{ from = "host"; host.address = "127.0.0.1"; host.port = 2222; guest.port = 22; }];
}
