{
  config,
  lib,
  options,
  pkgs,
  themeEngineSrc,
  ...
}:
let
  enginePackage = pkgs.callPackage ../pkgs/hyprchroma.nix {
    src = themeEngineSrc;
  };
  defaultPluginPackage = pkgs.callPackage ../pkgs/omarchroma-plugin.nix {
    src = themeEngineSrc;
    engine = enginePackage;
  };
  cfg = config.programs.nixarchyThemeEngine;
  stylixModuleImported = options ? stylix;
  resolvedThemeMode =
    if cfg.stylix.mode == "runtime" then
      "runtime"
    else if cfg.stylix.mode == "stylix" then
      "stylix"
    else if stylixModuleImported then
      "stylix"
    else
      "runtime";
  runtimeTargets = [
    {
      name = "gtk";
      enabled = cfg.targets.gtk;
    }
    {
      name = "qt-kde";
      enabled = cfg.targets.qtKde;
    }
    {
      name = "dark-reader";
      enabled = cfg.targets.darkReader;
    }
    {
      name = "pear";
      enabled = cfg.targets.pear;
    }
    {
      name = "flatpak";
      enabled = cfg.targets.flatpak;
    }
  ];
  targetCommands = map (
    target:
    "${cfg.package}/bin/hyprchroma --target=${target.name} --set-enabled=${lib.boolToString target.enabled} --quiet"
  ) runtimeTargets;
in
{
  options.programs.nixarchyThemeEngine = {
    enable = lib.mkEnableOption "the Omarchy runtime theme engine";

    user = lib.mkOption {
      type = lib.types.str;
      default = "olafkfreund";
      description = "User whose Omarchy graphical session owns the theme engine.";
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = enginePackage;
      description = "Package providing the hyprchroma runtime engine.";
    };

    pluginPackage = lib.mkOption {
      type = lib.types.package;
      default = defaultPluginPackage;
      description = "Omarchy bar plugin for the runtime theme engine.";
    };

    stylix.mode = lib.mkOption {
      type = lib.types.enum [
        "auto"
        "runtime"
        "stylix"
      ];
      default = "auto";
      description = ''
        Theme integration mode. "auto" uses Stylix when its NixOS module is
        imported and otherwise uses the runtime engine. "runtime" ignores
        Stylix. "stylix" requires the Stylix NixOS module to be imported.
      '';
    };

    targets = {
      gtk = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Synchronize GTK and GNOME colors at runtime.";
      };

      qtKde = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Synchronize Qt and KDE colors at runtime.";
      };

      darkReader = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Synchronize installed Dark Reader browser extensions.";
      };

      pear = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Synchronize Pear Desktop when it is installed.";
      };

      flatpak = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Synchronize Flatpak applications using the portal.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.stylix.mode != "stylix" || stylixModuleImported;
        message = "programs.nixarchyThemeEngine.stylix.mode = \"stylix\" requires the Stylix NixOS module to be imported";
      }
    ];

    home-manager.users.${cfg.user} = {
      home.packages = [ cfg.package ];

      home.file = {
        ".config/omarchy/hooks/theme-set.d/hyprchroma" = {
          source = "${cfg.package}/share/hyprchroma/hooks/hyprchroma";
          executable = true;
        };
        ".config/omarchy/hooks/font-set.d/hyprchroma" = {
          source = "${cfg.package}/share/hyprchroma/hooks/hyprchroma";
          executable = true;
        };
      };

      home.activation.nixarchyThemeEnginePlugin = {
        after = [ "linkGeneration" ];
        before = [ ];
        data = ''
          plugin_dir="$HOME/.config/omarchy/plugins/io.github.nobledoodle.omarchroma"
          run ${pkgs.coreutils}/bin/mkdir -p "$plugin_dir"
          for file in manifest.json BarWidget.qml Panel.qml README.md; do
            target="$plugin_dir/$file"
            if [ -L "$target" ]; then
              run ${pkgs.coreutils}/bin/rm -- "$target"
            fi
            run ${pkgs.coreutils}/bin/install -Dm644 "${cfg.pluginPackage}/$file" "$target"
          done
        '';
      };

      home.activation.nixarchyThemeEngineAlacritty = {
        after = [ "linkGeneration" ];
        before = [ ];
        data = ''
          alacritty_config="$HOME/.config/alacritty/alacritty.toml"
          if [ -L "$alacritty_config" ]; then
            generated_config=$(${pkgs.coreutils}/bin/readlink -f -- "$alacritty_config")
            if [ -f "$generated_config" ]; then
              temporary_config="$alacritty_config.nixarchy-tmp"
              run ${pkgs.coreutils}/bin/rm -f -- "$temporary_config"
              run ${pkgs.coreutils}/bin/install -Dm644 "$generated_config" "$temporary_config"
              run ${pkgs.coreutils}/bin/mv -f -- "$temporary_config" "$alacritty_config"
            fi
          fi
        '';
      };

      systemd.user.services.hyprchromad = {
        Unit = {
          Description = "Omarchy runtime theme synchronization";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${cfg.package}/bin/hyprchroma daemon";
          ExecStartPre = targetCommands;
          Environment = [ "NIXARCHY_THEME_ENGINE_MODE=${resolvedThemeMode}" ];
          Restart = "always";
          RestartSec = 2;
          RestartPreventExitStatus = 78;
          NoNewPrivileges = true;
          PrivateTmp = true;
          PrivateDevices = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectControlGroups = true;
          ProtectHostname = true;
          ProtectClock = true;
          RestrictSUIDSGID = true;
          RestrictRealtime = true;
          RestrictNamespaces = true;
          RestrictAddressFamilies = [ "AF_UNIX" ];
          SystemCallArchitectures = "native";
          SystemCallFilter = [ "@system-service" ];
          LockPersonality = true;
        };

        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
