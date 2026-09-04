# Unity 7 on NixOS — separate experiment

This directory is a standalone flake and NixOS module. Nothing imports it into
the host configuration. **It does not yet contain a working Unity runtime.**
The flake now includes Compiz 0.9 and Nux 4 package definitions. The module
and VM session wiring can be tested independently. The VM diagnostic opens
a labelled terminal, not Unity.

## Foundation packages

```sh
nix build path:.#compiz --out-link result-compiz
nix build path:.#nux --out-link result-nux
nix build path:.#checks.x86_64-linux.foundations
```

Sources are hash-pinned Ubuntu source packages:

- Compiz `0.9.14.2+25.10.20250930-0ubuntu3`, including libcompizconfig,
  its GSettings backend, and compositor plugins. The Python settings GUI,
  GTK window decorator and optional protobuf cache are omitted in this
  foundation build. Unity supplies its own window decorations.
- Nux `4.0.8+18.10.20180623-0ubuntu14`, with Ubuntu's patch series applied,
  including PCRE2, ICU and modern Boost compatibility changes. Gestures
  are enabled using Geis. The helper is installed at
  `result-nux/libexec/nux/unity_support_test`.

The foundation check verifies pkg-config dependency discovery, Compiz's
CMake integration, a C++ consumer linked against Nux, Compiz's version
command, the Nux helper's startup, and library resolution for Unity's four
required Compiz plugins. It does not start a graphical desktop. Upstream graphical test
suites are disabled in these initial package builds.

These packages are outputs of this flake only; they do not replace host
packages, register a host session, or complete the `runtimePackage` contract.

## Test the module separately

From this directory:

```sh
nix flake check path:.
nix build path:.#nixosConfigurations.unity-module-test.config.system.build.vm
./result/bin/run-unity-module-test-vm
```

The diagnostic VM uses an unprivileged `tester` account, password `test-only`,
with automatic login. These settings belong only to the VM. A successful
diagnostic opens a terminal saying that runtime packaging is pending. Close
the terminal to end the diagnostic session. The VM may create a disk image
in the directory from which it is launched.

## Module interface for the real runtime

In a future test configuration, import `modules/unity.nix` and set:

```nix
services.desktopManager.unityExperimental = {
  enable = true;
  runtimePackage = myUnityRuntime;
  supportPackages = [ ];
};
```

`myUnityRuntime` must be a real derivation exposing `bin/unity-session`.
It is deliberately not defaulted to an unrelated package or placeholder.
Enabling without a runtime raises an explanatory assertion. The module
registers an X11 session, enables D-Bus, dconf and polkit, and creates the
`unity` PAM service requested by Unity's lock screen. It does not choose a
display manager or enable automatic login outside the diagnostic VM.

The runtime wrapper must set Unity's session environment, arrange schema,
indicator and Compiz plugin discovery, start the required supporting daemons,
supervise Compiz, and stop its services at logout. Package wrappers must supply
the necessary XDG data paths; installing packages alone is insufficient.
User systemd units should be explicitly integrated with session lifetime,
not started globally for every desktop. The PAM definition is an initial
integration point; real lock/unlock behavior still requires runtime testing.

## Source audit and implementation order

Inspected upstream Unity 7.7.1 at commit
`6f01ccb7395ca0fb3ee5f220263d9704a18ce194`:
[source](https://gitlab.com/ubuntu-unity/unity/unity/-/tree/6f01ccb7395ca0fb3ee5f220263d9704a18ce194).
This is a source review, not evidence of a successful Unity build.

1. **Compiz 0.9 and Nux 4 foundation: built.** The root CMake file requires
   `compiz >= 0.9.11` and `nux-4.0 >= 4.0.5`. The unityshell plugin also needs
   Compiz's composite, opengl, compiztoolbox and scale interfaces. Use a
   compatible Compiz 0.9 source revision; Compiz Reloaded 0.8 is not a drop-in
   replacement. The new definitions pin both sources. Building these
   dependencies does not yet establish compatibility with the complete Unity
   shell; that needs the next build stage.
2. **Complete the build dependency set.** The installed Nixpkgs revision
   `02e08985a27c65ffd33d434eeb2e660a2e4dc84d` exposes BAMF, Dee, libunity,
   libindicator, libdbusmenu, Geis and Zeitgeist. Attribute checks did not find
   `compiz`, `nux`, `libunity-misc`, `xpathselect`, `unity-settings-daemon`,
   `gsettings-ubuntu-schemas`, `unity-gtk-module`, `libido` or `hud` under those
   names. Compiz and Nux are now supplied by this flake. This is not an
   exhaustive search for alternate package names.
   Existing libraries still need version/API verification, especially
   libunity's private protocol and libindicator's service API.
3. **Patch installation and discovery paths.** `services/CMakeLists.txt`
   hardcodes `/usr/lib/systemd/user`. `data/CMakeLists.txt` obtains an install
   directory from systemd, potentially pointing into a different store
   output. `data/compiz/CMakeLists.txt` similarly installs into directories
   read from libcompizconfig. Redirect all installs to Unity's own output.
   Enable `GSETTINGS_LOCALINSTALL=ON` and handle schema compilation through
   Nix packaging. Patch `/usr/bin/compiz` in `data/unity7.service.in` and
   `/usr/lib/nux/unity_support_test` in `tools/compiz-profile-selector.in`.
   `tools/systemd-prestart-check` assumes an Ubuntu session file and older
   cgroup layout; use explicit NixOS session supervision instead.
4. **Assemble the runtime.** The top-level CMake file derives indicator
   discovery directories from libindicator's prefix, while
   `services/panel-service.c` scans those fixed directories. Separate Nix
   package outputs require a combined data directory or patched search
   paths. Expose schemas, icons, D-Bus services and Compiz plugin metadata
   deliberately. Package a compatible session manager or implement equivalent
   startup/lifetime handling. Add the settings daemon, local application/file
   scopes and indicators to reach a useful desktop; add HUD/global-menu
   integration afterward.
5. **Replace the VM fixture with the real runtime.** Verify graphical login,
   launcher and Dash, application matching, indicators, settings persistence,
   lock/unlock, logout and service cleanup. Use an accelerated X11 VM or test
   hardware as needed. A successful module evaluation does not test graphics.

The source implements Unity as a Compiz plugin. Preserving the existing
desktop means targeting X11 first. Disabling `ENABLE_X_SUPPORT` excludes
the shell, panel and lock screen; it does not produce a Wayland desktop.

## Validation

`tests/eval.nix` checks disabled-module isolation, the missing-runtime
assertion, and session/PAM registration when supplied a fixture package.
The module evaluation checks passed against the installed Nixpkgs revision
above, and the diagnostic VM derivation evaluated successfully. No graphical
VM boot or real Unity compilation has been performed. `nix flake check
path:. --no-build` also passed against the committed lock file, which pins
Nixpkgs `a5cc6f2c37bf518436dc8d1c288ccd0c43c2f4c4`.

On 2026-09-04, both foundation package builds and **`nix flake check path:.`**
(including actual check builds) passed on x86_64-linux against that lock file.
The initial consumer check caught Compiz's missing installed library search
path; the package now supplies an install RPATH for its libraries and plugins.
The CMake probe still prints a warning about `uuid.pc` during optional static
dependency discovery. Shared-library discovery, linking, executable startup
and the required plugin library checks pass; static linking is not validated.

Next: package Unity's missing small libraries and settings daemon, then build
the shell against this foundation. The diagnostic VM remains a session-wiring
test until a real `unity-session` runtime replaces its fixture.
