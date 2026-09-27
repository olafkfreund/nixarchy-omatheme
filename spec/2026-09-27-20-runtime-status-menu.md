---
status: draft
issue: 20
intent: intent/2026-09-27-20-runtime-status-menu.md
---

# Spec: Desktop runtime status in the Nixarchy menu

## Design

Extend the existing `Panel.qml` patch in `pkgs/omarchroma-plugin.nix` with one
desktop status model and one watched `FileView`:

- Read `root.stateDir + "/status.json"` with `watchChanges: true`.
- Default all desktop fields to `unknown` when the file is absent, malformed,
  or incomplete.
- Track `gtk`, `qtKde`, `darkReader`, `pearDesktop`, and `flatpak` without
  changing the runtime engine’s JSON schema.
- Convert only known long values for display: `synchronized` to `synced`,
  `not-installed` to `unavailable`, `restart-required` to `restart`,
  `deferred` to `deferred`, and `disabled` to `off`. Preserve unknown values
  as-is so the UI does not claim a state it does not understand.
- Add a compact desktop status row near the existing shell, terminal, and
  Electron rows, using the existing muted text/font/layout conventions.

The plugin remains read-only with respect to status: the daemon continues to
write `status.json`, and QML only watches and renders it. The same plugin works
when Stylix is present or absent because the status file is produced by the
runtime engine in either mode.

Extend the existing plugin build-time assertions in
`pkgs/omarchroma-plugin.nix` to require the desktop properties, file watcher,
fallback values, label mapping, and UI marker. Add a small fixture-oriented
shell check only if the existing derivation assertions cannot cover malformed
and partial JSON behavior; do not add a QML test framework for this one view.

## Alternatives rejected

- **Create a new daemon status protocol:** rejected because `status.json`
  already contains the target outcomes and is watched by the plugin ecosystem.
- **Show only one overall “theme synced” indicator:** rejected because it hides
  unavailable, deferred, disabled, and restart-required targets.
- **Make the plugin run synchronization commands:** rejected because the menu
  should present state, not become a second owner of runtime writes.
- **Add a QML test framework:** rejected because build-time source assertions
  plus the existing runtime status tests provide sufficient coverage here.

## Risks

- A future target may add a new status string; preserving unknown values avoids
  false claims but may expose a raw technical value until mapped.
- A large status row may be truncated at narrow bar widths; use the existing
  elision/layout behavior and keep labels short.
- `status.json` can change while QML is reading it; the existing `FileView`
  parse/fallback pattern must be reused.
- Plugin source is patched from an upstream tree during Nix build, so marker
  checks must fail clearly if upstream `Panel.qml` moves.

## Verification

- `nix flake check --no-build --accept-flake-config` evaluates the plugin and
  module outputs.
- `nix build .#packages.x86_64-linux.omarchroma-plugin` builds the patched QML
  plugin and runs its marker checks.
- Existing runtime, desktop, Electron, and module checks remain green.
- A fixture check, if needed, proves missing, malformed, partial, and complete
  desktop status input resolve to truthful display values.
- `git diff --check` is clean and `/home/olafkfreund/.config/nixos` is not
  modified.
