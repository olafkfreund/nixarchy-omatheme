{
  description = "NixOS packaging and integration for an Omarchy runtime theme engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    omarchroma = {
      url = "github:NobleDoodle/omarchroma";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      omarchroma,
    }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      packages = forAllSystems (system: {
        hyprchroma = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/hyprchroma.nix {
          src = omarchroma;
        };
        default = self.packages.${system}.hyprchroma;
        omarchroma-plugin = nixpkgs.legacyPackages.${system}.callPackage ./pkgs/omarchroma-plugin.nix {
          src = omarchroma;
          engine = self.packages.${system}.hyprchroma;
        };
      });

      checks = forAllSystems (system: {
        package = self.packages.${system}.default;
      });

      nixosModules.default =
        moduleArgs:
        import ./modules/nixos.nix (
          moduleArgs
          // {
            defaultPackage = self.packages.${moduleArgs.pkgs.system}.default;
          }
        );

      devShells = forAllSystems (system: {
        default = nixpkgs.legacyPackages.${system}.mkShell {
          packages = with nixpkgs.legacyPackages.${system}; [
            bash
            jq
            python3
          ];
        };
      });
    };
}
