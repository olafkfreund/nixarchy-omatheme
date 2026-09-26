---
status: draft
issue: 7
spec: spec/2026-09-26-7-runtime-app-bridges.md
---

# Plan: Runtime bridges for remaining desktop applications

Implement verified runtime adapters for Kitty, Foot, Ghostty, and selected
Electron applications while preserving Stylix/Home Manager ownership.

## Decisions carried from the approved specification

- Runtime theme files live below `~/.config/omarchy/runtime/`.
- Stylix/Home Manager remain the declarative template owners.
- Store-linked wrappers are copied to regular user-owned files after
  `linkGeneration`, preserving their settings and runtime imports.
- Kitty uses native remote control when available.
- Ghostty uses its user-service reload path when available.
- Foot reports restart-required for arbitrary palette changes unless a safe
  host-specific reload path is verified.
- Electron is opt-in and adapter-based; unsupported applications are reported
  rather than mutated speculatively.
- The no-Stylix path generates the complete runtime boundary itself.

## Steps

1. `pkgs/hyprchroma.nix`, upstream source helpers: add shared palette renderers
   for Kitty, Foot, and Ghostty, plus safe runtime-file writes → verify shell
   syntax and deterministic output in temporary XDG directories.

2. `bin/hyprchroma` and adapter helpers: add terminal sync dispatch, ownership
   checks, and explicit status values for synchronized, new-windows-only,
   restart-required, unsupported, and disabled → verify missing applications
   and store-linked paths do not cause unsafe writes.

3. NixOS/Home Manager module: add terminal target options, runtime directories,
   post-`linkGeneration` wrapper bridges, and reload commands → verify module
   evaluation with Stylix absent, Stylix detected, and forced runtime mode.

4. Electron adapter registry: add the smallest verified interface for installed
   Razer applications, beginning with applications whose config and reload
   behavior can be demonstrated → verify each entry independently and keep
   unsupported applications opt-in and inert.

5. Menu plugin and status model: expose terminal/Electron states and restart
   requirements without duplicating file operations → verify plugin validation
   and QML linting.

6. Documentation: update target matrix, Stylix integration, README, and usage
   examples with ownership and reload semantics → verify examples remain
   consistent with module option names.

7. Razer acceptance: build a temporary extended `razer` system, activate it
   with `switch-to-configuration test`, switch between two Omarchy themes, and
   inspect generated files, process reloads, status output, and stale apps →
   verify `/home/olafkfreund/.config/nixos` remains unchanged.

8. Review and merge: run CI, open a PR linked to issue #7, address failures,
   and merge only after all checks and Razer acceptance pass.

## Tests

- `nix fmt`
- `git diff --check`
- `nix flake check --all-systems`
- shell syntax checks for all generated helpers
- temporary-XDG renderer tests for Kitty, Foot, and Ghostty
- NixOS module evaluation with and without Stylix
- `omarchy plugin validate <plugin-dir>`
- `qmllint` for plugin QML when available
- temporary Razer system build and activation
- live theme switch to two themes, followed by restoration of the original
  theme
- clean NixOS configuration worktree check

## Rollback

- Disable the new terminal and Electron target options.
- Rebuild the consuming NixOS configuration to remove the service/hooks.
- Stop the temporary user service if necessary.
- Restore captured runtime state with the engine's restore operation.
- Remove only generated files below `~/.config/omarchy/runtime/` and preserve
  user-owned configuration.
- Revert the implementation PR if the bridge changes behavior unexpectedly.
