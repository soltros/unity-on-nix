{ pkgs, modulesPath, ... }: {
  imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
  system.stateVersion = "26.05";
  networking.hostName = "unity-module-test";
  virtualisation.memorySize = 2048;
  virtualisation.cores = 2;
  virtualisation.graphics = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.displayManager.defaultSession = "unity-experimental";
  services.displayManager.autoLogin = { enable = true; user = "tester"; };
  users.users.tester = { isNormalUser = true; initialPassword = "test-only"; };
  services.desktopManager.unityExperimental = {
    enable = true;
    runtimePackage = pkgs.writeShellScriptBin "unity-session" ''
      export XDG_CURRENT_DESKTOP=Unity
      export XDG_SESSION_DESKTOP=unity-experimental
      exec ${pkgs.xterm}/bin/xterm -title 'Unity module wiring test — not the Unity desktop' \
        -e ${pkgs.bash}/bin/bash -c 'echo "Session registration works. Unity runtime packaging is still pending."; exec ${pkgs.bash}/bin/bash'
    '';
  };
}
