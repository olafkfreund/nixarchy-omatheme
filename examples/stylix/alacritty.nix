{ config, ... }:
{
  # Stylix/Home Manager owns the application structure. The runtime engine
  # owns the mutable file imported by Alacritty after an Omarchy theme switch.
  programs.alacritty.settings.general.import = [
    "${config.home.homeDirectory}/.config/omarchy/runtime/alacritty.toml"
  ];
}
