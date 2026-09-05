{ pkgs }:
let
  base = import ./components.nix { inherit pkgs; };
  packages = base // (import ./desktop-components.nix { inherit pkgs base; }) // {
    unity-flatpak-scope = import ./flatpak-scope { inherit pkgs; inherit (base) libunity; };
    cinnamon-session-unity = import ./cinnamon-session-unity.nix { inherit pkgs; };
    lomiri-indicator-network = pkgs.lomiri.lomiri-indicator-network;
    compiz = pkgs.callPackage ./compiz.nix {};
    nux = pkgs.callPackage ./nux.nix {};
    unity = pkgs.callPackage ./unity.nix {
      inherit (packages) compiz nux libunity libunity-misc xpathselect libindicator
        ido unity-settings-daemon gtk3-unity gsettings-ubuntu-schemas;
      nixos-icons = pkgs.nixos-icons;
    };
    unity-session = import ./session.nix { inherit pkgs; unityPackages = packages; };
    default = packages.unity-session;
  };
in packages
