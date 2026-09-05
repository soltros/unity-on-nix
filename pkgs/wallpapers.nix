{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "unity-ubuntu-wallpapers";
  version = "26.04.2";
  src = pkgs.fetchurl {
    url = "https://archive.ubuntu.com/ubuntu/pool/main/u/ubuntu-wallpapers/ubuntu-wallpapers-resolute_26.04.2_all.deb";
    hash = "sha256-8K9/9KP9W8O2OIW/oU7Zw7oyDcmk+pSPnFBrcVpZ34g=";
  };
  nativeBuildInputs = [ pkgs.dpkg ];
  unpackPhase = "dpkg-deb -x $src .";
  installPhase = ''
    mkdir -p $out/share
    cp -r usr/share/backgrounds usr/share/gnome-background-properties $out/share/
    cp -r usr/share/doc $out/share/
    # The Ubuntu catalogue names the slideshow at the background root,
    # although the package ships it under contest/.
    ln -s contest/resolute.xml $out/share/backgrounds/resolute.xml
    # Background catalogues and slideshow files contain Ubuntu absolute paths.
    while IFS= read -r -d "" catalogue; do
      substituteInPlace "$catalogue" --replace-warn /usr/share/backgrounds "$out/share/backgrounds"
    done < <(find $out/share -name '*.xml' -print0)
  '';
  meta = {
    description = "Ubuntu 26.04 wallpapers and background chooser catalogue for Unity";
    homepage = "https://packages.ubuntu.com/resolute/ubuntu-wallpapers-resolute";
    license = [ pkgs.lib.licenses.cc-by-sa-30 pkgs.lib.licenses.cc-by-sa-40 ];
    platforms = pkgs.lib.platforms.linux;
  };
}
