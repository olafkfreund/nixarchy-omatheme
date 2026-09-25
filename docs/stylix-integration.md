# Stylix integration

Stylix is optional. The runtime engine is the base integration and works on
plain NixOS and on the Nixarchy offline image without importing Stylix at all.
When the Stylix NixOS module is present, the engine can use it for declarative
configuration shape and rebuild-only targets, while still owning mutable files
that applications read after a theme switch.

## Module modes

```nix
programs.nixarchyThemeEngine.stylix.mode = "auto";
```

`auto` detects the Stylix NixOS module during evaluation. It selects the
Stylix integration when `options.stylix` exists and selects the runtime-only
integration otherwise. The other modes are explicit:

- `runtime` ignores Stylix, even when it is imported.
- `stylix` requires the Stylix NixOS module and fails evaluation if it is not
  imported.

Detection is based on imported NixOS module options, not on a command or a
package lookup. Stylix is a module, not a runtime executable.

The same declaration therefore works in both environments:

```nix
programs.nixarchyThemeEngine.enable = true;
```

The Nixarchy offline ISO does not need to add Stylix as an input. It receives
the same daemon, Omarchy hooks, plugin, runtime palette, and target adapters.
For that installation, import `nixosModules.nixarchy`; it connects the engine
to `programs.nixarchy.enable` and `programs.nixarchy.user` without adding a
Stylix dependency.

## Runtime targets

Hyprchroma currently synchronizes the targets it actually implements:

```nix
programs.nixarchyThemeEngine.targets = {
  gtk = true;
  qtKde = true;
  darkReader = true;
  pear = true;
  flatpak = false;
};
```

The first four targets are enabled by default. Flatpak is opt-in because it
changes files through the desktop portal and affects sandboxed applications.
The module applies these settings when the user service starts, then the
daemon follows subsequent Omarchy theme changes.

GTK and Qt/KDE are synchronized through their native user configuration files.
The active palette is also available at:

```text
~/.config/hyprchroma/palette.toml
```

Terminals are currently themed by Omarchy's own theme command and are not
pretended to be Hyprchroma import targets. A terminal-specific runtime adapter
will be added only when its config ownership and reload behavior are verified.

## Import boundary

For an application with a native import option, keep the import in the
Stylix/Home Manager configuration and point it at a user-owned runtime file
created by a verified adapter:

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

The current Hyprchroma package does not create an Alacritty runtime import file;
the example is the ownership pattern for future adapters, not a file supplied
by this release.

## Ownership rules

- Do not use `home.file` or a Stylix target to generate the mutable runtime file.
- Do not make the runtime engine rewrite a file still owned by Home Manager.
- Prefer an application-native import over a wrapper.
- Use a symlink only when the application follows it reliably.
- Use a launch wrapper when the application accepts a config path or environment
  override.
- Disable the Stylix target when the engine must render the complete config.
- When Stylix is absent, use the runtime renderer for that target instead of
  adding a fake Stylix dependency.
- Keep GRUB, Plymouth, initrd, console, fonts, cursors, and icons rebuild-only.

## Reload semantics

Updating the imported file and updating the visible application are separate
checks. The engine reports the target as synchronized only after a supported
reload succeeds; otherwise it reports that the application must be restarted.
