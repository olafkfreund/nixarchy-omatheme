# nixarchy-omatheme

NixOS integration for an Omarchy-compatible runtime theme engine.

`nixarchy-omatheme` packages [Omarchroma](https://github.com/NobleDoodle/omarchroma)
for NixOS and exposes its live theme switching through a small NixOS module.
The Omarchy palette remains the runtime source of truth: selecting a theme
updates the running desktop immediately, while NixOS and Home Manager still
declare the packages, hooks, service, and application defaults.

## Why this exists

Stylix is excellent at declaring a consistent theme during a NixOS rebuild.
Omarchy is excellent at changing a running desktop in one action. Stylix is
optional; this project connects both models when it is available and provides
the same runtime path when it is not:

- Stylix remains the declarative template for supported application targets.
- Omarchy's theme engine owns the active palette and live reload event.
- The NixOS module installs the engine, daemon, Omarchy plugin, and hooks.
- Applications that cannot reload still receive their declarative Stylix
  configuration on the next rebuild or through their normal reload mechanism.
- Nixarchy's offline ISO works without importing or installing Stylix.

This is intentionally a NixOS module, not a second desktop configuration
system.

## Add it to a flake

```nix
{
  inputs.nixarchy-omatheme.url = "github:olafkfreund/nixarchy-omatheme";

  outputs = { self, nixpkgs, home-manager, nixarchy-omatheme, ... }:
    nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        nixarchy-omatheme.nixosModules.default
        {
          programs.nixarchyThemeEngine = {
            enable = true;
            user = "olafkfreund";
          };
        }
      ];
    };
}
```

For Nixarchy installations, use the dedicated module. It imports the generic
engine and enables it when the Nixarchy desktop is enabled, using
`programs.nixarchy.user` when set:

```nix
{
  imports = [ nixarchy-omatheme.nixosModules.nixarchy ];

  programs.nixarchy.enable = true;
  programs.nixarchy.user = "olafkfreund";
}
```

This path does not import or install Stylix. It is suitable for the Nixarchy
offline ISO.

The module installs `hyprchromad` as a user service and places the Omarchy
plugin and theme hooks under the selected user's Home Manager configuration.
Apply it with the normal NixOS workflow:

```sh
nixos-rebuild switch --flake .
omarchy theme set nord
```

The theme command is runtime-only. It does not require a rebuild or a second
declarative theme definition.

## Theme integration modes

The default mode detects whether the Stylix NixOS module is imported:

```nix
programs.nixarchyThemeEngine.stylix.mode = "auto";
```

Use `runtime` to ignore Stylix, or `stylix` to require it explicitly:

```nix
programs.nixarchyThemeEngine.stylix.mode = "runtime";
```

Detection happens during Nix evaluation through the presence of Stylix's module
options. It does not depend on a Stylix executable or an installed package.

## Stylix boundary

Keep Stylix enabled for its supported targets and generated application
configuration. Use the runtime engine for palette changes and live reloads.
The intended ownership split is documented in
[`docs/target-matrix.md`](docs/target-matrix.md) and
[`docs/stylix-integration.md`](docs/stylix-integration.md).

When a target needs the active runtime palette, import the generated colors
through an explicit file or template boundary rather than duplicating color
values in Nix. This keeps rebuild-time declarations reproducible while letting
the Omarchy engine update runtime files atomically.

When Stylix is absent, the runtime engine renders those files itself from the
active Omarchy palette. The daemon, hooks, menu plugin, and application target
behavior remain the same.

The current runtime target toggles are GTK, Qt/KDE, Dark Reader, Pear Desktop,
and opt-in Flatpak support. Terminal colors remain owned by Omarchy's native
theme command until a verified runtime adapter exists.

## Development

```sh
nix flake check
nix fmt
nix build .#hyprchroma
nix build .#omarchroma-plugin
```

The flake check evaluates the NixOS/Home Manager module. The package checks
validate the patched runtime scripts and plugin manifest. Upstream's test
suite remains available in the source repository.

## Status

This project is early-stage. The package and module boundary are working; the
application target matrix will grow as each runtime integration is verified.

## License

The integration code is provided under the project license. The packaged
Omarchroma assets retain their upstream license and attribution.
