---
status: draft
issue: 10
spec: spec/2026-09-26-10-electron-registry.md
---

# Plan: Verified Electron application registry

Implement a fail-closed Electron registry while preserving the existing
opt-in VS Code adapter. Unsupported applications, including Discord, remain
inert and are reported explicitly.

## Steps

1. `pkgs/hyprchroma-electron`: refactor dispatch around an explicit registry;
   preserve the VS Code JSON ownership checks and add inert unsupported entries
   for Discord and other known Electron targets → verify unsupported dispatch
   performs no file reads or writes.
2. `pkgs/hyprchroma-electron` and `pkgs/hyprchroma.nix`: write atomic
   `$XDG_STATE_HOME/hyprchroma/electron.json` status containing supported,
   unavailable, unsupported, restart-required, or synchronized states → verify
   deterministic JSON with a temporary XDG home.
3. `modules/nixos.nix`: retain the explicit VS Code opt-in hook and wire the
   registry/status helper into the existing theme synchronization path without
   adding automatic unsupported-app configuration → verify Stylix and no-Stylix
   module evaluations.
4. `pkgs/omarchroma-plugin.nix`: extend the existing watched status model with
   Electron states using the packaging marker checks already used for terminal
   state → verify plugin build, manifest validation, and generated QML markers.
5. Tests and documentation: add adapter checks for preserved settings,
   malformed JSON, symlink refusal, unsupported inert behavior, and status
   values; document the registry and Discord safety boundary → verify
   `nix fmt`, `git diff --check`, and `nix flake check --all-systems`.
6. Razer acceptance: build and temporarily activate the branch on Razer,
   verify VS Code and unsupported Electron states, then restore the recorded
   generation and confirm `/home/olafkfreund/.config/nixos` is clean.
7. Review and merge: push the branch, open a PR linked to issue #10, wait for
   CI and Razer acceptance, then merge only after all checks pass.

## Tests

- `nix fmt`
- `git diff --check`
- `nix flake check --all-systems`
- Engine and plugin builds
- Temporary-XDG VS Code preservation and refusal tests
- Temporary-XDG unsupported/Discord no-write test
- Generated plugin QML and manifest validation
- Temporary Razer system build and activation
- Clean NixOS configuration worktree check

## Rollback

- Disable the VS Code Electron target option.
- Rebuild the consuming NixOS configuration to remove the hook.
- Revert the implementation PR if registry or status behavior is incorrect.
- Preserve and restore user settings files; remove only generated runtime state
  under `$XDG_STATE_HOME/hyprchroma` if required.
