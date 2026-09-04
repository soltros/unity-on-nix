{ pkgs }:
let
  inherit (pkgs) lib;
  source = import ./ubuntu-source.nix { inherit pkgs; };
  manifest = builtins.fromJSON (builtins.readFile ./sources.json);
  auto = name: attrs: pkgs.stdenv.mkDerivation ({
    pname = name;
    version = manifest.${name}.version;
    src = source name;
    nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config intltool gnome-common gtk-doc ];
    enableParallelBuilding = true;
    env.NIX_CFLAGS_COMPILE = "-Wno-error";
    meta = { license = lib.licenses.gpl3Plus; platforms = [ "x86_64-linux" ]; };
  } // attrs);
in rec {
  gtk3-unity = pkgs.gtk3.overrideAttrs (old: {
    pname = "gtk3-unity";
    patches = (old.patches or []) ++ [
      ./patches/gtk/ubuntu_gtk_custom_menu_items.patch
      ./patches/gtk/x-canonical-accel.patch
      ./patches/gtk/message-dialog-restore-traditional-look-on-unity.patch
      ./patches/gtk/0001-calendar-always-emit-day-selected-once.patch
      ./patches/gtk/0001-gtkwindow-set-transparent-background-color.patch
      ./patches/gtk/unity-border-radius.patch
      ./patches/gtk/unity-headerbar-maximized-mode.patch
    ];
  });
  accountsservice-unity = pkgs.accountsservice.overrideAttrs (old: {
    src = source "accountsservice";
    postPatch = (old.postPatch or "") + ''
      printf '#!/bin/sh\necho 23.13.9\n' > generate-version.sh
      chmod +x generate-version.sh
      patchShebangs generate-version.sh
    '';
    prePatch = (old.prePatch or "") + ''
      # Retain Nixpkgs' shadow tools and immutable-user safeguards.
      patch -R -p1 < debian/patches/debian/Create-and-manage-groups-like-on-a-debian-system.patch
    '';
  });
  libunity-misc = auto "libunity-misc" {
    propagatedBuildInputs = with pkgs; [ glib gtk3 libx11 ];
    configureFlags = [ "--disable-gtk-doc" ];
  };
  xpathselect = pkgs.stdenv.mkDerivation {
    pname = "xpathselect";
    version = "1.4";
    src = source "xpathselect";
    nativeBuildInputs = with pkgs; [ cmake pkg-config ];
    propagatedBuildInputs = [ pkgs.boost ];
    cmakeFlags = [ "-DCMAKE_POLICY_VERSION_MINIMUM=3.5" ];
    postPatch = ''
      substituteInPlace CMakeLists.txt --replace-fail 'add_subdirectory(test)' ""
    '';
  };
  ido = auto "ido" {
    nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config intltool gnome-common gtk-doc gobject-introspection vala ];
    propagatedBuildInputs = [ gtk3-unity pkgs.glib ];
    configureFlags = [ "--disable-gtk-doc" ];
  };
  libindicator = auto "libindicator" {
    propagatedBuildInputs = [ gtk3-unity pkgs.glib ido ];
    configureFlags = [ "--with-gtk=3" "--disable-tests" ];
  };
  gsettings-ubuntu-schemas = auto "gsettings-ubuntu-touch-schemas" {
    buildInputs = [ pkgs.glib ];
  };
  libunity = auto "libunity" {
    nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config intltool gnome-common gobject-introspection vala python3 ];
    propagatedBuildInputs = with pkgs; [ glib gtk3 dee libdbusmenu ];
    configureFlags = [ "--disable-integration-tests" "--disable-docs" "--with-pygi-overrides-dir=${placeholder "out"}/${pkgs.python3.sitePackages}/gi/overrides" ];
  };
  unity-settings-daemon = auto "unity-settings-daemon" {
    nativeBuildInputs = with pkgs; [ autoreconfHook pkg-config intltool gnome-common gtk-doc gperf wrapGAppsHook3 ];
    propagatedBuildInputs = with pkgs; [ gtk3 glib gnome-desktop gsettings-desktop-schemas gsettings-ubuntu-schemas ];
    buildInputs = with pkgs; [ dbus-glib libnotify libxt libxi fontconfig libxext libx11 libxtst libpulseaudio alsa-lib librsvg libcanberra-gtk3 polkit accountsservice-unity libappindicator-gtk3 hwdata upower colord lcms2 nss libgudev libwacom xf86-input-wacom libgnomekbd libxklavier systemd ibus libGL libxkbfile xkeyboard_config networkmanager ];
    configureFlags = [ "--disable-fcitx" "--disable-packagekit" "--disable-man" "--disable-more-warnings" ];
    postPatch = ''
      substituteInPlace gnome-settings-daemon/gnome-settings-manager.c \
        --replace-fail 'signal_queue, signal_cache_free)' 'signal_queue, (GDestroyNotify) signal_cache_free)'
      substituteInPlace plugins/background/gnome-update-wallpaper-cache.c \
        --replace-fail 'main (int argc' 'int main (int argc'
      substituteInPlace plugins/keyboard/gsd-keyboard-manager.c \
        --replace-fail 'user_notify_is_loaded_cb, user_data)' 'G_CALLBACK (user_notify_is_loaded_cb), user_data)'
      substituteInPlace plugins/media-keys/what-did-you-plug-in/dialog-window.c \
        --replace-fail 'gtk_box_pack_start(GTK_CONTAINER(d->v_box)' 'gtk_box_pack_start(GTK_BOX(d->v_box)'
      substituteInPlace plugins/media-keys/gsd-media-keys-manager.c \
        --replace-fail 'g_strv_length (icon_names)' 'g_strv_length ((gchar **) icon_names)'
      substituteInPlace plugins/xrandr/gsd-xrandr-manager.c --replace-fail $'GsdRROutputInfo *laptop_output;\n\n        if (!supports_xinput_devices ())\n                return;' $'GsdRROutputInfo *laptop_output;\n\n        if (!supports_xinput_devices ())\n                return FALSE;'
      echo 'usd_test_screensaver_proxy_LDADD += $(top_builddir)/gnome-settings-daemon/libunity-settings-daemon.la' >> plugins/screensaver-proxy/Makefile.am
    '';
    preConfigure = ''
      configureFlagsArray+=(--with-systemduserunitdir="$out/lib/systemd/user")
    '';
  };
}
