# Unity on NixOS

This repository packages the Unity 7 desktop for NixOS as a flake and NixOS module. It does not enable Cinnamon.

![Unity on NixOS](docs-unity-proof-of-concept.png)

## Status

The X11 session boots through LightDM and starts the Unity shell, panel, Dash, launcher, indicators, HUD, BAMF, Nemo, Unity Settings Daemon, and Unity Control Center. It includes Ubuntu wallpapers, themes, fonts, desktop portals, Nix application profiles, and Flatpak export paths.

This is development software. Keep another desktop session available while testing. The current target is x86_64-linux with X11. Wayland support will follow after the X11 session is complete.

## Install

Add the input:

```nix
inputs.unity-on-nix = {
  url = "github:soltros/unity-on-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Import the module and enable Unity:

```nix
modules = [
  unity-on-nix.nixosModules.default
  { services.desktopManager.unity.enable = true; }
];
```

The module enables LightDM and the Unity greeter. Rebuild, reboot, and select Unity at login.

Add applications to the system closure with:

```nix
services.desktopManager.unity.extraPackages = with pkgs; [ firefox libreoffice ];
```

Disable LightDM when another display manager is configured:

```nix
services.desktopManager.unity.lightdm.enable = false;
```

## Included

- Unity 7.7.1, Compiz, Nux, panel, launcher, Dash, HUD, and lock screen
- LightDM and the Unity greeter
- Nemo file manager and Unity desktop icons
- Unity Settings Daemon and Unity Control Center
- Applications, files, music, video, photos, and home scopes
- Application, sound, power, session, clock, keyboard, Bluetooth, messages, and network indicators
- Kitty and GNOME Terminal, with GNOME Terminal as the default
- Unity Appearance for themes, icons, fonts, background color, and dock size
- GNOME Screenshot and Print Screen shortcuts
- Ubuntu 26.04 wallpapers and chooser catalogue
- NixOS snowflake launcher button
- PipeWire, GVfs, UDisks, UPower, NetworkManager, polkit, keyring, and XDG portals
- iwgtk for scanning and connecting to Wi-Fi networks
- Network Connections for editing wired, Wi-Fi, and VPN profiles

Only the Cinnamon session manager and shared Cinnamon desktop library are used. The Cinnamon shell and Settings Daemon are excluded.

## Software and Flatpak

GNOME Software is included for browsing, installing, and updating Flatpak apps. The module enables Flatpak and adds the system Flathub remote. Nix packages remain managed through Nix.

The experimental Flatpak Dash lens searches Flatpak catalogue metadata and opens app details in GNOME Software. An empty search shows editor suggestions. The first search may wait for catalogue metadata to download. App-specific artwork and live desktop testing are still pending. A separate Nix lens is planned.

## VM testing

```sh
nix build path:.#nixosConfigurations.unity-test.config.system.build.vm
./result/bin/run-unity-test-vm
```

Log in as `tester` with password `test-only`. SSH forwards to `127.0.0.1:2222` and the VM disk is `unity-test.qcow2`.

Run checks:

```sh
nix flake check path:.
nix build path:.#unity-session
```

The graphical check starts Unity under Xvfb, verifies the launcher and panel, and opens an application window. `tests/install-vm-apps.sh` installs Nix profile and Flatpak applications for manual Dash testing.

## Known limitations

- Reboot and shutdown actions are still being tested across LightDM and logind.
- The Wi-Fi/network panel indicator is a known issue. Open iwgtk from the Dash to scan and connect to Wi-Fi. Network Connections remains available for profile editing; it does not provide a nearby-network scanner.
- Application indexing and icon loading need testing with more Nix and Flatpak applications.
- Some legacy Ubuntu global-menu and online-service integrations are unavailable.
- Graphics, suspend, multi-monitor, locking, and other hardware behavior need broader testing.
- There is no Wayland session yet.

## Sources

Unity and its supporting projects are pinned in the package expressions and `pkgs/sources.json`. The project repository is [github.com/soltros/unity-on-nix](https://github.com/soltros/unity-on-nix).
