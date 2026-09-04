# Unity 7 on NixOS

A standalone flake packaging Ubuntu Unity 7 and its supporting desktop services.
The module is separate from your NixOS configuration until you import and enable
it. Development currently targets **x86_64-linux and X11**.

**Status: experimental, undergoing real-session testing.** The complete package
set builds, and a graphical smoke test renders the Unity launcher, panel and Dash
windows. The isolated NixOS VM builds and boots. Login integration and desktop
features are still being tested; this is not yet a release-ready desktop.

## Use as a flake input

Add the repository directly to your flake inputs:

```nix
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  unity-on-nix = {
    url = "github:soltros/unity-on-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
};
```

Add these entries to your `nixosSystem.modules` list:

```nix
inputs.unity-on-nix.nixosModules.default
{
  services.desktopManager.unity.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
}
```

Select **Unity** at login. The module also sets Unity as the default session
unless your configuration specifies another default. It does not enable automatic
login. A display manager must be enabled separately; LightDM is used by the test VM.
The packaged Unity greeter is not yet selected by the module.

The repository is [soltros/unity-on-nix](https://github.com/soltros/unity-on-nix).
For local development, you can instead use `path:/absolute/path/to/unity-on-nix`.
`inputs.nixpkgs.follows` is supported, but validation currently uses the revision
in `flake.lock` (NixOS 26.05). Other revisions, including unstable, require testing.

Optional module settings:

```nix
services.desktopManager.unity.extraPackages = [ pkgs.firefox ];
```

`services.desktopManager.unity.package` accepts an alternate session package with
`providedSessions` and `components` passthru attributes. Individual packages are
also exported under `packages.x86_64-linux`, and `overlays.default` exposes them
as `pkgs.unity7`. Building the default package does not register a desktop session;
NixOS system integration is provided by the module.

## Test without changing your host

```sh
nix build path:.#nixosConfigurations.unity-test.config.system.build.vm
./result/bin/run-unity-test-vm
```

The VM uses an unprivileged `tester` account, password `test-only`, with automatic
login. These credentials apply only to the VM. SSH is forwarded from host
`127.0.0.1:2222` to the guest. The VM creates `unity-test.qcow2` in the launch
directory. Hardware virtualization is recommended; QEMU falls back to software
emulation when KVM is unavailable.

For package and smoke checks:

```sh
nix build path:.#unity-session
nix flake check path:.
```

The checks cover disabled-module isolation, session/PAM registration, patched
AccountsService integration, Compiz/Nux interfaces, and a software-rendered X11
Unity shell. The shell check requires actual launcher and panel windows and
rejects a failed unityshell plugin load. It does not establish complete login,
lock-screen, indicator, or application-search functionality.

Use `path:.` while files are untracked: Git-backed flakes otherwise omit them.

## Included components

| Component | Packaging status |
| --- | --- |
| Unity 7.7.1 shell, launcher, Dash, panel and lock screen | Builds; shell renders in graphical smoke test |
| Compiz 0.9.14.2 and Nux 4.0.8 | Built with modern compiler/library fixes |
| Unity settings daemon and control center | Built; runtime panel checks pending |
| HUD and GTK global menu module | Built; application integration checks pending |
| Application, sound, power, session, clock, keyboard, Bluetooth and messages indicators | Built and supervised with the Unity session |
| Home, applications, files, music, local video and Shotwell photo scopes | Built; search checks pending |
| BAMF application matching and Zeitgeist history | Included; runtime checks pending |
| Unity greeter | Built; LightDM integration pending |
| Nemo desktop, NetworkManager applet, polkit and notifications | Included |
| Ambiance theme, Ubuntu icons and fonts | Included |

The module configures session-specific user services, D-Bus, dconf, the Unity PAM
service, graphics, keyring, storage/power services, and default NetworkManager and
PipeWire support. It uses Ubuntu's AccountsService extensions while retaining
NixOS account-management patches. Session environment variables are imported at
login and restored when the session ends.

## Sources and compatibility

Unity comes from [Ubuntu Unity's source repository](https://gitlab.com/ubuntu-unity/unity/unity)
at commit `6f01ccb7395ca0fb3ee5f220263d9704a18ce194`. The session definition comes
from its `unity-session` project at commit
`32c2fd569b0d51e40bd3ec875e77f0261a744d03`. Ubuntu source package versions, download
URLs and hashes are recorded in `pkgs/sources.json`; each recipe applies the
relevant Debian patch series. Nixpkgs dependencies are pinned by `flake.lock`.

Compatibility changes include Nix store installation paths, cross-package
indicator discovery, Ubuntu GTK extensions, AccountsService APIs, current
GLib/GCC/CMake compatibility, service launchers, and schema assembly.

Current omissions and limits:

- Retired remote video and online photo providers are not installed. Local video
  and Shotwell photo providers are packaged. Removed web services cannot be
  restored by packaging their old clients.
- Ubuntu APT software suggestions are disabled; installed-application search is
  retained. Nix software discovery has not been implemented.
- The control center's legacy online-accounts and webcam-capture integrations
  are omitted. IBus support is built; FCITX control-center integration is disabled.
- Compiz's old Python settings GUI, optional protobuf cache and separate GTK
  window decorator are omitted. Unity supplies its own window decorations.
- This is an X11 desktop, with no Wayland session or non-NixOS integration.
- Real login, logout cleanup, lock/unlock, global menus, multimedia controls,
  local search and hardware behavior need completion of the VM/hardware checks.

Build success is recorded separately from runtime verification throughout this
project. Do not use the current snapshot as your only desktop session.
