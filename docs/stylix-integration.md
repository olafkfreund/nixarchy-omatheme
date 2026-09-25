# Stylix integration

Stylix remains responsible for declarative application configuration and
rebuild-only system targets. The runtime engine owns only mutable files that
applications read after a theme switch.

## Import boundary example

For an application with a native import option, keep the import in the
Stylix/Home Manager configuration and point it at a user-owned runtime file:

```nix
{ config, ... }:
{
  programs.alacritty.settings.general.import = [
    "${config.home.homeDirectory}/.config/omarchy/runtime/alacritty.toml"
  ];
}
```

The runtime engine may replace that file atomically. It must never replace the
Stylix-generated wrapper in the Nix store.

## Ownership rules

- Do not use `home.file` or a Stylix target to generate the mutable runtime file.
- Do not make the runtime engine rewrite a file still owned by Home Manager.
- Prefer an application-native import over a wrapper.
- Use a symlink only when the application follows it reliably.
- Use a launch wrapper when the application accepts a config path or environment
  override.
- Disable the Stylix target when the engine must render the complete config.
- Keep GRUB, Plymouth, initrd, console, fonts, cursors, and icons rebuild-only.

## Reload semantics

Updating the imported file and updating the visible application are separate
checks. The engine reports the target as synchronized only after a supported
reload succeeds; otherwise it reports that the application must be restarted.
