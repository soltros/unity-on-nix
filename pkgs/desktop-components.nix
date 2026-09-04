{ pkgs, base }:
let
  source = import ./ubuntu-source.nix { inherit pkgs; };
  manifest = builtins.fromJSON (builtins.readFile ./sources.json);
  cmakeExtras = pkgs.stdenv.mkDerivation {
    pname = "cmake-extras";
    version = "1.9";
    src = source "cmake-extras";
    nativeBuildInputs = [ pkgs.cmake ];
  };
  auto = name: attrs: pkgs.stdenv.mkDerivation ({
    pname = name;
    version = manifest.${name}.version;
    src = source name;
    nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config intltool gnome-common gtk-doc vala python3 gobject-introspection ];
    enableParallelBuilding = true;
    env.NIX_CFLAGS_COMPILE = "-Wno-error";
    makeFlags = [ "SYSTEMD_USERDIR=${placeholder "out"}/lib/systemd/user" "SYSTEMD_USERUNITDIR=${placeholder "out"}/lib/systemd/user" "xdg_autostartdir=${placeholder "out"}/etc/xdg/autostart" ];
  } // attrs);
  mkCmake = name: attrs: pkgs.stdenv.mkDerivation ({
    pname = name;
    version = manifest.${name}.version;
    src = source name;
    nativeBuildInputs = with pkgs; [ cmake pkg-config gettext intltool vala python3 gobject-introspection cmakeExtras ];
    prePatch = ''
      python3 - <<'PYCODE'
from pathlib import Path
for p in Path('.').rglob('CMakeLists.txt'):
    text = p.read_text()
    if '/usr/lib/systemd/user' in text:
        p.write_text(text.replace('/usr/lib/systemd/user', '${placeholder "out"}/lib/systemd/user'))
PYCODE
    '';
    cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" "-DGSETTINGS_LOCALINSTALL=ON" "-DCMAKE_INSTALL_RPATH=${placeholder "out"}/lib" "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON" ];
    enableParallelBuilding = true;
    env.NIX_CFLAGS_COMPILE = "-Wno-error";
  } // attrs);
in rec {
  cmake-extras = cmakeExtras;
  libcolumbus = mkCmake "libcolumbus" {
    buildInputs = [ pkgs.boost pkgs.icu ];
    postPatch = ''
      substituteInPlace CMakeLists.txt --replace-fail 'include(cmake/python.cmake)' 'set(build_python FALSE)' \
        --replace-fail 'option(enable_tests "Enable tests." ON)' 'option(enable_tests "Enable tests." OFF)'
    '';
  };
  libzeitgeist = auto "libzeitgeist" {
    propagatedBuildInputs = [ pkgs.glib ];
    configureFlags = [ "--disable-gtk-doc" ];
  };
  unity-scope-home = auto "unity-scope-home" {
    buildInputs = with pkgs; [ base.libunity glib dee libgee json-glib libuuid ];
    configureFlags = [ "--enable-localinstall" "--disable-headless-tests" ];
  };
  unity-lens-music = auto "unity-lens-music" {
    buildInputs = with pkgs; [ base.libunity glib dee sqlite libgee json-glib libnotify
      tdb gst_all_1.gstreamer gst_all_1.gst-plugins-base ];
    configureFlags = [ "--enable-localinstall" ];
  };
  unity-lens-photos = pkgs.stdenvNoCC.mkDerivation {
    pname = "unity-lens-photos-local";
    version = manifest.unity-lens-photos.version;
    src = source "unity-lens-photos";
    nativeBuildInputs = [ pkgs.makeWrapper pkgs.intltool ];
    dontBuild = true;
    installPhase = let python = pkgs.python3.withPackages (p: [ p.pygobject3 ]); in ''
      mkdir -p $out/libexec $out/share/unity-scopes/shotwell $out/share/unity/scopes/photos $out/share/dbus-1/services
      cp src/unity_shotwell_daemon.py $out/share/unity-scopes/shotwell/
      makeWrapper ${python}/bin/python3 $out/libexec/unity-shotwell-scope \
        --add-flags $out/share/unity-scopes/shotwell/unity_shotwell_daemon.py \
        --prefix GI_TYPELIB_PATH : ${base.libunity}/lib/girepository-1.0:${pkgs.dee}/lib/girepository-1.0:${pkgs.lib.getLib pkgs.glib}/lib/girepository-1.0 \
        --prefix LD_LIBRARY_PATH : ${base.libunity}/lib:${base.libunity}/lib/libunity:${pkgs.dee}/lib
      intltool-merge -d -u po data/shotwell.scope.in $out/share/unity/scopes/photos/shotwell.scope
      substituteInPlace $out/share/unity/scopes/photos/shotwell.scope \
        --replace-fail '/usr/share/unity-scopes/shotwell/unity_shotwell_daemon.py' "$out/libexec/unity-shotwell-scope"
      substitute data/unity-scope-shotwell.service $out/share/dbus-1/services/unity-scope-shotwell.service \
        --replace-fail '/usr/share/unity-scopes/shotwell/unity_shotwell_daemon.py' "$out/libexec/unity-shotwell-scope"
    '';
    meta.description = "Local Shotwell photo search for Unity";
  };
  unity-lens-video = auto "unity-lens-video" {
    # Build the local provider; the retired Ubuntu remote search client depends
    # on unsupported libsoup 2 and is not advertised as a working service.
    buildInputs = with pkgs; [ base.libunity glib dee libgee json-glib libzeitgeist ];
    postPatch = ''
      sed -i '/libsoup-gnome-2.4/d' configure.ac
      sed -i '/^[[:space:]]*unity-scope-video-remote \\/d; /^[[:space:]]*unity_scope_video_remote.vala.stamp \\/d' src/Makefile.am
      substituteInPlace Makefile.am --replace-fail ' tests/unit' ""
      sed -i '/^[[:space:]]*unity-scope-video-remote.service.in \\/d' data/Makefile.am
      substituteInPlace data/Makefile.am --replace-fail 'scope_in_files = local.scope.in remote.scope.in' 'scope_in_files = local.scope.in'
    '';
    configureFlags = [ "--enable-localinstall" ];
  };
  unity-lens-files = auto "unity-lens-files" {
    buildInputs = with pkgs; [ base.libunity glib dee libgee zeitgeist ];
    configureFlags = [ "--enable-localinstall" "--disable-headless-tests" ];
  };
  unity-lens-applications = auto "unity-lens-applications" {
    buildInputs = with pkgs; [ base.libunity glib dee libgee libzeitgeist libcolumbus gnome-menus xapian db apt ];
    configureFlags = [ "--enable-localinstall" "--disable-headless-tests" ];
  };
  unity-gtk-module = auto "unity-gtk-module" {
    buildInputs = [ base.gtk3-unity pkgs.glib pkgs.libx11 pkgs.systemd ];
    postPatch = ''
      substituteInPlace lib/unity-gtk-menu-item.c --replace-fail 'icon = g_object_ref (pixbuf);' 'icon = G_ICON (g_object_ref (pixbuf));'
      substituteInPlace src/main.c --replace-fail 'window_data->old_model = g_object_ref (old_menu_model);' 'window_data->old_model = G_MENU_MODEL (g_object_ref (old_menu_model));'
    '';
    configureFlags = [ "--with-gtk=3" "--with-gtk-module-dir=${placeholder "out"}/lib/gtk-3.0/modules" ];
  };
  indicator-appmenu = auto "indicator-appmenu" {
    buildInputs = with pkgs; [ base.gtk3-unity base.libindicator base.ido unity-gtk-module glib libdbusmenu-gtk3 bamf libx11 libxslt ];
    postPatch = ''
      substituteInPlace configure.ac --replace-fail "gio-2.0 >=" "gio-unix-2.0 >="
    '';
    configureFlags = [ "--enable-localinstall" "--disable-tests" ];
  };
  indicator-application = auto "indicator-application" {
    buildInputs = with pkgs; [ base.gtk3-unity base.libindicator base.ido glib json-glib dbus-glib libdbusmenu libappindicator-gtk3 ];
    configureFlags = [ "--enable-localinstall" ];
  };
  indicator-power = mkCmake "indicator-power" {
    postPatch = ''
      substituteInPlace src/service.c --replace-fail 'p->conn = g_object_ref (G_OBJECT (connection));' 'p->conn = g_object_ref (connection);'
      substituteInPlace src/CMakeLists.txt --replace-fail '/usr/share/accountsservice/interfaces/com.ubuntu.touch.AccountsService.Sound.xml' '${base.gsettings-ubuntu-schemas}/share/accountsservice/interfaces/com.ubuntu.touch.AccountsService.Sound.xml'
    '';
    buildInputs = with pkgs; [ glib libgudev libnotify ];
  };
  indicator-bluetooth = auto "indicator-bluetooth" {
    buildInputs = [ pkgs.glib ];
  };
  indicator-messages = auto "indicator-messages" {
    buildInputs = with pkgs; [ glib base.accountsservice-unity dbus-test-runner ];
  };
  indicator-sound = mkCmake "indicator-sound" {
    postPatch = ''
      substituteInPlace src/main.c \
        --replace-fail '#include <glib.h>' $'#include <glib.h>\n#include <glib-unix.h>\n#include <libintl.h>' \
        --replace-fail 'options = indicator_sound_options_gsettings_new();' 'options = INDICATOR_SOUND_OPTIONS (indicator_sound_options_gsettings_new());' \
        --replace-fail 'warning = volume_warning_pulse_new(options, pgloop);' 'warning = VOLUME_WARNING (volume_warning_pulse_new(options, pgloop));' \
        --replace-fail '(playerlist, volume, accounts,' '(playerlist, VOLUME_CONTROL (volume), accounts,'

      substituteInPlace src/CMakeLists.txt --replace-fail 'add_subdirectory(gmenuharness)' "" --replace-fail '/usr/share/gir-1.0/AccountsService-1.0.gir' '${pkgs.lib.getDev base.accountsservice-unity}/share/gir-1.0/AccountsService-1.0.gir'
    '';
    buildInputs = with pkgs; [ glib libpulseaudio libgee libxml2 libnotify base.accountsservice-unity dbus-test-runner ];
  };
  fcitx4 = mkCmake "fcitx" {
    version = "4.2.9.9";
    postPatch = ''
      patchShebangs cmake
      substituteInPlace src/lib/fcitx-gclient/CMakeLists.txt \
        --replace-fail 'DESTINATION "''${GOBJECT_INTROSPECTION_GIRDIR}"' 'DESTINATION "${placeholder "out"}/share/gir-1.0"' \
        --replace-fail 'DESTINATION "''${GOBJECT_INTROSPECTION_TYPELIBDIR}"' 'DESTINATION "${placeholder "out"}/lib/girepository-1.0"'
    '';
    buildInputs = with pkgs; [ kdePackages.extra-cmake-modules glib dbus libx11 libxext libxrender
      libxkbcommon libxkbfile xkeyboard_config cairo pango libxml2 isocodes json_c libuuid ];
    dontWrapQtApps = true;
    preConfigure = ''
      cmakeFlagsArray+=(-DENABLE_QT=OFF -DENABLE_QT_IM_MODULE=OFF -DENABLE_QT_GUI=OFF
        -DENABLE_GTK2_IM_MODULE=OFF -DENABLE_GTK3_IM_MODULE=OFF -DENABLE_OPENCC=OFF
        -DENABLE_ENCHANT=OFF -DENABLE_PRESAGE=OFF -DENABLE_XDGAUTOSTART=OFF)
    '';
  };
  indicator-keyboard = auto "indicator-keyboard" {
    buildInputs = with pkgs; [ base.gtk3-unity base.accountsservice-unity glib libgee pango
      gnome-desktop libxklavier libgnomekbd ibus fcitx4 lightdm ];
    configureFlags = [ "--enable-localinstall" ];
  };
  unity-greeter = auto "unity-greeter" {
    buildInputs = with pkgs; [ base.gtk3-unity base.libindicator base.ido base.unity-settings-daemon
      lightdm freetype cairo libcanberra pixman libx11 libxext ];
  };
  unity-control-center = auto "unity-control-center" {
    postPatch = ''
      substituteInPlace panels/printers/pp-new-printer.c --replace-fail 'g_dbus_connection_call (g_object_ref (source_object),' 'g_dbus_connection_call (G_DBUS_CONNECTION (g_object_ref (source_object)),'
      substituteInPlace panels/bluetooth/gnome-bluetooth/lib/bluetooth-client.c --replace-fail 'model = g_object_ref(priv->store);' 'model = GTK_TREE_MODEL (g_object_ref (priv->store));'
      substituteInPlace panels/user-accounts/um-realm-manager.c --replace-fail 'discover->manager = g_object_ref (self);' 'discover->manager = G_DBUS_OBJECT_MANAGER (g_object_ref (self));'
      substituteInPlace panels/user-accounts/um-account-dialog.c --replace-fail 'g_clear_pointer (&self->join_dialog, gtk_widget_destroy);' 'g_clear_pointer (&self->join_dialog, (GDestroyNotify) gtk_widget_destroy);'
      substituteInPlace panels/appearance/cc-appearance-xml.c --replace-fail 'emit_added_in_idle (xml, g_object_ref (item));' 'emit_added_in_idle (xml, G_OBJECT (g_object_ref (item)));'
      substituteInPlace shell/cc-shell-item-view.c --replace-fail 'gtk_widget_override_background_color (self,' 'gtk_widget_override_background_color (GTK_WIDGET (self),'
    '';

    buildInputs = with pkgs; [ base.gtk3-unity base.unity-settings-daemon base.accountsservice-unity
      glib json-glib libsoup_3 libnotify polkit gnome-desktop gnome-menus libxml2 libtimezonemap geonames
      libgtop libGL libx11 libxi ibus libcanberra-gtk3 libpulseaudio libpwquality
      upower colord networkmanager libnma modemmanager cups libwacom isocodes krb5
      libxklavier libgnomekbd gsettings-desktop-schemas base.gsettings-ubuntu-schemas ];
    configureFlags = [ "--disable-fcitx" "--disable-documentation" "--disable-onlineaccounts" "--without-cheese" ];
  };
  libtimezonemap = auto "libtimezonemap" {
    buildInputs = with pkgs; [ base.gtk3-unity glib libsoup_3 json-glib ];
    configureFlags = [ "--enable-localinstall" ];
  };
  geonames = mkCmake "geonames" {
    buildInputs = [ pkgs.glib ];
    postPatch = ''patchShebangs src/generate-locales.sh'';
    preConfigure = ''cmakeFlagsArray+=(-DWANT_DOC=OFF -DWANT_TESTS=OFF)'';
  };
  indicator-datetime = mkCmake "indicator-datetime" {
    buildInputs = with pkgs; [ glib libical evolution-data-server gst_all_1.gstreamer
      libnotify properties-cpp libaccounts-glib indicator-messages libuuid ];
    postPatch = ''
      substituteInPlace CMakeLists.txt --replace-fail 'add_subdirectory(tests)' ""
      sed -i '/find_package(CoverageReport)/,$d' CMakeLists.txt
    '';
  };
  indicator-session = mkCmake "indicator-session" {
    buildInputs = [ pkgs.glib ];
    # Ubuntu's crash uploader is not part of a NixOS session. Retain the
    # diagnostic locally instead of submitting user account data to it.
    postPatch = ''
      substituteInPlace CMakeLists.txt --replace-fail 'libwhoopsie)' ')'
      substituteInPlace src/service.c \
        --replace-fail '#include <libwhoopsie/recoverable-problem.h>' "" \
        --replace-fail 'whoopsie_report_recoverable_problem("indicator-session-unknown-user-error", 0, FALSE, properties);' 'g_warning("indicator-session: unusable user account (uid %s)", uid_str);'
    '';
  };
  dee-qt = mkCmake "dee-qt" {
    buildInputs = [ pkgs.dee pkgs.qt5.qtbase pkgs.qt5.qtdeclarative ];
    dontWrapQtApps = true;
    postPatch = ''
      substituteInPlace CMakeLists.txt --replace-fail 'add_subdirectory(tests)' ""
    '';
    preConfigure = ''
      cmakeFlagsArray+=(-DWITHQT5=ON)
      sed -i '/file(TO_CMAKE_PATH/a set(QT_IMPORTS_DIR "${placeholder "out"}/lib/qt-5/qml")' modules/Dee/CMakeLists.txt
    '';
  };
  hud = mkCmake "hud" {
    buildInputs = with pkgs; [ glib dee libdbusmenu base.gtk3-unity libcolumbus
      qt5.qtbase qt5.qtdeclarative dee-qt gsettings-qt libdbusmenu-qt5 python3Packages.setuptools ];
    dontWrapQtApps = true;
    preConfigure = ''cmakeFlagsArray+=(-DENABLE_TESTS=OFF -DLOCAL_INSTALL=ON)'';
    postPatch = ''
      substituteInPlace data/CMakeLists.txt --replace-fail 'pkg_get_variable(SYSTEMD_USER_DIR systemd systemduserunitdir)' 'set(SYSTEMD_USER_DIR "${placeholder "out"}/lib/systemd/user")'
      substituteInPlace service/QGSettingsSearchSettings.h service/SqliteUsageTracker.cpp --replace-fail '<QGSettings/qgsettings.h>' '<qgsettings.h>'
      sed -i '/pkg_check_modules(QTDBUSTEST /d; /pkg_check_modules(QTDBUSMOCK /d' CMakeLists.txt
    '';
  };
  unity-asset-pool = pkgs.stdenvNoCC.mkDerivation {
    pname = "unity-asset-pool";
    version = manifest.unity-asset-pool.version;
    src = source "unity-asset-pool";
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/share/icons $out/share/unity/themes
      cp -r unity-icon-theme $out/share/icons/unity-icon-theme
      cp -r launcher/* panel/* $out/share/unity/themes/
    '';
  };
}
