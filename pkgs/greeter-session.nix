{ pkgs, unityPackages }:
let
  u = unityPackages;
  session = u.unity-session;
  names = [ "application" "power" "datetime" "keyboard" "session" "sound" ];
  launcher = pkgs.writeShellScript "unity-greeter-session" ''
    export XDG_CURRENT_DESKTOP=Unity
    export GSETTINGS_SCHEMA_DIR=${session.schemas}/share/glib-2.0/schemas
    export XDG_DATA_DIRS=${session.data}/share:''${XDG_DATA_DIRS:-/run/current-system/sw/share}
    export LD_LIBRARY_PATH=${u.gtk3-unity}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    export GDK_PIXBUF_MODULE_FILE=${pkgs.librsvg}/${pkgs.gdk-pixbuf.binaryDir}/loaders.cache
    export UNITY_INDICATOR_DIR=${session.indicators}/lib/indicators/3
    export UNITY_INDICATOR_SERVICE_DIR=${session.indicators}/share/unity/indicators
    export PATH=${pkgs.lib.makeBinPath [ pkgs.networkmanagerapplet pkgs.coreutils pkgs.glib ]}:$PATH
    children=()
    cleanup() {
      for pid in "''${children[@]}"; do kill "$pid" 2>/dev/null || true; done
      wait || true
    }
    trap cleanup EXIT
    trap 'exit 0' HUP INT TERM
    ${pkgs.lib.concatMapStringsSep "\n" (name: ''
      ${u."indicator-${name}"}/libexec/indicator-${name}/indicator-${name}-service &
      children+=($!)
    '') names}
    ${u.unity-greeter}/bin/unity-greeter &
    greeter_pid=$!
    children+=($greeter_pid)
    wait "$greeter_pid"
  '';
in pkgs.writeTextDir "unity-greeter.desktop" ''
  [Desktop Entry]
  Name=Unity Greeter
  Comment=Unity login screen
  Exec=${launcher}
  Type=Application
''
