---
status: approved
issue: 20
spec: spec/2026-09-27-20-runtime-status-menu.md
---

# Plan: Desktop runtime status in the Nixarchy menu

Extend the existing Omarchroma plugin status presentation with a read-only,
live-watched view of Hyprchroma’s desktop target status. Keep the current JSON
schema, QML conventions, and Stylix/no-Stylix behavior unchanged.

## Steps

1. Inspect the pinned upstream `Panel.qml` markers and current plugin patch
   assertions → verify the desktop status insertion point is unique and the
   existing shell, terminal, and Electron views remain unchanged.
2. Update `pkgs/omarchroma-plugin.nix` to add the desktop status properties,
   fallback parser, `status.json` `FileView`, and compact desktop status row →
   verify known states map truthfully and missing/malformed data falls back to
   `unknown`/`unavailable` without throwing QML errors.
3. Extend the plugin build-time marker checks for the new properties, watcher,
   fallback values, mappings, and UI row → verify upstream source drift fails
   the package build clearly.
4. Use generated-source marker assertions as the smallest fixture-free check
   that the complete field mapping and malformed/missing fallback branches are
   present; do not add a QML test framework because the parser/fallback is
   embedded in generated QML and has no runtime harness in this repository →
   verify the fallback implementation without changing runtime synchronization.
5. Run the full checks and build the plugin package → verify runtime, desktop,
   Electron, module, and plugin checks pass; verify the user NixOS config
   repository remains clean.

## Tests

- `nix flake check --no-build --accept-flake-config`
- `nix build .#packages.x86_64-linux.omarchroma-plugin --accept-flake-config`
- `nix build .#checks.x86_64-linux.runtime --accept-flake-config`
- `nix build .#checks.x86_64-linux.desktop --accept-flake-config`
- `nix build .#checks.x86_64-linux.electron --accept-flake-config`
- `nix build .#checks.x86_64-linux.module --accept-flake-config`
- `git diff --check`

Expected result: the plugin builds with the desktop status view, all existing
checks remain green, and no NixOS configuration files are modified.

## Rollback

Revert the implementation commit for issue #20. The existing shell, terminal,
and Electron plugin status views remain independent, and runtime synchronization
continues to use the existing `status.json` writer.
