---
status: draft
issue: 38
author: olafkfreund
---

# Intent: Package Omarchroma runtime dependencies on NixOS

## Problem

The NixOS package currently wraps Omarchroma's scripts and supplies basic
command-line tools, but it does not declare the optional runtime dependencies
used by Omarchroma's browser and desktop integrations. Users may therefore
enable a target that exists upstream while the required Python module or theme
assets are missing from the NixOS runtime.

## Proposed outcome

The NixOS package provides the runtime dependencies required by the supported
Omarchroma targets through the flake, with clear behavior for optional
integrations. Users should not need to install Python packages manually or
modify the immutable NixOS installation. Target status should distinguish an
installed dependency from an unavailable optional integration.

## Affected users and systems

- NixOS users importing `nixosModules.default` or `nixosModules.nixarchy`.
- Stylix and non-Stylix installations using the Omarchroma runtime engine.
- Browser synchronization and GTK/libadwaita desktop integrations.
- The `hyprchroma` package, its systemd user service, and runtime checks.

## Constraints

- Keep the package reproducible and declarative; no pip installation at
  activation time.
- Do not make browser-only dependencies mandatory for users who disable the
  browser target.
- Preserve the existing shell, terminal, Electron, GTK, Qt/KDE, and Flatpak
  behavior.
- Do not modify the user's NixOS configuration directory directly.
- Runtime services must continue to operate without Stylix.

## Open questions

- Which upstream dependencies are required for each target, and which can be
  split into optional package inputs to avoid unnecessary closure size?
- Should GTK/libadwaita assets be supplied by the module, by the package, or
  only documented as host-level dependencies?
- What is the correct status and fallback when an optional dependency is not
  installed?
