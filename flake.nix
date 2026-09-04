{
  description = "Unity 7 desktop packages and standalone NixOS module";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  outputs = { self, nixpkgs }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
  in {
    packages.${system} = import ./pkgs { inherit pkgs; };
    overlays.default = final: prev: { unity7 = import ./pkgs { pkgs = final; }; };
    nixosModules.default = import ./modules/unity.nix;
    nixosModules.unity = self.nixosModules.default;
    nixosConfigurations.unity-test = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [ self.nixosModules.default ./tests/vm.nix ];
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
