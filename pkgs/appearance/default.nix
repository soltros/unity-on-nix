{ pkgs, unityPackages }:
let
  u = unityPackages;
  python = pkgs.python3.withPackages (p: [ p.pygobject3 ]);
  schemaPackages = [ u.compiz u.unity u.gsettings-desktop-schemas-unity
    u.gsettings-ubuntu-schemas u.unity-settings-daemon pkgs.nemo
    u.indicator-datetime u.indicator-power u.indicator-sound u.indicator-session
    u.indicator-bluetooth pkgs.notify-osd u.hud ];
in pkgs.stdenvNoCC.mkDerivation {
  pname = "unity-appearance";
  version = "0.2.0";
  src = ./.;
  nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
  buildInputs = [ u.gtk3-unity pkgs.glib ] ++ schemaPackages;
  installPhase = ''
    install -Dm755 app.py $out/bin/unity-theme-settings
    install -m644 settings.json $out/bin/settings.json
    install -m644 choices.json $out/bin/choices.json
    substituteInPlace $out/bin/unity-theme-settings \
      --replace-fail '#!/usr/bin/env python3' '#!${python}/bin/python3'
  '';
}
