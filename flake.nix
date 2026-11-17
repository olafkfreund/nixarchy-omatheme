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
        hyprchroma-icons = self.packages.${system}.default.override { withIcons = true; };
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
          stubPackage = pkgs.runCommand "hyprchroma-stub" { } ''
            mkdir -p $out/bin $out/lib/hyprchroma
            cat > $out/lib/hyprchroma/hyprchroma-palette <<'EOF'
            #!${pkgs.bash}/bin/bash
            echo palette >> "$STUB_LOG"
            exit "''${STUB_PALETTE_RC:-0}"
            EOF
            cat > $out/bin/hyprchroma <<'EOF'
            #!${pkgs.bash}/bin/bash
            if [ -f "$STUB_BASE" ]; then base=present; else base=absent; fi
            echo "hyprchroma $* base=$base" >> "$STUB_LOG"
            exit "''${STUB_RENDER_RC:-0}"
            EOF
            chmod 755 $out/bin/hyprchroma $out/lib/hyprchroma/hyprchroma-palette
          '';
          stubSystem = makeTestSystem [ { programs.nixarchyThemeEngine.package = stubPackage; } ];
          starshipOffSystem = makeTestSystem [ { programs.nixarchyThemeEngine.targets.starship = false; } ];
          shellsOffSystem = makeTestSystem [
            {
              programs.nixarchyThemeEngine.targets = {
                starship = false;
                bash = false;
                zsh = false;
                fish = false;
              };
            }
          ];
          hm = testSystem: testSystem.config.home-manager.users.test;
          stylixSystem = makeTestSystem [ stylixProbeModule ];
          runtimeSystem = makeTestSystem [
            stylixProbeModule
            { programs.nixarchyThemeEngine.stylix.mode = "runtime"; }
          ];
          externallyManagedPluginSystem = makeTestSystem [
            { programs.nixarchyThemeEngine.managePlugin = false; }
          ];
          neovimProgramSystem = makeTestSystem [
            { home-manager.users.test.programs.neovim.enable = true; }
          ];
          targetSystem = makeTestSystem [
            {
              programs.nixarchyThemeEngine.targets = {
                gtk = false;
                qtKde = false;
                thunderbird = false;
                flatpak = true;
                browsers = true;
              };
            }
          ];
          nixarchyProbeModule =
            { lib, ... }:
            {
              options.programs.nixarchy = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                };
                user = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                };
              };
            };
          nixarchySystem = nixpkgs.lib.nixosSystem {
            inherit system;
            modules = [
              home-manager.nixosModules.home-manager
              self.nixosModules.nixarchy
              nixarchyProbeModule
              {
                system.stateVersion = "25.11";
                users.users.test = {
                  isNormalUser = true;
                  home = "/home/test";
                };
                programs.nixarchy = {
                  enable = true;
                  user = "test";
                };
                home-manager.users.test.home.stateVersion = "25.11";
              }
            ];
          };
          requiredModeFails =
            !(builtins.tryEval (
              (makeTestSystem [
                { programs.nixarchyThemeEngine.stylix.mode = "stylix"; }
              ]).config.system.build.toplevel.drvPath
            )).success;
          hasPackage =
            system: package:
            builtins.any (
              p: (p.name or "") == package.name
            ) system.config.home-manager.users.test.home.packages;
          iconsSystem = makeTestSystem [ { programs.nixarchyThemeEngine.icons.enable = true; } ];
          iconsPackage = self.packages.${system}.hyprchroma-icons;
          pluginWithIcons = pkgs.callPackage ./pkgs/omarchroma-plugin.nix {
            src = omarchroma;
            engine = iconsPackage;
          };
          pluginOf = testSystem: testSystem.config.programs.nixarchyThemeEngine.pluginPackage.drvPath;
          revertIcons = "-${
            self.packages.${system}.default
          }/bin/hyprchroma --target=icons --set-enabled=false --quiet --force";
          iconsCommands =
            testSystem:
            builtins.filter (
              command: builtins.match ".*--target=icons.*" command != null
            ) (serviceFor testSystem).Service.ExecStartPre;
          hasPackageMatching =
            testSystem: pattern:
            builtins.any (
              p: builtins.match pattern (p.name or "") != null
            ) testSystem.config.home-manager.users.test.home.packages;
          serviceFor =
            testSystem: testSystem.config.home-manager.users.test.systemd.user.services.hyprchromad;
          pluginUnit =
            noStylixSystem.config.home-manager.users.test.systemd.user.services.nixarchyThemeEnginePlugin;
          pluginSwitchMethod = pluginUnit.Unit."X-SwitchMethod" or null;
          pluginEnableTest =
            pkgs.runCommand "nixarchy-omatheme-plugin-enable"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.gnused
                ];
              }
              ''
                PLUGIN_ENABLE=${toString pluginUnit.Service.ExecStart} \
                  UNIT_SWITCH_METHOD=${if pluginSwitchMethod == null then "unset" else pluginSwitchMethod} \
                  UNIT_TIMEOUT=${toString (pluginUnit.Service.TimeoutStartSec or "unset")} \
                  ${pkgs.bash}/bin/bash ${./tests/plugin-enable.sh}
                touch $out
              '';
          runtimeTargetsTest =
            pkgs.runCommand "nixarchy-omatheme-runtime-targets"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.foot
                  pkgs.python3
                ];
              }
              ''
                HYPRCHROMA_PACKAGE=${self.packages.${system}.default} \
                  ${pkgs.bash}/bin/bash ${./tests/runtime-targets.sh}
                touch $out
              '';
          shellActivationTest =
            pkgs.runCommand "nixarchy-omatheme-shell-activation"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.fish
                  pkgs.gnugrep
                  pkgs.zsh
                ];
              }
              ''
                SHELL_ACTIVATION=${pkgs.writeText "shell-activation" (hm stubSystem).home.activation.nixarchyThemeEngineShell.data} \
                BASH_HOOK_OFF=${pkgs.writeText "bash-hook-off" (hm starshipOffSystem).programs.bash.bashrcExtra} \
                BASH_HOOK_ON=${pkgs.writeText "bash-hook-on" (hm noStylixSystem).programs.bash.bashrcExtra} \
                ZSH_HOOK_OFF=${pkgs.writeText "zsh-hook-off" (hm starshipOffSystem).programs.zsh.initContent} \
                ZSH_HOOK_ON=${pkgs.writeText "zsh-hook-on" (hm noStylixSystem).programs.zsh.initContent} \
                FISH_HOOK_OFF=${pkgs.writeText "fish-hook-off" (hm starshipOffSystem).programs.fish.interactiveShellInit} \
                FISH_HOOK_ON=${pkgs.writeText "fish-hook-on" (hm noStylixSystem).programs.fish.interactiveShellInit} \
                  ${pkgs.bash}/bin/bash ${./tests/shell-activation.sh}
                touch $out
              '';
          editorRuntimeTest =
            pkgs.runCommand "nixarchy-omatheme-editor-runtime"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.neovim
                  pkgs.gnused
                  pkgs.python3
                  pkgs.util-linux
                  pkgs.vim
                  pkgs.vimPlugins.lazy-nvim
                ];
                LAZY_NVIM = "${pkgs.vimPlugins.lazy-nvim}";
              }
              ''
                HYPRCHROMA_PACKAGE=${self.packages.${system}.default} \
                  ${pkgs.bash}/bin/bash ${./tests/editors-runtime.sh}
                touch $out
              '';
          cliCompatibilityTest =
            pkgs.runCommand "nixarchy-omatheme-cli-compatibility"
              {
                nativeBuildInputs = [ pkgs.gnugrep ];
              }
              ''
                ${self.packages.${system}.default}/bin/hyprchroma --help |
                  ${pkgs.gnugrep}/bin/grep -F -- '[--target=gtk|qt-kde|dark-reader|pear|flatpak|browsers|thunderbird|icons]'
                touch $out
              '';
          electronRuntimeTest =
            pkgs.runCommand "nixarchy-omatheme-electron-runtime"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.python3
                ];
              }
              ''
                HYPRCHROMA_PACKAGE=${self.packages.${system}.default} \
                  ${pkgs.bash}/bin/bash ${./tests/electron-runtime.sh}
                touch $out
              '';
          desktopRuntimeTest =
            pkgs.runCommand "nixarchy-omatheme-desktop-runtime"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.gawk
                  pkgs.glib
                  pkgs.jq
                  pkgs.python3
                  pkgs.util-linux
                ];
              }
              ''
                HYPRCHROMA_PACKAGE=${self.packages.${system}.default} \
                  ${pkgs.bash}/bin/bash ${./tests/desktop-runtime.sh}
                touch $out
              '';
          nixosCompatTest =
            pkgs.runCommand "nixarchy-omatheme-nixos-compat"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.python3
                ];
              }
              ''
                HYPRCHROMA_PACKAGE=${self.packages.${system}.default} \
                  ${pkgs.bash}/bin/bash ${./tests/nixos-compat.sh}
                touch $out
              '';
          paletteActionsTest =
            pkgs.runCommand "nixarchy-omatheme-palette-actions"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                ];
              }
              ''
                PLUGIN_PANEL=${self.packages.${system}.omarchroma-plugin}/Panel.qml \
                  TMPDIR=$TMPDIR ${pkgs.bash}/bin/bash ${./tests/palette-actions.sh}
                touch $out
              '';
          iconsUpstreamTest =
            pkgs.runCommand "nixarchy-omatheme-icons-upstream"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.gnused
                  pkgs.gnugrep
                  pkgs.gawk
                  pkgs.glib
                  pkgs.jq
                  pkgs.librsvg
                  iconsPackage.pythonRuntime
                ];
              }
              ''
                HYPRCHROMA_PACKAGE=${iconsPackage} \
                  PLUGIN_PANEL=${self.packages.${system}.omarchroma-plugin}/Panel.qml \
                  UPSTREAM_TESTS=${omarchroma}/tests \
                  PYTHON_ENV=${iconsPackage.pythonRuntime} \
                  ${pkgs.bash}/bin/bash ${./tests/icons-upstream.sh}
                touch $out
              '';
          iconsNixosTest =
            pkgs.runCommand "nixarchy-omatheme-icons-nixos"
              {
                nativeBuildInputs = [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.gnused
                  pkgs.librsvg
                ];
              }
              ''
                HYPRCHROMA_ICONS_PACKAGE=${iconsPackage} \
                  HYPRCHROMA_PACKAGE=${self.packages.${system}.default} \
                  PYTHON_ENV=${iconsPackage.pythonRuntime} \
                  ${pkgs.bash}/bin/bash ${./tests/icons-nixos.sh}
                touch $out
              '';
          packageDependenciesTest = pkgs.runCommand "nixarchy-omatheme-package-dependencies" { } ''
            ${self.packages.${system}.default.pythonRuntime}/bin/python3 -I -c 'import plyvel'
            touch $out
          '';
        in
        {
          package = self.packages.${system}.default;
          palette-actions = paletteActionsTest;
          package-dependencies = packageDependenciesTest;
          desktop = desktopRuntimeTest;
          electron = electronRuntimeTest;
          runtime = runtimeTargetsTest;
          shell-activation = shellActivationTest;
          editors = editorRuntimeTest;
          cli-compatibility = cliCompatibilityTest;
          nixos-compat = nixosCompatTest;
          plugin-enable = pluginEnableTest;
          icons-upstream = iconsUpstreamTest;
          icons-nixos = iconsNixosTest;
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
                targets = serviceFor targetSystem;
                nixarchy = {
                  service = nixarchySystem.config.home-manager.users.test.systemd.user.services.hyprchromad;
                  mode =
                    nixarchySystem.config.home-manager.users.test.systemd.user.services.hyprchromad.Service.Environment;
                };
                pluginActivation =
                  noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEnginePlugin;
                alacrittyActivation =
                  noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEngineAlacritty;
                themeHook =
                  noStylixSystem.config.home-manager.users.test.home.file.".config/omarchy/hooks/theme-set.d/hyprchroma";
                shellActivation = (hm noStylixSystem).home.activation.nixarchyThemeEngineShell;
                inherit requiredModeFails;
              }
              (
                assert
                  noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEngineAlacritty.after
                  == [ "linkGeneration" ];
                assert
                  builtins.match ".*readlink -f.*alacritty_config.*" (
                    noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEngineAlacritty.data
                  ) != null;
                assert
                  builtins.match ".*mv -f.*alacritty_config.*" (
                    noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEngineAlacritty.data
                  ) != null;
                assert
                  builtins.match ".*install -Dm644.*generated_config.*" (
                    noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEngineAlacritty.data
                  ) != null;
                assert
                  builtins.match ".*io.github.nobledoodle.omarchroma.*" (
                    noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEnginePlugin.data
                  ) != null;
                assert
                  builtins.match ".*install -Dm644.*" (
                    noStylixSystem.config.home-manager.users.test.home.activation.nixarchyThemeEnginePlugin.data
                  ) != null;
                assert builtins.hasAttr "nvim/site/plugin/nixarchy-theme.lua"
                  noStylixSystem.config.home-manager.users.test.xdg.dataFile;
                assert builtins.hasAttr "nvim/site/colors/omarchy.lua"
                  noStylixSystem.config.home-manager.users.test.xdg.dataFile;
                assert
                  !(builtins.hasAttr ".local/share/nvim/site/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.lua" noStylixSystem.config.home-manager.users.test.home.file);
                assert builtins.hasAttr ".vim/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.vim"
                  noStylixSystem.config.home-manager.users.test.home.file;
                assert builtins.hasAttr ".vim/pack/nixarchy/start/nixarchy-theme/colors/omarchy.vim"
                  noStylixSystem.config.home-manager.users.test.home.file;
                assert builtins.hasAttr "nvim/site/plugin/nixarchy-theme.lua"
                  stylixSystem.config.home-manager.users.test.xdg.dataFile;
                assert builtins.hasAttr "nvim/site/colors/omarchy.lua"
                  stylixSystem.config.home-manager.users.test.xdg.dataFile;
                assert
                  !(builtins.hasAttr ".local/share/nvim/site/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.lua" stylixSystem.config.home-manager.users.test.home.file);
                assert builtins.hasAttr ".vim/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.vim"
                  stylixSystem.config.home-manager.users.test.home.file;
                assert builtins.hasAttr ".vim/pack/nixarchy/start/nixarchy-theme/colors/omarchy.vim"
                  stylixSystem.config.home-manager.users.test.home.file;
                assert builtins.hasAttr "nvim/site/plugin/nixarchy-theme.lua"
                  runtimeSystem.config.home-manager.users.test.xdg.dataFile;
                assert builtins.hasAttr "nvim/site/colors/omarchy.lua"
                  runtimeSystem.config.home-manager.users.test.xdg.dataFile;
                assert
                  !(builtins.hasAttr ".local/share/nvim/site/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.lua" runtimeSystem.config.home-manager.users.test.home.file);
                assert builtins.hasAttr ".vim/pack/nixarchy/start/nixarchy-theme/plugin/nixarchy-theme.vim"
                  runtimeSystem.config.home-manager.users.test.home.file;
                assert builtins.hasAttr ".vim/pack/nixarchy/start/nixarchy-theme/colors/omarchy.vim"
                  runtimeSystem.config.home-manager.users.test.home.file;
                assert builtins.all (f: f.source != null) (
                  builtins.attrValues neovimProgramSystem.config.home-manager.users.test.home.file
                );
                assert builtins.all (f: f.source != null) (
                  builtins.attrValues neovimProgramSystem.config.home-manager.users.test.xdg.dataFile
                );
                assert
                  !(builtins.hasAttr "nixarchyThemeEnginePlugin" externallyManagedPluginSystem.config.home-manager.users.test.home.activation);
                assert builtins.hasAttr "nixarchyThemeEnginePlugin"
                  externallyManagedPluginSystem.config.home-manager.users.test.systemd.user.services;
                assert builtins.hasAttr "hyprchromad"
                  externallyManagedPluginSystem.config.home-manager.users.test.systemd.user.services;
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
                assert
                  nixarchySystem.config.home-manager.users.test.systemd.user.services.hyprchromad.Service.Environment
                  == [ "NIXARCHY_THEME_ENGINE_MODE=runtime" ];
                assert builtins.any (
                  command: builtins.match ".*--target=gtk --set-enabled=false --quiet" command != null
                ) (serviceFor targetSystem).Service.ExecStartPre;
                assert builtins.any (
                  command: builtins.match ".*--target=flatpak --set-enabled=true --quiet" command != null
                ) (serviceFor targetSystem).Service.ExecStartPre;
                assert builtins.any (
                  command: builtins.match ".*--target=browsers --set-enabled=true --quiet" command != null
                ) (serviceFor targetSystem).Service.ExecStartPre;
                assert builtins.any (
                  command: builtins.match ".*--target=thunderbird --set-enabled=false --quiet" command != null
                ) (serviceFor targetSystem).Service.ExecStartPre;
                assert builtins.any (
                  command: builtins.match ".*--target=thunderbird --set-enabled=true --quiet" command != null
                ) (serviceFor noStylixSystem).Service.ExecStartPre;
                assert iconsCommands noStylixSystem == [ revertIcons ];
                assert iconsCommands targetSystem == [ revertIcons ];
                assert iconsCommands iconsSystem == [ ];
                assert !hasPackageMatching noStylixSystem "(reversal|yaru).*";
                assert hasPackageMatching iconsSystem "reversal-icon-theme.*";
                assert hasPackageMatching iconsSystem "yaru-.*";
                assert pluginOf noStylixSystem == self.packages.${system}.omarchroma-plugin.drvPath;
                assert pluginOf iconsSystem == pluginWithIcons.drvPath;
                assert pluginOf iconsSystem != pluginOf noStylixSystem;
                assert (hm noStylixSystem).home.activation.nixarchyThemeEngineShell.before == [ "reloadSystemd" ];
                assert !(builtins.hasAttr "nixarchyThemeEngineShell" (hm shellsOffSystem).home.activation);
                assert (serviceFor noStylixSystem).Service.MemoryHigh == "1G";
                assert (serviceFor noStylixSystem).Service.MemoryMax == "1536M";
                assert (serviceFor noStylixSystem).Service.TasksMax == 128;
                assert (serviceFor noStylixSystem).Service.CPUWeight == 1000;
                assert hasPackage noStylixSystem pkgs.adw-gtk3;
                assert !hasPackage targetSystem pkgs.adw-gtk3;
                assert hasPackage noStylixSystem pkgs.kdePackages.breeze-icons;
                assert !hasPackage targetSystem pkgs.kdePackages.breeze-icons;
                assert builtins.any (
                  command: command == "${self.packages.${system}.default}/bin/hyprchroma electron status"
                ) (serviceFor noStylixSystem).Service.ExecStartPre;
                assert requiredModeFails;
                # Home Manager reports target collisions only when it builds home-files.
                pkgs.runCommand "nixarchy-omatheme-module-eval"
                  {
                    neovimHomeFiles = neovimProgramSystem.config.home-manager.users.test.home-files;
                    offClosure = pkgs.closureInfo {
                      rootPaths = [ noStylixSystem.config.programs.nixarchyThemeEngine.package ];
                    };
                    onClosure = pkgs.closureInfo {
                      rootPaths = [ iconsSystem.config.programs.nixarchyThemeEngine.package ];
                    };
                  }
                  ''
                    # Pillow is the cost of Icons: only the option brings it in.
                    ! grep -qi pillow $offClosure/store-paths
                    grep -qi pillow $onClosure/store-paths
                    touch $out
                  ''
              );
        }
      );

      nixosModules.default =
        { pkgs, ... }@moduleArgs:
        import ./modules/nixos.nix (moduleArgs // { themeEngineSrc = omarchroma; });

      nixosModules.nixarchy =
        { pkgs, ... }@moduleArgs:
        {
          imports = [
            (import ./modules/nixos.nix (moduleArgs // { themeEngineSrc = omarchroma; }))
            ./modules/nixarchy.nix
          ];
        };

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
