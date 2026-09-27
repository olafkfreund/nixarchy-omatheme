---
status: draft
issue: 26
spec: spec/2026-09-27-26-nixos-runtime-integration.md
---

# Plan: Make the runtime theme engine declarative on NixOS

Implement the existing `programs.nixarchyThemeEngine` architecture as the
single supported installation path. The result must work with and without
Stylix, install the engine and Omarchroma plugin through Home Manager, run the
user-scoped `hyprchromad.service`, and keep mutable runtime files outside the
Nix store so theme changes remain rebuild-free.

## Steps

1. `modules/nixos.nix`: audit the existing option, Stylix detection, package,
   hook, plugin activation, and user-service definitions against the approved
   spec. Preserve the single `enable` option and existing target flags; keep
   `stylix.mode = "auto"` as the default, runtime fallback when Stylix is
   absent, explicit runtime override, and explicit Stylix assertion.
   → verify with module evaluation for Stylix-present, Stylix-free, explicit
   runtime, explicit Stylix, and invalid explicit Stylix cases.

2. `modules/nixos.nix` and Home Manager activation: make plugin installation
   and activation reproducible using Omarchy's supported plugin registry
   interface, while retaining the engine's absolute store paths. Do not rely
   on a manual `omarchy-plugin-enable` command for a working installation.
   → verify the generated plugin files, enabled registry state, and shell
   discovery in a test Home Manager generation.

3. `modules/nixos.nix`: harden the `hyprchromad.service` without using
   `DynamicUser`; retain access to the configured user's home, session bus,
   compositor, and graphical target while keeping the existing no-new-
   privileges and filesystem/kernel restrictions.
   → verify the generated unit, environment, ordering, restart policy, and
   `ExecStartPre` target commands.

4. `modules/nixos.nix` and `docs/stylix-integration.md`: fix Alacritty
   ownership handling so a Home Manager/Stylix symlink is resolved to a
   regular user-owned file before runtime hooks write. Preserve imports and
   refuse unsafe or unrelated paths; document the ownership boundary.
   → verify activation with a symlinked generated config, a regular config,
   a missing config, and a non-writable target without deleting unrelated
   files.

5. `flake.nix` and `tests/`: extend the existing evaluation and runtime tests
   for service generation, plugin activation, Stylix detection, terminal and
   shell bridges, Electron status, desktop targets, and Alacritty ownership.
   Keep unsupported Electron applications inert and report restart-required
   states where an application cannot reload an existing window.
   → verify with the repository's existing checks plus the new focused test
   fixtures.

6. `README.md` and relevant docs: document the NixOS and Nixarchy module
   imports, the same declaration for Stylix and non-Stylix hosts, target
   options, runtime switching semantics, plugin activation, and rollback.
   → verify examples evaluate against the flake's module outputs.

7. Local validation: run formatting, whitespace checks, all-system flake
   evaluation, package builds, and all runtime tests.
   → verify with:
   `nix fmt -- --check`, `git diff --check`,
   `nix flake check --all-systems --no-build`,
   `nix build .#hyprchroma .#omarchroma-plugin`, and the generated checks.

8. Razer integration test: deploy only through the host's normal declarative
   NixOS/Home Manager workflow, verify the service and plugin after login,
   switch between two themes without `nixos-rebuild`, inspect state files and
   supported application targets, and confirm no Alacritty permission warning.
   Reserve the desktop on the agent bus before control, capture logs, then
   restore the original theme and release control.
   → verify service health, plugin registry state, before/after palette files,
   and clean rollback.

9. Publish: commit implementation and tests on this branch, push, open a PR
   closing issue #26, wait for green CI, and merge only after all checks pass.
   → verify `main` contains the approved artifacts, implementation, and CI
   result.

## Tests

- `nix fmt -- --check`
- `git diff --check`
- `nix flake check --all-systems --no-build`
- `nix build .#hyprchroma .#omarchroma-plugin`
- Existing desktop, Electron, and runtime target checks
- New module/plugin/Alacritty activation checks
- Razer service, plugin, theme-switch, and permission regression checks

## Rollback

- Before deployment, revert the implementation commit or reset to the prior
  generation using the host's normal NixOS rollback workflow.
- Disable `programs.nixarchyThemeEngine.enable` and rebuild to remove the
  service, hooks, and declarative plugin files.
- Restore the previous Omarchy theme with `omarchy theme set <previous-theme>`.
- Leave user-owned runtime files and unrelated application configuration
  intact; do not remove them recursively during rollback.
- If the Razer test fails, stop the user service, restore the prior theme,
  remove only the test generation/plugin files, and release desktop control.
