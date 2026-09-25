---
status: approved
issue: tbd
spec: spec/2026-09-25-tbd-omarchy-theme-engine.md
---

# Plan: Omarchy runtime theme engine for NixOS

Implement a Nix-packaged Omarchy runtime theme engine that updates mutable
user-session theme files immediately, while Stylix remains responsible for
declarative configuration shape and rebuild-only system targets.

## Steps

1. `flake.nix`, package metadata, and source layout: create the minimal flake,
   package definition, development shell, and license/README structure. Pin
   the upstream Omarchroma source or record the smallest required local
   implementation. → verify with `nix flake check`.

2. Runtime engine package: package the CLI and helpers, normalize Nix runtime
   paths, preserve rootless operation, and keep all generated state below the
   user XDG directories. Add atomic writes, a per-user lock, palette-source
   validation, and stale-application reporting. → verify with focused tests
   using temporary XDG directories and no live desktop changes.

3. Renderer target matrix: implement and document the first targets using the
   approved order: imported runtime file, symlink/path indirection, launch
   wrapper, full-config renderer, or rebuild-only fallback. Start with GTK,
   Qt/KDE, Alacritty/Kitty/Foot/Ghostty, and the existing Omarchy palette;
   add browser, Electron, and Flatpak adapters only where their boundaries are
   verified. → verify one test per ownership strategy.

4. NixOS/Home Manager module: expose an enable option, package option, target
   toggles, Flatpak opt-in, user service, and declarative Omarchy hooks. The
   service runs as the desktop user after the graphical session and never
   writes the Nix store. → verify module evaluation and generated unit/hooks.

5. Stylix integration contract: keep Stylix optional, detect its NixOS module
   during evaluation, provide explicit `auto`, `runtime`, and `stylix` modes,
   provide stable wrapper/config paths that can reference runtime files,
   document which Stylix targets must be disabled when the runtime engine owns a
   path, and preserve static Stylix targets such as GRUB, Plymouth, fonts,
   icons, cursor, and console. → verify no ownership collisions in consuming
   NixOS evaluations with and without Stylix.

6. Omarchy menu plugin: add a namespaced manifest and thin QML panel for status,
   sync, target toggles, stale applications, and restore-stock. Delegate all
   file and process operations to the CLI. → verify with `omarchy plugin
   validate`, `qmllint`, and shell IPC checks.

7. Consumer integration: expose a `nixosModules.nixarchy` entry point that
   imports the generic module and auto-enables it from
   `programs.nixarchy.enable`, using `programs.nixarchy.user` when configured.
   Keep direct NixOS users on `nixosModules.default`; consumer configuration
   changes remain behind a feature flag. → verify with Nixarchy and plain NixOS
   module evaluations.

8. Live acceptance: switch between two Omarchy themes, confirm one hook-driven
   synchronization updates every enabled runtime target, record applications
   that require restart, and verify that a rebuild is unnecessary for those
   user-session changes. → verify service logs, generated files, and visible
   application state.

## Tests

- `nix flake check`
- Focused renderer tests with temporary XDG paths
- `omarchy plugin validate <plugin-dir>`
- `qmllint -I "$OMARCHY_PATH/shell" ...`
- NixOS module evaluation/build
- NixOS module evaluation with Stylix absent, auto-detected, forced runtime,
  and required-but-absent
- `just validate`
- `just test-host <host>` in the consuming configuration
- One live `omarchy theme set <name>` acceptance test

## Rollback

- Disable the feature flag and remove the flake input from the consuming NixOS
  configuration.
- Disable the user service and remove the Omarchy hooks.
- Run the engine's restore-stock/captured operation for runtime-owned files.
- Re-enable the previous Stylix targets and rebuild the affected host.
- Remove only generated runtime state; preserve user-owned configuration and
  existing NixOS worktree changes.
