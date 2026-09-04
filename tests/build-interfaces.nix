{ pkgs, compiz, nux }:
pkgs.runCommand "unity-foundation-interfaces" {
  nativeBuildInputs = [ pkgs.pkg-config pkgs.cmake pkgs.stdenv.cc ];
  buildInputs = [ compiz nux ];
} ''
  pkg-config --exists 'compiz >= 0.9.11' libcompizconfig compiz-opengl \
    'nux-4.0 >= 4.0.5'
  cat > nux-consumer.cpp <<'EOF'
  #include <Nux/Nux.h>
  int main() { nux::NuxInitialize(nullptr); }
  EOF
  $CXX nux-consumer.cpp -o nux-consumer $(pkg-config --cflags --libs nux-4.0)
  cat > CMakeLists.txt <<'EOF'
  cmake_minimum_required(VERSION 3.17)
  project(UnityDependencyProbe C CXX)
  find_package(Compiz REQUIRED)
  include(CompizPlugin)
  EOF
  cmake -S . -B build -DCMAKE_MODULE_PATH=${compiz}/share/cmake/Modules
  ${compiz}/bin/compiz --version > compiz-version.txt
  for plugin in composite opengl compiztoolbox scale; do
    ${pkgs.glibc.bin}/bin/ldd ${compiz}/lib/compiz/lib$plugin.so > "$plugin-libraries.txt"
    if grep -q 'not found' "$plugin-libraries.txt"; then
      cat "$plugin-libraries.txt"
      exit 1
    fi
  done
  helperStatus=0
  ${nux}/libexec/nux/unity_support_test --help > nux-helper-help.txt || helperStatus=$?
  # Upstream deliberately returns 2 after printing help.
  test "$helperStatus" -eq 2
  mkdir -p $out
  cp compiz-version.txt nux-helper-help.txt $out/
  # Link-check only: graphical Nux initialization requires an X server.
  touch $out/nux-link-check-passed
''
