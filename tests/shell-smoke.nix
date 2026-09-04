{ pkgs, unityPackages }:
let
  u = unityPackages;
  data = pkgs.buildEnv {
    name = "unity-smoke-data";
    paths = [ u.unity u.compiz u.libunity u.gsettings-ubuntu-schemas
      u.unity-settings-daemon u.unity-greeter pkgs.gsettings-desktop-schemas pkgs.adwaita-icon-theme ];
    pathsToLink = [ "/share" ];
    ignoreCollisions = true;
  };
in pkgs.runCommand "unity-shell-smoke" {
  nativeBuildInputs = with pkgs; [ xvfb dbus glib xwininfo imagemagick procps mesa-demos ];
} ''
  mkdir -p $out "$TMPDIR/config" "$TMPDIR/data" "$TMPDIR/runtime"
  chmod 700 "$TMPDIR/runtime"
  export FONTCONFIG_FILE=${pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; }}
  export XDG_CACHE_HOME="$TMPDIR/cache"
  export XDG_CONFIG_HOME="$TMPDIR/config" XDG_DATA_HOME="$TMPDIR/data"
  export XDG_RUNTIME_DIR="$TMPDIR/runtime"
  export XDG_CURRENT_DESKTOP=Unity DESKTOP_SESSION=ubuntu
  export XDG_DATA_DIRS=${data}/share
  for schemaDir in ${data}/share/gsettings-schemas/*; do
    export XDG_DATA_DIRS="$schemaDir:$XDG_DATA_DIRS"
  done
  export GSETTINGS_BACKEND=memory
  export LD_LIBRARY_PATH=${u.gtk3-unity}/lib:${pkgs.mesa}/lib
  export __GLX_VENDOR_LIBRARY_NAME=mesa
  export LIBGL_ALWAYS_SOFTWARE=1
  export LIBGL_DRIVERS_PATH=${pkgs.mesa}/lib/dri
  export COMPIZ_PLUGIN_DIR=${u.unity}/lib/compiz:${u.compiz}/lib/compiz
  export DISPLAY=:99
  Xvfb :99 -screen 0 1280x800x24 +extension GLX -nolisten tcp >$out/xserver.log 2>&1 &
  xserver=$!
  trap 'kill "$xserver" 2>/dev/null || true' EXIT
  for i in $(seq 1 50); do
    xwininfo -root >/dev/null 2>&1 && break
    sleep 0.1
  done
  glxinfo -B >$out/renderer.txt
  dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- ${pkgs.bash}/bin/bash -euc '
    ${u.compiz}/bin/compiz --debug --replace composite opengl compiztoolbox copytex scale move resize place unityshell >"$out/unity.log" 2>&1 &
    shell_pid=$!
    trap "kill $shell_pid 2>/dev/null || true" EXIT
    sleep 15
    if ! kill -0 "$shell_pid" 2>/dev/null; then
      cat "$out/unity.log"
      exit 1
    fi
    if grep -q "Failed to load plugin: unityshell\|Failed to start plugin: unityshell" "$out/unity.log"; then cat "$out/unity.log"; exit 1; fi
    xwininfo -root -tree >"$out/windows.txt"
    import -window root "$out/desktop.png"
  '
''
