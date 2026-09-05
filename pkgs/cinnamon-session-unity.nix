{ pkgs }:
# Unity needs the session manager and libcinnamon-desktop, not the Cinnamon
# shell or its settings daemon. Keep the latter out of the runtime closure.
pkgs.cinnamon-session.overrideAttrs (old: {
  pname = "cinnamon-session-unity";
  buildInputs = builtins.filter (p: p != pkgs.cinnamon-settings-daemon) old.buildInputs
    ++ [ pkgs.gtk3 pkgs.python3Packages.pygobject3 ];
  preFixup = ''
    gappsWrapperArgs+=(--prefix XDG_DATA_DIRS : "${pkgs.cinnamon-desktop}/share")
    gappsWrapperArgs+=(--prefix GI_TYPELIB_PATH : "${pkgs.gtk3}/lib/girepository-1.0")
  '';
  postPatch = (old.postPatch or "") + ''
    substituteInPlace cinnamon-session/csm-manager.c \
      --replace-fail '"org.cinnamon.settings-daemon.plugins.power"' '"org.gnome.desktop.screensaver"' \
      --replace-fail '"lock-on-suspend"' '"ubuntu-lock-on-suspend"'
    substituteInPlace cinnamon-session/csm-manager.c \
      --replace-fail 'cinnamon-screensaver-command --lock' '${pkgs.glib}/bin/gdbus call --session --dest org.gnome.ScreenSaver --object-path /org/gnome/ScreenSaver --method org.gnome.ScreenSaver.Lock'
    # Let GLib interpret the colon-separated XDG_CURRENT_DESKTOP list. Passing
    # "Unity:Unity7:ubuntu" as one desktop name skips Unity's settings daemon.
    substituteInPlace cinnamon-session/csm-autostart-app.c \
      --replace-fail '                                             current_desktop))' '                                             NULL))'
  '';
})
