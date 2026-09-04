{ pkgs }:
name:
let
  entry = (builtins.fromJSON (builtins.readFile ./sources.json)).${name};
  fetch = f: pkgs.fetchurl { inherit (f) url hash; };
  packaging = entry.packaging;
in pkgs.runCommand "${name}-${entry.version}-source" {
  nativeBuildInputs = [ pkgs.gnutar pkgs.gzip pkgs.xz pkgs.patch ];
} ''
  mkdir -p $out
  tar -xf ${fetch entry.src} -C $out --strip-components=${toString entry.strip}
  chmod -R u+w $out
  cd $out
  ${pkgs.lib.optionalString (packaging != null) (
    if pkgs.lib.hasSuffix ".diff.gz" packaging.file then ''
      gzip -dc ${fetch packaging} | patch -p1
    '' else ''
      tar -xf ${fetch packaging}
    '')}
  if test -f debian/patches/series; then
    while read -r patchName patchOptions; do
      case "$patchName" in ""|\#*) continue;; esac
      if patch --dry-run --forward -p1 $patchOptions < "debian/patches/$patchName" >/dev/null; then
        patch --forward -p1 $patchOptions < "debian/patches/$patchName"
      elif patch --dry-run --reverse -p1 $patchOptions < "debian/patches/$patchName" >/dev/null; then
        echo "Already included in source diff: $patchName"
      else
        echo "Cannot apply source patch: $patchName" >&2
        exit 1
      fi
    done < debian/patches/series
  fi
''
