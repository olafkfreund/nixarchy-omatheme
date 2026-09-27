---
status: approved
issue: 33
intent: intent/2026-09-27-33-nixarchy-default-integration.md
---

# Spec: Integrate omatheme into Nixarchy defaults

## Design

Add a pinned `nixarchy-omatheme` flake input to Nixarchy's `flake.nix`, with
`nixpkgs` and `home-manager` following Nixarchy's inputs. Nixarchy will use
the input's existing `omarchroma-plugin` package rather than vendoring or
rebuilding the plugin source.

Extend nixarchy-omatheme's NixOS module with a boolean `managePlugin` option,
defaulting to `true`. Standalone users keep the current behavior. When false,
the module still installs the engine, daemon, runtime bridges, and plugin
enablement service, but does not write the plugin directory itself.

In Nixarchy's `modules/home.nix`:

- add an `omatheme` entry to `programs.nixarchy.defaultPluginSet`, using the
  pinned input's `omarchroma-plugin` package and manifest id
  `io.github.nobledoodle.omarchroma`;
- add `omatheme = true` to the default plugin policy;
- keep plugin installation and first-login enablement under Nixarchy's existing
  default-plugin machinery.

In Nixarchy's `modules/nixos.nix`:

- import `inputs.nixarchy-omatheme.nixosModules.default`;
- enable `programs.nixarchyThemeEngine` by default only when Nixarchy has a
  configured desktop user;
- pass `programs.nixarchy.user` to the theme engine's `user` option;
- set `managePlugin = false`, leaving plugin file ownership with
  `defaultPluginSet`.

Add upstream evaluation/runtime coverage proving that the default Nixarchy
configuration contains the omatheme plugin, enables the runtime module for the
desktop user, does not create a duplicate plugin writer, and still evaluates
when Stylix is absent. Update Nixarchy documentation and the lock file with
the pinned input and ownership rule.

## Alternatives rejected

- **Import omatheme and let it install the plugin itself:** rejected because it
  bypasses Nixarchy's default-plugin policy and creates a second plugin owner.
- **Vendor Omarchroma into Nixarchy:** rejected because the package and runtime
  tests already live in nixarchy-omatheme and vendoring would create drift.
- **Require Stylix:** rejected because the offline ISO deliberately does not
  install Stylix and the runtime renderer already supports that path.
- **Make the integration imperative:** rejected because the target is a fresh
  Nixarchy installation with declarative plugin installation and no manual
  `omarchy plugin add` step.

## Risks

- The pinned input may need a release commit or API adjustment before upstream
  accepts it.
- The `managePlugin = false` boundary must be tested so the runtime service can
  enable an already-declared plugin without writing its files.
- A missing or null Nixarchy desktop user must not create a Home Manager entry
  for a nonexistent account.
- Runtime bridges may expose application-specific assumptions in the offline
  ISO; existing nixarchy-omatheme checks remain required.
- Two repositories' lock files and CI checks must agree on the package output
  and module interface.

## Verification

- nixarchy-omatheme: `nix flake check --all-systems --no-build` and targeted
  module checks for `managePlugin`.
- Nixarchy: `nix flake check --all-systems --no-build`, formatter check, and
  existing plugin/module tests.
- Evaluate a Nixarchy system with `programs.nixarchy.user = "omarchy"` and
  assert the engine is enabled, `managePlugin` is false, and the default plugin
  id resolves to the pinned package.
- Evaluate a Stylix-free Nixarchy system and verify the same runtime path.
- Run a Nixarchy VM or Razer smoke test: confirm `hyprchromad.service`, the
  plugin registry entry, and `omarchy theme set` without a rebuild.
- Inspect the generated Home Manager activation to prove there is one plugin
  writer and one runtime engine owner.
