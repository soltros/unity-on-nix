{ pkgs, libunity }:
pkgs.stdenv.mkDerivation {
  pname = "unity-flatpak-scope";
  version = "0.1.0";
  src = ./.;
  nativeBuildInputs = [ pkgs.vala pkgs.pkg-config ];
  buildInputs = [ libunity pkgs.glib pkgs.dee ];
  postPatch = ''
    substituteInPlace main.vala \
      --replace-fail '@timeout@' '${pkgs.coreutils}/bin/timeout' \
      --replace-fail '@flatpak@' '${pkgs.flatpak}/bin/flatpak' \
      --replace-fail '@software@' '${pkgs.gnome-software}/bin/gnome-software'
  '';
  buildPhase = ''valac --pkg unity --pkg gio-2.0 main.vala -o unity-flatpak-scope'';
  installPhase = ''
    install -Dm755 unity-flatpak-scope $out/bin/unity-flatpak-scope
    mkdir -p $out/share/unity/scopes/flatpak $out/share/dbus-1/services
    cat >$out/share/unity/scopes/flatpak.scope <<SCOPE
    [Scope]
    GroupName=com.canonical.Unity.Scope.Home
    UniqueName=/com/canonical/unity/masterscope/flatpak
    Name=Flatpak
    Icon=system-software-install
    SearchHint=Search Flatpak applications
    Type=flatpak
    IsMaster=true
    [Category apps]
    Name=Flatpak applications
    Icon=system-software-install
    ContentType=apps
    SCOPE
    cat >$out/share/unity/scopes/flatpak/catalogue.scope <<SCOPE
    [Scope]
    DBusName=org.unityonix.Flatpak
    DBusPath=/org/unityonix/Flatpak
    Name=Flathub catalogue
    Icon=system-software-install
    Type=flatpak
    SearchHint=Search Flatpak applications
    SCOPE
    cat >$out/share/dbus-1/services/org.unityonix.Flatpak.service <<SERVICE
    [D-BUS Service]
    Name=org.unityonix.Flatpak
    Exec=$out/bin/unity-flatpak-scope
    SERVICE
  '';
}
