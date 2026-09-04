{
  description = "Separate experimental Unity 7 NixOS module; runtime port pending";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    base = import ./pkgs/components.nix { inherit pkgs; };
  in {
    packages.${system} = base // (import ./pkgs/desktop-components.nix { inherit pkgs base; }) // {
      compiz = pkgs.callPackage ./pkgs/compiz.nix {};
      nux = pkgs.callPackage ./pkgs/nux.nix {};
      unity = pkgs.callPackage ./pkgs/unity.nix {
        inherit (self.packages.${system}) compiz nux libunity libunity-misc
          xpathselect libindicator ido unity-settings-daemon gtk3-unity
          gsettings-ubuntu-schemas;
      };
    };
    nixosModules.default = import ./modules/unity.nix;
    nixosModules.unity = self.nixosModules.default;
    # Explicitly a wiring diagnostic, not Unity. No host configuration changes.
    nixosConfigurations.unity-module-test = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ self.nixosModules.default ./tests/diagnostic-vm.nix ];
    };
    checks.${system} = {
      shell-smoke = import ./tests/shell-smoke.nix { inherit pkgs; unityPackages = self.packages.${system}; };
      module = import ./tests/eval.nix { inherit nixpkgs pkgs; };
      foundations = import ./tests/build-interfaces.nix {
        inherit pkgs;
        inherit (self.packages.${system}) compiz nux;
      };
    };
  };
}
