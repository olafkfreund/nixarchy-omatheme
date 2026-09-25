{
  config,
  lib,
  defaultPackage,
  ...
}:
let
  cfg = config.programs.nixarchyThemeEngine;
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
      default = defaultPackage;
      description = "Package providing the hyprchroma runtime engine.";
    };
  };

  config = lib.mkIf cfg.enable {
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

      systemd.user.services.hyprchromad = {
        Unit = {
          Description = "Omarchy runtime theme synchronization";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${cfg.package}/bin/hyprchroma daemon";
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
