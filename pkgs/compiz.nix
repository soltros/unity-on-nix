{ lib, stdenv, fetchurl, cmake, pkg-config, intltool, libxslt,
  boost, glib, glibmm, libstartup_notification, libxml2,
  libGL, libGLU, libx11, libxext, libxdamage, libxcomposite, libxcursor,
  libxrandr, libxinerama, libxi, libice, libsm, libxrender, libxfixes,
  libpng, libjpeg, cairo, librsvg, dbus, dbus-glib, pango, libnotify,
  libxdmcp, libxau }:
stdenv.mkDerivation {
  pname = "compiz-unity";
  version = "0.9.14.2-ubuntu3";
  src = fetchurl {
    url = "https://archive.ubuntu.com/ubuntu/pool/universe/c/compiz/compiz_0.9.14.2+25.10.20250930-0ubuntu3.tar.xz";
    hash = "sha256-41R8lRh/uedvfej5Ul3SDlVWhNZ1fgc8YulJLBHsW8o=";
  };
  nativeBuildInputs = [ cmake pkg-config intltool libxslt ];
  propagatedBuildInputs = [ boost glib glibmm libstartup_notification
    libxml2 libxslt libGL libGLU libx11 libxext libxdamage libxcomposite
    libxcursor libxrandr libxinerama libxi libice libsm libxrender libxfixes
    libxdmcp libxau ];
  buildInputs = [ libpng libjpeg cairo librsvg dbus dbus-glib pango libnotify ];
  postPatch = ''
    # A package must not install into systemd's immutable store output.
    substituteInPlace CMakeLists.txt --replace-fail \
      'pkg_get_variable(SYSTEMD_USERUNITDIR systemd systemduserunitdir)' \
      'set(SYSTEMD_USERUNITDIR "''${CMAKE_INSTALL_PREFIX}/lib/systemd/user")'
    # Stage one needs the C library/backend, not the Python settings GUI.
    substituteInPlace compizconfig/CMakeLists.txt \
      --replace-fail 'add_subdirectory (compizconfig-python)' "" \
      --replace-fail 'add_subdirectory (ccsm)' ""
    substituteInPlace cmake/CompizGSettings.cmake \
      --replace-fail 'GSETTINGS_GLIB_PREFIX}/share' 'CMAKE_INSTALL_PREFIX}/share'
  '';
  cmakeBuildType = "RelWithDebInfo";
  cmakeFlags = [
    "-DCOMPIZ_BUILD_TESTING=OFF" "-DBUILD_XORG_GTEST=OFF"
    "-DCOMPIZ_WERROR=OFF" "-DCOMPIZ_RUN_LDCONFIG=OFF"
    "-DBUILD_GTK=OFF" "-DUSE_PROTOBUF=OFF"
    "-DCMAKE_INSTALL_RPATH=${placeholder "out"}/lib;${placeholder "out"}/lib/compiz"
    "-DCMAKE_INSTALL_RPATH_USE_LINK_PATH=ON"
  ];
  enableParallelBuilding = true;
  postInstall = ''
    # Export the module used by Unity's find_package(Compiz).
    mkdir -p $out/share/cmake/Modules
    cp ../cmake/FindCompiz.cmake ../cmake/FindOpenGLES2.cmake $out/share/cmake/Modules/
    test -e $out/lib/pkgconfig/compiz.pc
    test -e $out/lib/pkgconfig/libcompizconfig.pc
    for plugin in composite opengl compiztoolbox scale; do
      test -e "$out/lib/compiz/lib$plugin.so"
    done
  '';
  meta = {
    description = "Compiz 0.9 and libcompizconfig for the experimental Unity 7 port";
    homepage = "https://launchpad.net/compiz";
    license = lib.licenses.gpl2Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "compiz";
  };
}
