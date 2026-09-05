{ pkgs, unityPackages }:
let
  inherit (pkgs) lib;
  u = unityPackages;
  wallpapers = import ./wallpapers.nix { inherit pkgs; };
  unity-theme-settings-script = pkgs.writeScriptBin "unity-theme-settings" ''
    #!${pkgs.python3.withPackages (p: [ p.pygobject3 ])}/bin/python3
    import gi
    gi.require_version("Gtk", "3.0")
    from gi.repository import Gtk, Gio, Gdk
    interface = Gio.Settings.new("org.gnome.desktop.interface")
    background = Gio.Settings.new("org.gnome.desktop.background")
    launcher = Gio.Settings.new("com.canonical.Unity.Launcher")
    has_launcher_size = "launcher-icon-size" in launcher.list_keys()
    themes = ["Ambiance", "Radiance", "Adwaita", "Adwaita-dark"]
    icons = ["ubuntu-mono-dark", "ubuntu-mono-light", "Adwaita", "hicolor"]
    win = Gtk.Window(title="Unity Appearance")
    win.set_border_width(18); win.set_default_size(420, 260)
    box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12); win.add(box)
    def row(label, values, key):
      r = Gtk.Box(spacing=12); r.pack_start(Gtk.Label(label=label, xalign=0), True, True, 0)
      c = Gtk.ComboBoxText()
      for v in values: c.append_text(v)
      current = interface.get_string(key)
      if current not in values:
        values.append(current); c.append_text(current)
      if current in values: c.set_active(values.index(current))
      r.pack_end(c, False, False, 0); box.pack_start(r, False, False, 0)
      return c
    theme = row("GTK theme", themes, "gtk-theme")
    icon = row("Icon theme", icons, "icon-theme")
    size = Gtk.SpinButton.new_with_range(24, 64, 1)
    size.set_value(launcher.get_int("launcher-icon-size") if has_launcher_size else 48)
    size.set_sensitive(has_launcher_size)
    r = Gtk.Box(spacing=12); r.pack_start(Gtk.Label(label="Dock icon size", xalign=0), True, True, 0); r.pack_end(size, False, False, 0); box.pack_start(r, False, False, 0)
    font = Gtk.FontButton(); font.set_font(interface.get_string("font-name"))
    r = Gtk.Box(spacing=12); r.pack_start(Gtk.Label(label="Font", xalign=0), True, True, 0); r.pack_end(font, False, False, 0); box.pack_start(r, False, False, 0)
    color = Gtk.ColorButton()
    initial_color = Gdk.RGBA()
    initial_color.parse(background.get_string("primary-color"))
    color.set_rgba(initial_color)
    color_changed = False
    def mark_color_changed(_):
      global color_changed
      color_changed = True
    color.connect("color-set", mark_color_changed)
    r = Gtk.Box(spacing=12); r.pack_start(Gtk.Label(label="Background", xalign=0), True, True, 0); r.pack_end(color, False, False, 0); box.pack_start(r, False, False, 0)
    apply = Gtk.Button(label="Apply"); box.pack_end(apply, False, False, 0)
    def save(_):
      interface.set_string("gtk-theme", theme.get_active_text()); interface.set_string("icon-theme", icon.get_active_text()); interface.set_string("font-name", font.get_font_name())
      if has_launcher_size: launcher.set_int("launcher-icon-size", size.get_value_as_int())
      if color_changed:
        rgba = color.get_rgba()
        value = "#{:02x}{:02x}{:02x}".format(round(rgba.red*255), round(rgba.green*255), round(rgba.blue*255))
        background.set_string("primary-color", value)
        background.set_string("color-shading-type", "solid")
        background.set_string("picture-uri", "")
    apply.connect("clicked", save); win.connect("destroy", Gtk.main_quit); win.show_all(); Gtk.main()
  '';
  unity-theme-settings = pkgs.stdenvNoCC.mkDerivation {
    pname = "unity-theme-settings";
    version = "1.0";
    dontUnpack = true;
    nativeBuildInputs = [ pkgs.wrapGAppsHook3 pkgs.gobject-introspection ];
    buildInputs = [ u.gtk3-unity pkgs.glib u.gsettings-desktop-schemas-unity ];
    installPhase = ''
      install -Dm755 ${unity-theme-settings-script}/bin/unity-theme-settings $out/bin/unity-theme-settings
    '';
  };
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
    cinnamon-desktop libgnomekbd ibus glib.bin nemo
    zeitgeist notify-osd networkmanagerapplet polkit_gnome
    ubuntu-themes adwaita-icon-theme ubuntu-classic dejavu_fonts gnome-terminal kitty gnome-screenshot firefox thunderbird rhythmbox vlc unity-theme-settings wallpapers
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
      indicator-bluetooth indicator-messages lomiri-indicator-network ];
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
    favorites=['application://unity-files.desktop', 'application://org.gnome.Terminal.desktop', 'application://firefox.desktop', 'application://thunderbird.desktop', 'application://org.gnome.Rhythmbox3.desktop', 'application://vlc.desktop', 'application://unity-system-settings.desktop', 'unity://running-apps', 'unity://devices']
    [com.canonical.Unity.ApplicationsLens]
    display-available-apps=false
    [com.canonical.unity.settings-daemon.plugins.media-keys]
    screenshot='Print'
    window-screenshot='<Alt>Print'
    area-screenshot='<Shift>Print'
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
    Exec=${pkgs.nemo}/bin/nemo %U
    Icon=system-file-manager
    Terminal=false
    Type=Application
    Categories=System;FileManager;
    MimeType=inode/directory;application/x-gnome-saved-search;
    StartupNotify=true
    StartupWMClass=Nemo
    EOF
    # Folder results in the Files lens use GIO's default URI-capable handler.
    # Scope these defaults to Unity and preserve explicit user associations.
    cat >$out/etc/xdg/unity-mimeapps.list <<EOF
    [Default Applications]
    inode/directory=nemo.desktop;
    application/x-gnome-saved-search=nemo.desktop;
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
    Exec=${unity-theme-settings}/bin/unity-theme-settings
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
    cat >$out/share/applications/unity-screenshot.desktop <<EOF
    [Desktop Entry]
    Name=Screenshot
    Comment=Capture the screen
    Exec=${pkgs.gnome-screenshot}/bin/gnome-screenshot --interactive
    Icon=applets-screenshooter
    Terminal=false
    Type=Application
    Categories=Graphics;Utility;
    StartupNotify=true
    EOF
    cat >$out/share/applications/nm-connection-editor-unity.desktop <<EOF
    [Desktop Entry]
    Name=Network Connections
    Comment=Configure wired and wireless network connections
    Exec=${pkgs.networkmanagerapplet}/bin/nm-connection-editor
    Icon=network-workgroup
    Terminal=false
    Type=Application
    Categories=Settings;Network;
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
    export UNITY_INDICATOR_DIR=${indicators}/lib/indicators/3:${indicators}/share/unity/indicators
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
