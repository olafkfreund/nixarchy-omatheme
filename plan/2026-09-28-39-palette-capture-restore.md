---
status: approved
issue: 39
spec: spec/2026-09-28-39-palette-capture-restore.md
---

# Plan: Expose palette capture and restore in the theme plugin

Implement the approved plugin integration on `feat/39-palette-capture-restore`
using the existing `hyprchroma` commands and user-owned state paths.

## Steps

1. `pkgs/omarchroma-plugin.nix`: extend the existing post-patch QML insertion
   with fixed user actions for `palette --capture`, `restore --captured`, and
   `restore --stock`; reuse the upstream plugin's process and feedback pattern
   → verify all command strings and insertion markers are present in the
   built plugin.
2. `pkgs/omarchroma-plugin.nix`: refresh the panel status after each action and
   show concise success/failure feedback without exposing arbitrary paths or
   shell input → verify the QML action arguments are constant.
3. `tests/palette-actions.sh` and `flake.nix`: add a small shell-level
   dispatch test using a stub engine, then expose it as a flake check → verify
   capture and both restore modes dispatch exactly once with the expected
   arguments.
4. `docs/stylix-integration.md` and `docs/target-matrix.md`: document that
   capture/restore is runtime user state and does not alter Stylix ownership or
   require a rebuild → verify the documentation matches the commands.

## Tests

Run:

```sh
nix fmt -- --fail-on-change
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#packages.x86_64-linux.omarchroma-plugin
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.palette-actions
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.module
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.runtime
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.desktop
NIXPKGS_ALLOW_UNFREE=1 nix build --impure --no-link .#checks.x86_64-linux.electron
nix run nixpkgs#statix -- check
```

Expected results are successful builds and formatting. Existing unrelated
Statix warnings are recorded rather than fixed in this issue.

## Rollback

Revert the implementation commit. This removes only the plugin actions, test,
and documentation; the engine's existing command-line capture and restore
primitives remain available.
