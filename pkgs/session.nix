{ pkgs, unityPackages }:
let
  inherit (pkgs) lib;
  u = unityPackages;
  components = with u; [
    gsettings-desktop-schemas-unity gsettings-ubuntu-schemas
    cinnamon-session-unity
    unity compiz nux libunity gtk3-unity unity-settings-daemon unity-control-center unity-greeter
    unity-asset-pool unity-gtk-module bamf-session hud unity-scope-home unity-lens-applications
    unity-lens-files unity-lens-music unity-lens-video unity-lens-photos
    indicator-appmenu indicator-application indicator-sound
    indicator-power indicator-session indicator-datetime indicator-keyboard
    indicator-bluetooth indicator-messages
  ] ++ (with pkgs; [
    cinnamon-desktop libgnomekbd ibus glib.bin nemo lxappearance
    zeitgeist notify-osd networkmanagerapplet polkit_gnome
    ubuntu-themes adwaita-icon-theme ubuntu-classic dejavu_fonts gnome-terminal kitty
  ]);
  data = pkgs.buildEnv {
    name = "unity-session-data";
    paths = components;
    pathsToLink = [ "/share" ];
    ignoreCollisions = true;
  };
  indicators = pkgs.buildEnv {
    name = "unity-indicators";
    paths = with u; [ indicator-appmenu indicator-application indicator-sound
      indicator-power indicator-session indicator-datetime indicator-keyboard
      indicator-bluetooth indicator-messages ];
    pathsToLink = [ "/lib/indicators" "/share/unity/indicators" ];
  };
  schemas = pkgs.runCommand "unity-session-schemas" { nativeBuildInputs = [ pkgs.glib ]; } ''
    mkdir -p $out/share/glib-2.0/schemas
    ${lib.concatMapStringsSep "\n" (p: ''
      for dir in ${p}/share/glib-2.0/schemas ${p}/share/gsettings-schemas/*/glib-2.0/schemas; do
        if [ -d "$dir" ]; then
          for file in "$dir"/*.xml; do
            [ -f "$file" ] || continue
            target="$out/share/glib-2.0/schemas/$(basename "$file")"
            [ -e "$target" ] || cp "$file" "$target"
          done
        fi
      done
    '') components}
    cat >$out/share/glib-2.0/schemas/90-unity-nixos.gschema.override <<'EOF'
    [org.gnome.desktop.interface]
    gtk-theme='Ambiance'
    icon-theme='ubuntu-mono-dark'
    font-name='Ubuntu 11'
    [org.gnome.desktop.default-applications.terminal]
    exec='gnome-terminal'
    exec-arg='-e'
    [org.gnome.desktop.background]
    picture-uri=""
    primary-color='#2c001e'
    secondary-color='#772953'
    color-shading-type='vertical'
    [com.canonical.Unity.Launcher]
    favorites=['application://unity-files.desktop', 'application://unity-terminal.desktop', 'application://unity-system-settings.desktop', 'unity://running-apps', 'unity://devices']
    [com.canonical.Unity.ApplicationsLens]
    display-available-apps=false
    EOF
    glib-compile-schemas --strict $out/share/glib-2.0/schemas
  '';
in pkgs.stdenvNoCC.mkDerivation {
  pname = "unity-session";
  version = "unstable-32c2fd5";
  src = pkgs.fetchurl {
    url = "https://gitlab.com/ubuntu-unity/unity/unity-session/-/archive/32c2fd569b0d51e40bd3ec875e77f0261a744d03/unity-session-32c2fd569b0d51e40bd3ec875e77f0261a744d03.tar.gz";
    hash = "sha256-xQT3MSxArPUL8LIO7eCqjSJkF77iMDZaPUi3zl/i1iA=";
  };
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/applications $out/share/unity $out/share/xsessions $out/share/cinnamon-session/sessions $out/share/nemo/actions $out/etc/xdg/menus
    # Scope metadata is generated with each provider's own prefix, although
    # the navigation and category artwork is supplied by Unity and its asset
    # pool. Keep a corrected metadata copy first in XDG_DATA_DIRS so the Dash
    # can render its real lens icons instead of generic file placeholders.
    cp -Lr ${data}/share/unity/scopes $out/share/unity/
    chmod -R u+w $out/share/unity/scopes
    find $out/share/unity/scopes -type f -name '*.scope' -exec sed -E -i \
      -e 's#Icon=/nix/store/[^/]*/share/unity/icons/#Icon=${u.unity}/share/unity/icons/#' \
      -e 's#Icon=/nix/store/[^/]*/share/icons/unity-icon-theme/#Icon=${u.unity-asset-pool}/share/icons/unity-icon-theme/#' \
      -e 's#group-favouritefolders\.svg#group-folders.svg#' {} +
    cat >$out/share/applications/unity-files.desktop <<EOF
    [Desktop Entry]
    Name=Files
    Comment=Browse and organize files
    Exec=${pkgs.nemo}/bin/nemo
    Icon=system-file-manager
    Terminal=false
    Type=Application
    Categories=System;FileManager;
    StartupNotify=true
    StartupWMClass=Nemo
    EOF
    cat >$out/share/applications/unity-terminal.desktop <<EOF
    [Desktop Entry]
    Name=Terminal
    GenericName=Terminal
    Comment=Use the command line
    Exec=${pkgs.gnome-terminal}/bin/gnome-terminal
    Icon=utilities-terminal
    Terminal=false
    Type=Application
    Categories=System;TerminalEmulator;
    StartupNotify=true
    StartupWMClass=Gnome-terminal
    EOF
    cat >$out/share/applications/unity-appearance.desktop <<EOF
    [Desktop Entry]
    Name=Unity Appearance
    Comment=Choose GTK themes, icon themes, fonts, and pointer styles
    Exec=${pkgs.lxappearance}/bin/lxappearance
    Icon=preferences-desktop-theme
    Terminal=false
    Type=Application
    Categories=Settings;DesktopSettings;
    Keywords=Unity;Theme;Icons;Appearance;GTK;Font;Cursor;
    StartupNotify=true
    EOF
    cat >$out/share/applications/unity-system-settings.desktop <<EOF
    [Desktop Entry]
    Name=System Settings
    Comment=Configure Unity and the system
    Exec=${u.unity-control-center}/bin/unity-control-center --overview
    Icon=preferences-system
    Terminal=false
    Type=Application
    Categories=Settings;DesktopSettings;System;
    Keywords=Preferences;Settings;System;Unity;
    StartupNotify=true
    EOF
    # Keep all desktop entries visible to the lens, including Nix and Flatpak
    # applications whose categories do not match Ubuntu's historical layout.
    cat >$out/etc/xdg/menus/unity-lens-applications.menu <<'EOF'
    <!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
      "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
    <Menu>
      <Name>Applications</Name>
      <DefaultAppDirs/>
      <DefaultDirectoryDirs/>
      <Include><All/></Include>
    </Menu>
    EOF
    mkdir -p $out/etc/xdg/autostart
    # These are supervised by the Unity target, not launched a second time
    # by the XDG autostart reader in the session manager.
    for entry in indicator-application indicator-messages nm-applet polkit-gnome-authentication-agent-1; do
      cat >$out/etc/xdg/autostart/$entry.desktop <<AUTOSTART
    [Desktop Entry]
    Type=Application
    Name=$entry
    Hidden=true
    AUTOSTART
    done
    cp unity.session $out/share/cinnamon-session/sessions/
    cp *.nemo_action $out/share/nemo/actions/
    substitute unity.desktop $out/share/xsessions/unity.desktop \
      --replace-fail '/usr/bin/unity-session' "$out/bin/unity-session" \
      --replace-fail '/usr/bin/unity' "$out/bin/unity-session"
    cat >$out/bin/unity-session <<'EOF'
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    managed=(XDG_CURRENT_DESKTOP DESKTOP_SESSION GDMSESSION GNOME_DESKTOP_SESSION_ID
      COMPIZ_CONFIG_PROFILE COMPIZ_CONFIG_DIR COMPIZ_PLUGIN_DIR COMPIZ_METADATA_PATH UNITY_INDICATOR_DIR
      UNITY_INDICATOR_SERVICE_DIR GSETTINGS_SCHEMA_DIR GDK_PIXBUF_MODULE_FILE
      XDG_DATA_DIRS XDG_CONFIG_DIRS PATH GTK_MODULES GTK_PATH GTK_DATA_PREFIX LD_LIBRARY_PATH)
    declare -A previous present
    for name in "''${managed[@]}"; do
      previous[$name]="''${!name-}"
      if [[ -v $name ]]; then present[$name]=yes; else present[$name]=no; fi
    done
    cleanup() {
      ${pkgs.systemd}/bin/systemctl --user stop unity-session.target || true
      local restored=() unset_names=()
      for name in "''${managed[@]}"; do
        restored+=("$name=''${previous[$name]}")
        if [[ ''${present[$name]} == no ]]; then unset_names+=("$name"); fi
      done
      ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd "''${restored[@]}" || true
      if (( ''${#unset_names[@]} )); then
        ${pkgs.systemd}/bin/systemctl --user unset-environment "''${unset_names[@]}" || true
      fi
    }
    # Put Unity7 first: several desktop-menu consumers use the first token
    # when evaluating OnlyShowIn, and Unity's own panels target Unity7.
    export XDG_CURRENT_DESKTOP=Unity7:Unity:ubuntu
    # Unity is an X11 session. Prevent Kitty/GLFW from selecting a stale
    # Wayland socket inherited from the display manager.
    export KITTY_DISABLE_WAYLAND=1
    export GDK_BACKEND=x11
    unset WAYLAND_DISPLAY
    export DESKTOP_SESSION=ubuntu
    export GDMSESSION=unity
    export GDK_PIXBUF_MODULE_FILE=${pkgs.librsvg}/${pkgs.gdk-pixbuf.binaryDir}/loaders.cache
    export GNOME_DESKTOP_SESSION_ID=this-is-deprecated
    export COMPIZ_CONFIG_PROFILE=ubuntu
    export COMPIZ_CONFIG_DIR=${u.unity}/etc/compizconfig
    export COMPIZ_METADATA_PATH=${u.unity}/share/compiz
    export COMPIZ_PLUGIN_DIR=${u.unity}/lib/compiz:${u.compiz}/lib/compiz
    export UNITY_INDICATOR_DIR=${indicators}/lib/indicators/3
    export UNITY_INDICATOR_SERVICE_DIR=${indicators}/share/unity/indicators
    export GSETTINGS_SCHEMA_DIR=${schemas}/share/glib-2.0/schemas
    export XDG_DATA_DIRS=@out@/share:${data}/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}
    # Include both Flatpak installation scopes, even when their directories
    # are created after the user first logs in.
    export XDG_DATA_DIRS="$XDG_DATA_DIRS:''${XDG_DATA_HOME:-$HOME/.local/share}/flatpak/exports/share:/var/lib/flatpak/exports/share"
    # The applications lens installs its menu definition under etc/xdg. If it
    # is absent, the Dash starts normally but indexes an empty application set.
    export XDG_CONFIG_DIRS=@out@/etc/xdg:${u.unity-lens-applications}/etc/xdg:${u.unity-settings-daemon}/etc/xdg:''${XDG_CONFIG_DIRS:-/etc/xdg}
    export PATH=${lib.makeBinPath components}:$PATH
    export GTK_DATA_PREFIX=${data}
    export GTK_MODULES=unity-gtk-module
    export GTK_PATH=${u.unity-gtk-module}/lib/gtk-3.0
    export LD_LIBRARY_PATH=${u.gtk3-unity}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd \
      DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP DESKTOP_SESSION GDMSESSION GNOME_DESKTOP_SESSION_ID GDK_PIXBUF_MODULE_FILE KITTY_DISABLE_WAYLAND GDK_BACKEND \
      COMPIZ_CONFIG_PROFILE COMPIZ_CONFIG_DIR COMPIZ_PLUGIN_DIR COMPIZ_METADATA_PATH UNITY_INDICATOR_DIR \
      UNITY_INDICATOR_SERVICE_DIR GSETTINGS_SCHEMA_DIR XDG_DATA_DIRS XDG_CONFIG_DIRS PATH GTK_MODULES GTK_PATH GTK_DATA_PREFIX LD_LIBRARY_PATH
    trap cleanup EXIT
    trap 'exit 0' HUP INT TERM
    ${pkgs.systemd}/bin/systemctl --user reset-failed unity-session.target unity-shell.service || true
    ${pkgs.systemd}/bin/systemctl --user start unity-session.target
    # Keep the manager inside LightDM's logind session for locking and logout.
    ${u.cinnamon-session-unity}/bin/cinnamon-session --session=unity
    EOF
    substituteInPlace $out/bin/unity-session --replace-fail '@out@' "$out"
    ${pkgs.bash}/bin/bash -n $out/bin/unity-session
    chmod +x $out/bin/unity-session
    runHook postInstall
  '';
  passthru = { inherit components schemas data indicators; providedSessions = [ "unity" ]; };
  meta = {
    description = "Unity 7 desktop session for NixOS";
    homepage = "https://gitlab.com/ubuntu-unity/unity/unity-session";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
  };
}
