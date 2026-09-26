---
status: approved
issue: 7
author: olafkfreund
---

# Intent: Runtime bridges for remaining desktop applications

## Problem

The current runtime theme integration updates GTK, Qt/KDE, browser extensions,
Pear Desktop, and Alacritty, but Kitty, Foot, Ghostty, and Electron
applications still depend on Omarchy's existing theme behavior or manual
restarts. This prevents one Omarchy theme selection from consistently reaching
the complete running desktop.

Stylix and Home Manager may own the application configuration files as
immutable Nix store links. A runtime bridge must therefore update only a
user-owned boundary and must not overwrite Nix-generated files.

## Proposed outcome

One Omarchy theme change updates the supported Kitty, Foot, Ghostty, and
Electron theme surfaces through the NixOS-packaged engine without a NixOS
rebuild. Each application reports whether it was synchronized, reloaded, or
requires a restart.

The solution works in both environments:

- systems using Stylix, where Stylix remains the declarative template;
- Nixarchy systems without Stylix, where the runtime engine supplies the
  complete user-owned configuration boundary.

## Affected users and systems

- NixOS users importing this flake's `nixosModules.default` module;
- Nixarchy users importing `nixosModules.nixarchy`;
- the Hyprchroma daemon, Omarchy hooks, and menu plugin;
- Kitty, Foot, Ghostty, and Electron-based applications;
- the Razer desktop used for live acceptance testing.

## Constraints

- Do not edit `/home/olafkfreund/.config/nixos` during implementation or tests.
- Do not write to `/nix/store` at runtime.
- Preserve Stylix and Home Manager ownership boundaries.
- Use native application imports or user-owned generated files where possible.
- Do not claim live reload where the application only supports restart.
- Keep Flatpak and Electron integration opt-in when it can affect sandboxed or
  application-specific configuration.
- Follow the existing NixOS module and feature-flag architecture.

## Open questions

- Which runtime ownership strategy is correct for each terminal: native
  import, user-owned wrapper, or generated full configuration?
- Which Electron applications can share a safe theme adapter, and which need
  application-specific profiles or restart handling?
- Should Electron support be one opt-in target or a per-application list?
- Which applications are installed on Razer and can be used for acceptance
  testing?
