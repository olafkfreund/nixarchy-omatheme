---
status: draft
issue: tbd
intent: intent/2026-09-25-tbd-omarchy-theme-engine.md
---

# Spec: Omarchy runtime theme engine for NixOS

## Design

Use Omarchroma's runtime synchronization model as the first implementation,
packaged for NixOS rather than installed through Arch packaging. The package
provides the runtime CLI and helpers for GTK/libadwaita, Qt/KDE, Dark Reader,
and optional Flatpak integration. It reads the active Omarchy palette and
writes only mutable user-session files under `$XDG_CONFIG_HOME`,
`$XDG_DATA_HOME`, and `$XDG_STATE_HOME`.

Add a declarative NixOS/Home Manager integration module that:

- installs the packaged engine and its runtime dependencies;
- creates a user service running after the graphical session;
- installs the Omarchy `theme-set` and `font-set` hooks declaratively;
- exposes the engine CLI to the user;
- makes Flatpak integration opt-in;
- keeps service privileges limited to the desktop user;
- does not write to `/nix/store` at runtime.

The theme-set hook performs one synchronized engine run. The engine stages
generated files, uses a per-user lock, updates all enabled renderers, and emits
a stale-application report for applications that cache their theme. It may
reload supported services, but it must not blindly kill arbitrary processes.

For each application, the integration records one ownership strategy:

1. Stylix generates a stable wrapper/config that imports an Omarchy-managed
   runtime theme file.
2. Nix creates a stable symlink or environment/config-path indirection to an
   Omarchy-managed runtime file.
3. A Nix-installed wrapper assembles or selects the runtime configuration when
   the application starts.
4. The engine renders the complete mutable application config when no
   indirection exists.
5. The application remains rebuild-only when none of the above is safe.

The engine never assumes that an arbitrary application understands an import.
The target matrix identifies the expected file path, owner, renderer, reload or
restart action, and fallback behavior for every supported application.

The Quickshell plugin is a thin control surface over the CLI. It provides
status, sync, renderer toggles, stale-application reporting, and restore-stock
actions. It contains no palette parsing or filesystem ownership logic.

Stylix remains enabled in the consuming NixOS configuration for immutable or
rebuild-time targets: GRUB, Plymouth, initrd/console surfaces, fonts, cursor,
icons, and static fallback configuration. Stylix targets that write files owned
by the runtime engine are disabled. Both systems consume the same Omarchy
`colors.toml` palette contract, but only the runtime engine changes user-session
files after a theme switch.

Stylix remains the source for declarative color values and static configuration
shape. The runtime engine does not evaluate Nix or modify Stylix outputs; it
rewrites only the mutable files referenced by the generated indirections.

The integration is consumed by the existing NixOS flake as a feature module,
with the runtime engine and plugin supplied from this repository. The first
version targets the current Nixarchy desktop user and Omarchy session; host
generalisation follows after the live path works.

## Alternatives rejected

### Remove Stylix and reimplement every target

Rejected because it duplicates Stylix's broad target coverage and would lose
reliable declarative handling for boot and system outputs.

### Keep Stylix as the owner of all user configuration

Rejected because Stylix outputs are immutable Nix store files and cannot be
retinted immediately by `omarchy theme set`.

### Put theme-generation logic in the QML plugin

Rejected because the plugin runs unsandboxed, is harder to test, and would
duplicate the CLI's file ownership and locking rules.

### Rebuild NixOS after every theme switch

Rejected because it violates the required immediate session update and makes
ordinary theme selection unnecessarily slow.

## Risks

- Some applications only read theme settings at startup and require a restart.
- Browser and Electron integrations may depend on extensions or app-specific
  reload behavior.
- Flatpak integration broadens read access and must remain opt-in.
- Upstream Omarchroma may assume Arch paths or dependencies that need small Nix
  packaging patches.
- Runtime-generated files can conflict with existing Home Manager or Stylix
  ownership unless the target matrix is explicit.
- A symlink or wrapper can preserve the application path without providing a
  true live reload; the verification must distinguish file update from visible
  application update.
- GRUB, Plymouth, initrd, console, fonts, and icons cannot promise immediate
  updates.

## Verification

- Build and evaluate the package and NixOS/Home Manager module.
- Run the engine's focused CLI checks with a temporary XDG configuration root.
- Verify hook execution changes generated GTK, Qt, and terminal outputs from one
  palette change.
- Verify at least one application through each ownership strategy: imported
  runtime file, symlink/path indirection, wrapper, full-config renderer, and
  rebuild-only fallback.
- Validate the plugin manifest with `omarchy plugin validate` and QML with
  `qmllint` against `$OMARCHY_PATH/shell`.
- Confirm the user service starts without elevated privileges and restarts
  after a graphical-session reconnect.
- Test `omarchy theme set <name>` followed by one hook-driven synchronization.
- Run `just validate` and the relevant host build in the consuming NixOS
  configuration before deployment.
