{ pkgs }:
# Unity needs the session manager and libcinnamon-desktop, not the Cinnamon
# shell or its settings daemon. Keep the latter out of the runtime closure.
pkgs.cinnamon-session.overrideAttrs (old: {
  pname = "cinnamon-session-unity";
  buildInputs = builtins.filter (p: p != pkgs.cinnamon-settings-daemon) old.buildInputs;
  preFixup = ''
    gappsWrapperArgs+=(--prefix XDG_DATA_DIRS : "${pkgs.cinnamon-desktop}/share")
  '';
  postPatch = (old.postPatch or "") + ''
    # Let GLib interpret the colon-separated XDG_CURRENT_DESKTOP list. Passing
    # "Unity:Unity7:ubuntu" as one desktop name skips Unity's settings daemon.
    substituteInPlace cinnamon-session/csm-autostart-app.c \
      --replace-fail '                                             current_desktop))' '                                             NULL))'
  '';
})
