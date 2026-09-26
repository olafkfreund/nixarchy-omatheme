---
status: draft
issue: 16
spec: spec/2026-09-26-16-electron-runtime-integrations.md
---

# Plan: Expand verified Electron runtime integrations

Issue #16 expands the Electron registry without adding unsafe mutators. VS Code
remains the only supported adapter. Discord, Slack, and Obsidian receive
explicit unsupported states and no-op behavior until a stable user-owned
configuration/reload boundary is proven.

## Steps

1. `pkgs/hyprchroma-electron`: replace the two-entry status map with a
   metadata-driven registry for VS Code, Discord, Slack, and Obsidian; add a
   status/registry operation that reports unavailable, supported, or unsupported
   states without touching application files → verify deterministic JSON and
   unchanged files for unsupported entries.
2. `modules/nixos.nix` and `pkgs/hyprchroma.nix`: initialize the complete
   Electron status file at service startup while keeping VS Code opt-in and all
   unsupported entries inert → verify module evaluation and existing VS Code
   enable/disable behavior.
3. `pkgs/omarchroma-plugin.nix`: consume the complete Electron status registry
   and show compact states for VS Code, Discord, Slack, and Obsidian → verify the
   patched QML contains the complete status watcher and builds successfully.
4. `tests/electron-runtime.sh` and `flake.nix`: add isolated fixtures for VS
   Code preservation/generated keys, unsupported no-op behavior, unavailable
   paths, store-linked refusal, and complete status JSON; expose the test as a
   flake check → verify with direct execution and the Nix sandbox.
5. `README.md`, `docs/target-matrix.md`, and `docs/stylix-integration.md`:
   document the final registry states, supported VS Code boundary, and explicit
   unsupported behavior → verify no documentation claims unsupported live
   adapters.
6. Razer acceptance test: build the branch as an extended `razer` system,
   activate temporarily, invoke only the non-mutating unsupported operations for
   Discord, Slack, and Obsidian, confirm configuration hashes do not change, and
   verify the existing VS Code adapter remains functional → restore the prior
   generation and report any application-specific warnings.
7. Commit, push, open a PR linking issue #16 and all artifacts, wait for CI, and
   merge only after all checks and Razer validation pass.

## Tests

```sh
bash tests/electron-runtime.sh
nix flake check --all-systems
nix build .#hyprchroma .#omarchroma-plugin
```

The Razer test must not launch Electron applications or edit the NixOS
configuration repository. It records and restores the active NixOS generation,
theme, and relevant configuration hashes.

## Rollback

If implementation or CI fails, revert the branch commits without touching
`main`. If Razer activation has started, restore the recorded system with its
`switch-to-configuration test` entry point and verify `hyprchromad`, the active
theme, application hashes, and user configuration repository status.
