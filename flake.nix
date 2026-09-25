{
  description = "NixOS packaging and integration for an Omarchy runtime theme engine";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    omarchroma = {
      url = "github:NobleDoodle/omarchroma";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
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

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          testSystem = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              home-manager.nixosModules.home-manager
              self.nixosModules.default
              {
                system.stateVersion = "25.11";
                users.users.test = {
                  isNormalUser = true;
                  home = "/home/test";
                };
                programs.nixarchyThemeEngine = {
                  enable = true;
                  user = "test";
                };
                home-manager.users.test.home.stateVersion = "25.11";
              }
            ];
          };
        in
        {
          package = self.packages.${system}.default;
          module =
            builtins.deepSeq testSystem.config.home-manager.users.test.systemd.user.services.hyprchromad
              (pkgs.runCommand "nixarchy-omatheme-module-eval" { } "touch $out");
        }
      );

      nixosModules.default =
        { pkgs, ... }@moduleArgs:
        import ./modules/nixos.nix (moduleArgs // { themeEngineSrc = omarchroma; });

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
