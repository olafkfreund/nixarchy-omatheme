---
status: approved
issue: 53
spec: spec/2026-09-28-53-editor-theme-targets.md
---

# Plan: Add live Vim and Neovim theme targets

The approved design adds one renderer to the existing `hyprchroma` package,
two module target flags, and small Home Manager-installed editor bridges. The
renderer writes deterministic runtime Lua/Vimscript from the existing palette;
Neovim watches and reapplies it after colorscheme changes, while Vim supports
startup, timer, and explicit-command reload paths. LazyVim is covered by the
Neovim target, and Stylix remains the declarative initial configuration layer.

## Steps

1. `pkgs/hyprchroma-editors`: add a renderer for Neovim Lua, Vimscript, and
   editor status JSON → verify deterministic output for a fixture palette.
2. `pkgs/hyprchroma.nix`: install and invoke the editor renderer through the
   existing synchronization path → verify the default package exposes the
   renderer and existing hooks still work.
3. `modules/nixos.nix`: add `targets.neovim` and `targets.vim`, install the
   runtime bridge plugins through Home Manager, and expose their runtime files
   → verify module evaluation with and without Stylix.
4. `tests/editors-runtime.sh`: test generated files, idempotence, and status
   reporting → verify fixture behavior without a desktop session.
5. Add headless Vim and Neovim checks using minimal configs → verify the
   generated highlights are applied.
6. Add editor status to the plugin only if the existing panel status contract
   can be extended without duplicating the renderer’s data model → otherwise
   keep the first implementation engine-only.
7. Build all affected packages and run the existing suite → verify desktop,
   terminal, shell, Electron, browser, and editor checks pass.
8. Deploy the merged feature to Razer with `nixos-rebuild` through the existing
   Nixarchy flake workflow → verify a live theme switch changes Neovim/Vim
   colors without a rebuild and leaves the NixOS config repository clean.

## Tests

```sh
nix build .#packages.x86_64-linux.hyprchroma --no-link --print-build-logs
nix build .#checks.x86_64-linux.editors --no-link --print-build-logs
nix build .#checks.x86_64-linux.desktop .#checks.x86_64-linux.electron \
  .#checks.x86_64-linux.runtime .#checks.x86_64-linux.plugin-enable \
  --no-link --print-build-logs
```

Runtime acceptance on Razer will use the normal pinned flake after the PR is
merged; no permanent edits or temporary overrides will be left behind.

## Rollback

Revert the implementation commit and remove the editor target flags from the
host configuration. Existing desktop, shell, terminal, and browser targets
remain unchanged; the generated editor runtime files can be removed by the
module activation cleanup.
