{ lib, stdenv, fetchurl, cmake, pkg-config, gettext, intltool, python3,
  compiz, nux, libunity, libunity-misc, xpathselect, libindicator, ido,
  unity-settings-daemon, gtk3-unity, glib, appstream-glib, atk, at-spi2-atk,
  cairo, libdbusmenu, dee, json-glib, bamf, gnome-desktop, libnotify,
  libstartup_notification, libsigcxx, zeitgeist, geis, libx11, libxfixes,
  libxi, libxrender, libxinerama, libxtst, xcbutilwm, libGL, libGLU,
  pam, boost, systemd, wrapGAppsHook3, gsettings-desktop-schemas,
  gsettings-ubuntu-schemas, nixos-icons }:
stdenv.mkDerivation {
  pname = "unity";
  version = "7.7.1";
  src = fetchurl {
    url = "https://gitlab.com/ubuntu-unity/unity/unity/-/archive/6f01ccb7395ca0fb3ee5f220263d9704a18ce194/unity-6f01ccb7395ca0fb3ee5f220263d9704a18ce194.tar.gz";
    hash = "sha256-X+FU80Q1oAV8vQpQatDEkoRaEHEObTItYh2vW68ClGc=";
  };
  nativeBuildInputs = [ cmake pkg-config gettext intltool python3 wrapGAppsHook3 ];
  buildInputs = [ gtk3-unity compiz nux libunity libunity-misc xpathselect
    libindicator ido unity-settings-daemon glib appstream-glib atk at-spi2-atk
    cairo libdbusmenu dee json-glib bamf gnome-desktop libnotify
    libstartup_notification libsigcxx zeitgeist geis libx11 libxfixes libxi
    libxrender libxinerama libxtst xcbutilwm libGL libGLU pam boost systemd
    gsettings-desktop-schemas gsettings-ubuntu-schemas ];
  cmakeFlags = [
    "-DENABLE_UNIT_TESTS=OFF" "-DGSETTINGS_LOCALINSTALL=ON"
    "-DCMAKE_MODULE_PATH=${compiz}/share/cmake/Modules"
    "-DCMAKE_INSTALL_RPATH=${lib.getLib gtk3-unity}/lib;${placeholder "out"}/lib;${compiz}/lib;${compiz}/lib/compiz"
    "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON"
  ];
  postPatch = ''
    # Unrecognized directory handlers must not leave GetDefault() null:
    # StorageLauncherIcon dereferences it while constructing drive icons.
    substituteInPlace unity-shared/FileManager.cpp \
      --replace-fail 'else if (app_id == "nemo.desktop")' 'else'
    # The session assembles indicators from independent Nix packages.
    python3 - <<'PY'
from pathlib import Path
p = Path('services/panel-service.c')
s = p.read_text()
for macro, env in [('INDICATORDIR', 'UNITY_INDICATOR_DIR'), ('INDICATOR_SERVICE_DIR', 'UNITY_INDICATOR_SERVICE_DIR')]:
    s = s.replace(macro, '(g_getenv ("' + env + '") ? g_getenv ("' + env + '") : ' + macro + ')')
p.write_text(s)
PY
    # Force Ubuntu GTK for every linked executable, including helper tools.
    sed -i '0,/add_subdirectory/s|add_subdirectory|link_libraries("${lib.getLib gtk3-unity}/lib/libgtk-3.so")\nadd_subdirectory|' CMakeLists.txt

    substituteInPlace services/CMakeLists.txt \
      --replace-fail 'target_link_libraries(unity-panel-service' 'target_link_libraries(unity-panel-service ${lib.getLib gtk3-unity}/lib/libgtk-3.so' \
      --replace-fail 'set (SYSTEMD_USER_DIR "/usr/lib/systemd/user")' \
        'set (SYSTEMD_USER_DIR "${placeholder "out"}/lib/systemd/user")'
    substituteInPlace data/CMakeLists.txt \
      --replace-fail 'pkg_get_variable(SYSTEMD_USER_DIR systemd systemduserunitdir)' \
        'set(SYSTEMD_USER_DIR "${placeholder "out"}/lib/systemd/user")'
    substituteInPlace data/compiz/CMakeLists.txt \
      --replace-fail 'pkg_get_variable (COMPIZCONFIG_CONFIG_DIR libcompizconfig configdir)' \
        'set (COMPIZCONFIG_CONFIG_DIR "${placeholder "out"}/etc/compizconfig")' \
      --replace-fail 'pkg_get_variable (COMPIZCONFIG_UPGRADES_DIR libcompizconfig upgradesdir)' \
        'set (COMPIZCONFIG_UPGRADES_DIR "${placeholder "out"}/share/compizconfig/upgrades")'
    substituteInPlace data/unity7.service.in \
      --replace-fail '/usr/bin/compiz' '${compiz}/bin/compiz'
    substituteInPlace tools/compiz-profile-selector.in \
      --replace-fail '/usr/lib/nux/unity_support_test' '${nux}/libexec/nux/unity_support_test'
    # Unity is a separate store output, never install plugins into Compiz's output.
    substituteInPlace plugins/unityshell/CMakeLists.txt \
      --replace-fail 'DESTINATION ''${COMPIZ_DATADIR}/ccsm' 'DESTINATION ${placeholder "out"}/share/compiz/ccsm'
  '';
  enableParallelBuilding = true;
  postInstall = ''
    # Unity loads the Dash button directly from its own icon directory.
    install -Dm644 ${nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake-white.png \
      $out/share/unity/icons/launcher_bfb.png
    install -Dm644 ${nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake-white.svg \
      $out/share/unity/icons/launcher_bfb.svg
  '';
  meta = {
    description = "Unity 7 desktop shell";
    homepage = "https://gitlab.com/ubuntu-unity/unity/unity";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
