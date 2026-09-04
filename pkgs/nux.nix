{ lib, stdenv, fetchurl, autoreconfHook, pkg-config, gnome-common,
  glib, libsigcxx, gdk-pixbuf, cairo, libpng, libGL, libGLU, glew_1_10,
  libx11, libxext, libxxf86vm, libxinerama, libxcomposite, libxdamage,
  pango, pcre2, pciutils, ibus, geis, boost, icu }:
let
  ubuntuChanges = fetchurl {
    url = "https://archive.ubuntu.com/ubuntu/pool/universe/n/nux/nux_4.0.8+18.10.20180623-0ubuntu14.diff.gz";
    hash = "sha256-Vma9FmxWnuXwsJU35Fsp3aKjXAog7cTs62gBBmvNj9g=";
  };
in stdenv.mkDerivation {
  pname = "nux";
  version = "4.0.8-ubuntu14";
  unpackPhase = ''
    runHook preUnpack
    mkdir source
    tar -xf $src -C source
    cd source
    runHook postUnpack
  '';
  src = fetchurl {
    url = "https://archive.ubuntu.com/ubuntu/pool/universe/n/nux/nux_4.0.8+18.10.20180623.orig.tar.gz";
    hash = "sha256-XsKW+OnURfwuK/KBTk+m7TamIGiTfQouASL6aEkjYbM=";
  };
  nativeBuildInputs = [ autoreconfHook pkg-config gnome-common ];
  propagatedBuildInputs = [ glib libsigcxx gdk-pixbuf cairo libpng libGL
    libGLU glew_1_10 libx11 libxext libxxf86vm libxinerama pango pcre2 geis ibus boost icu ];
  buildInputs = [ libxcomposite libxdamage pciutils ];
  postPatch = ''
    # GLEW 1.10 predates Khronos' renamed extension-header guard.
    substituteInPlace NuxGraphics/GLResource.h --replace-fail '#include "GL/glew.h"' $'#include "GL/glew.h"\n#define __gl_glext_h_ 1'

    gzip -dc ${ubuntuChanges} | patch -p1
    while IFS= read -r patchName; do
      patch -p1 < "debian/patches/$patchName"
    done < debian/patches/series
  '';
  configureFlags = [ "--disable-tests" "--disable-documentation" "--enable-gestures" ];
  enableParallelBuilding = true;
  postInstall = ''
    test -e $out/lib/pkgconfig/nux-4.0.pc
    test -e $out/lib/libnux-4.0.so
    test -x $out/libexec/nux/unity_support_test
  '';
  meta = {
    description = "Nux 4 rendering toolkit for the experimental Unity 7 port";
    homepage = "https://launchpad.net/nux";
    license = lib.licenses.lgpl3Plus;
    platforms = [ "x86_64-linux" ];
  };
}
