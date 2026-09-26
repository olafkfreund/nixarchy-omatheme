{ config, ... }:
{
  # Stylix/Home Manager owns the application structure. The runtime engine
  # Example only: a separate adapter must own and render this mutable file.
  # Hyprchroma preserves the generated wrapper but does not create this file.
  programs.alacritty.settings.general.import = [
    "${config.home.homeDirectory}/.config/omarchy/runtime/alacritty.toml"
  ];
}
