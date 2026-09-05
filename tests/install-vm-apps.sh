#!/usr/bin/env bash
# Run as tester inside the interactive VM. Pass the pinned nixpkgs source path.
set -euo pipefail
nixpkgs_source=${1:?Usage: bash install-vm-apps.sh /nix/store/...-source}

# Separate from Geany and Galculator in vm.nix: these exercise user profiles.
nix-env -f "$nixpkgs_source" -iA mousepad gnome-calculator

flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak install --user --noninteractive flathub org.gnome.clocks org.gnome.TextEditor

nix-env -q
flatpak list --user --app
# Verify in the Dash: Geany, Galculator, Mousepad, Calculator, Clocks, Text Editor.
# Open each result. Listing desktop files alone does not verify Unity indexing.
