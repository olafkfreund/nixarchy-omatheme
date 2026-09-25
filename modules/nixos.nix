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
        ".config/omarchy/plugins/io.github.nobledoodle.omarchroma/manifest.json".source =
          "${cfg.pluginPackage}/manifest.json";
        ".config/omarchy/plugins/io.github.nobledoodle.omarchroma/BarWidget.qml".source =
          "${cfg.pluginPackage}/BarWidget.qml";
        ".config/omarchy/plugins/io.github.nobledoodle.omarchroma/Panel.qml".source =
          "${cfg.pluginPackage}/Panel.qml";
        ".config/omarchy/plugins/io.github.nobledoodle.omarchroma/README.md".source =
          "${cfg.pluginPackage}/README.md";
        ".config/omarchy/hooks/theme-set.d/hyprchroma" = {
          source = "${cfg.package}/share/hyprchroma/hooks/hyprchroma";
          executable = true;
        };
        ".config/omarchy/hooks/font-set.d/hyprchroma" = {
          source = "${cfg.package}/share/hyprchroma/hooks/hyprchroma";
          executable = true;
        };
      };

      systemd.user.services.hyprchromad = {
        Unit = {
          Description = "Omarchy runtime theme synchronization";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${cfg.package}/bin/hyprchroma daemon";
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
