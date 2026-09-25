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
          baseTestModules = [
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
          stylixProbeModule =
            { lib, ... }:
            {
              options.stylix.enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
            };
          makeTestSystem =
            extraModules:
            nixpkgs.lib.nixosSystem {
              inherit system;
              modules = baseTestModules ++ extraModules;
            };
          noStylixSystem = makeTestSystem [ ];
          stylixSystem = makeTestSystem [ stylixProbeModule ];
          runtimeSystem = makeTestSystem [
            stylixProbeModule
            { programs.nixarchyThemeEngine.stylix.mode = "runtime"; }
          ];
          requiredModeFails =
            !(builtins.tryEval (
              (makeTestSystem [
                { programs.nixarchyThemeEngine.stylix.mode = "stylix"; }
              ]).config.system.build.toplevel.drvPath
            )).success;
          serviceFor =
            testSystem: testSystem.config.home-manager.users.test.systemd.user.services.hyprchromad;
        in
        {
          package = self.packages.${system}.default;
          module =
            builtins.deepSeq
              {
                noStylix = {
                  service = serviceFor noStylixSystem;
                  mode = (serviceFor noStylixSystem).Service.Environment;
                };
                stylix = {
                  service = serviceFor stylixSystem;
                  mode = (serviceFor stylixSystem).Service.Environment;
                };
                runtime = {
                  service = serviceFor runtimeSystem;
                  mode = (serviceFor runtimeSystem).Service.Environment;
                };
                plugin =
                  noStylixSystem.config.home-manager.users.test.home.file.".config/omarchy/plugins/io.github.nobledoodle.omarchroma/manifest.json";
                themeHook =
                  noStylixSystem.config.home-manager.users.test.home.file.".config/omarchy/hooks/theme-set.d/hyprchroma";
                inherit requiredModeFails;
              }
              (
                assert
                  (serviceFor noStylixSystem).Service.Environment == [
                    "NIXARCHY_THEME_ENGINE_MODE=runtime"
                  ];
                assert
                  (serviceFor stylixSystem).Service.Environment == [
                    "NIXARCHY_THEME_ENGINE_MODE=stylix"
                  ];
                assert
                  (serviceFor runtimeSystem).Service.Environment == [
                    "NIXARCHY_THEME_ENGINE_MODE=runtime"
                  ];
                assert requiredModeFails;
                pkgs.runCommand "nixarchy-omatheme-module-eval" { } "touch $out"
              );
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

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
