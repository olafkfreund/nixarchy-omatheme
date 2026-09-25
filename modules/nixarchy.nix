{
  config,
  lib,
  options,
  ...
}:
let
  nixarchyModuleImported = options ? programs.nixarchy;
  nixarchyEnabled = nixarchyModuleImported && config.programs.nixarchy.enable;
  nixarchyUser = if nixarchyModuleImported then config.programs.nixarchy.user else null;
in
{
  config = {
    assertions = [
      {
        assertion = nixarchyModuleImported;
        message = "nixosModules.nixarchy requires the Nixarchy NixOS module";
      }
    ];

    programs.nixarchyThemeEngine = lib.mkIf nixarchyEnabled {
      enable = lib.mkDefault true;
      user = lib.mkIf (nixarchyUser != null) (lib.mkDefault nixarchyUser);
    };
  };
}
